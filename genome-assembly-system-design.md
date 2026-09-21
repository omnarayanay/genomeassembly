# System Design: Automated Genome Assembly Platform

A buildable architecture for the pipeline outlined in `genome-assembly-automation.md` — designed to run standalone on your local machine first, with clean extension points for cloud burst later.

---

## 1. Goals & Constraints

**Goals**
- Drop in raw FASTQ files → get a validated, reported assembly with zero manual tool invocation.
- Every run is reproducible: same inputs + same config = same outputs, with a full audit trail.
- Scale from "one bacterial genome on a laptop" to "large eukaryotic genome on cloud/HPC" without rewriting the pipeline — only swapping the executor.

**Constraints**
- Local dev machine: i5-13420H, RTX 3050 (GPU is not the bottleneck here — assembly is CPU/RAM-bound; GPU only helps if you add basecalling or ML-based polishing later).
- Must containerize per-tool to avoid dependency hell (assemblers pin conflicting versions of samtools/htslib etc.).
- Should reuse your existing stack (Python, FastAPI, Docker) rather than introducing an unfamiliar language.

---

## 2. High-Level Architecture

```
                         ┌─────────────────────────┐
                         │   Ingestion Layer        │
                         │  (watch folder / API /   │
                         │   sample-sheet upload)   │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │   Control Plane (API)    │
                         │  FastAPI service:         │
                         │  - validate sample sheet  │
                         │  - create Run record      │
                         │  - enqueue job             │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │   Job Queue               │
                         │  (Redis + RQ/Celery, or   │
                         │   simple SQLite queue for │
                         │   v1)                      │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │  Workflow Engine          │
                         │  Snakemake / Nextflow     │
                         │  (executes the DAG from   │
                         │   the previous doc)       │
                         └────────────┬─────────────┘
                                      │
                     ┌────────────────┼────────────────┐
                     ▼                ▼                ▼
              ┌────────────┐  ┌────────────┐   ┌────────────┐
              │ Local exec  │  │ Docker exec │   │ Cloud/HPC   │
              │ (dev/small) │  │ (per-tool   │   │ executor    │
              │             │  │  containers)│   │ (later)     │
              └────────────┘  └────────────┘   └────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │   Storage Layer           │
                         │  - raw/ (immutable input) │
                         │  - work/ (scratch/tmp)    │
                         │  - results/{run_id}/      │
                         │  - metadata DB (SQLite/   │
                         │    Postgres)               │
                         └────────────┬─────────────┘
                                      │
                                      ▼
                         ┌─────────────────────────┐
                         │  Reporting & Notify       │
                         │  - MultiQC aggregation    │
                         │  - run summary JSON/MD    │
                         │  - Slack/email webhook    │
                         └─────────────────────────┘
```

---

## 3. Component Breakdown

### 3.1 Ingestion Layer
- **Watch-folder mode** (simplest, good for v1): a directory watcher (`watchdog` in Python) detects new FASTQ files + an accompanying `sample_sheet.csv`, and triggers a run automatically.
- **API mode** (for later, multi-user use): FastAPI endpoint `POST /runs` accepts a sample sheet + file references (local path or pre-signed upload URL), returns a `run_id`.
- Both modes converge on the same internal object: a **Run Request** (sample metadata + config).

### 3.2 Control Plane (FastAPI)
Responsibilities — this is the part that turns a "script" into a "system":
- `POST /runs` — validate sample sheet schema, check FASTQ files exist/are readable, create a `Run` row (status=`queued`), enqueue the job.
- `GET /runs/{id}` — status, current DAG stage, logs pointer.
- `GET /runs/{id}/report` — serve the final MultiQC/summary report once complete.
- `POST /runs/{id}/cancel` — kill a running job cleanly.
- Auth: not needed for solo local use now; add API-key middleware later if you expose it beyond your machine.

### 3.3 Job Queue
- **v1 (solo, local)**: skip a real broker — a simple SQLite-backed queue table (`status: queued/running/done/failed`) polled by a worker loop is enough and avoids running Redis for a single-user tool.
- **v2 (concurrent runs / remote triggering)**: Redis + `RQ` or `Celery` — lets you run multiple samples in parallel and later distribute workers across machines.

### 3.4 Workflow Engine
- **Snakemake** (recommended given your Python background): each stage from the pipeline doc (`fastqc`, `fastp`, `assembly`, `quast`, `busco`, `multiqc`, etc.) is a `rule`, chained via input/output file dependencies — Snakemake computes the DAG automatically.
- Config injected per-run via a generated `config.yaml` (genome size estimate, thread count, tool choice) — the Control Plane writes this file before invoking `snakemake --configfile`.
- Each rule's `shell:`/`script:` directive calls a Dockerized tool (`--use-singularity`/`--use-docker` in Snakemake), not a bare local binary — keeps the engine host-agnostic.

### 3.5 Execution Backends (pluggable)
| Backend | When |
|---|---|
| Local (bare process) | Quick dev iteration, tiny test genomes |
| Docker (local) | Default for real runs — reproducible, isolated tool versions |
| Cloud/HPC (Nextflow `-profile awsbatch` / Snakemake `--slurm`) | Large eukaryotic assemblies exceeding local RAM/CPU |

This is the key design decision that keeps this "run later, run bigger" without a rewrite: **the DAG definition never changes, only the executor config.**

### 3.6 Storage Layer
```
data/
├── raw/{sample_id}/           # immutable, never overwritten
├── work/{run_id}/              # scratch space, safe to purge after success
├── results/{run_id}/
│   ├── qc/
│   ├── trimmed/
│   ├── assembly/
│   ├── polished/
│   ├── annotation/
│   └── report/ (MultiQC + run_summary.json)
└── db/
    └── runs.sqlite             # run metadata, status, metrics, tool versions
```
- Keep `raw/` read-only and content-hashed (checksum on ingest) so you can always prove what went into a given assembly.
- `runs.sqlite` (or Postgres later) stores: run_id, sample_id, config used, tool versions, start/end time, status, key QC metrics (N50, BUSCo %) — this is your queryable audit log, not just files on disk.

### 3.7 Reporting & Notification
- Final Snakemake rule always runs `multiqc` over the whole `results/{run_id}/` tree, regardless of upstream success/failure of optional stages.
- A `run_summary.json` (schema: sample_id, tool_versions, metrics, pass/fail gate results) is generated alongside — this is what a future dashboard or API consumer reads, rather than parsing MultiQC HTML.
- Optional: a webhook call (Slack incoming webhook / SMTP) on run completion — trivial FastAPI background task.

---

## 4. Data Flow (Single Run, End to End)

1. FASTQ files + sample sheet land in `raw/` (watch-folder or API upload).
2. Control Plane validates and creates a `Run` record → `status: queued`.
3. Worker picks up the job, generates `config.yaml`, invokes Snakemake with the chosen executor.
4. Snakemake executes the DAG (QC → trim → assemble → polish → validate → report), each rule in its own container.
5. On completion, `run_summary.json` + MultiQC report written to `results/{run_id}/report/`.
6. `Run` record updated → `status: done` (or `failed`, with the failing rule/log captured).
7. Notification fired; report retrievable via `GET /runs/{id}/report`.

---

## 5. Failure Handling & Idempotency

- **Resume, don't restart**: use Snakemake's `--rerun-incomplete` / `-resume` (Nextflow) so a crash at the polishing stage doesn't force re-running assembly.
- **Gate checks as explicit rules**, not afterthoughts: a `validate_qc` rule that reads QUAST/BUSCo output and raises if thresholds aren't met — this shows up as a normal DAG failure with a clear log, not a silent bad result downstream.
- **Per-rule resource limits** (`threads`, `mem_mb` in Snakemake) so one greedy assembly job doesn't starve your machine — critical on a single dev laptop running other things.
- **Dead-letter handling**: failed runs stay queryable (`status: failed`, log path retained) rather than disappearing — you inspect and re-trigger with `run_id` + corrected config.

---

## 6. Build Order (What to Implement First)

1. **Week 1** — Snakemake pipeline itself (the DAG from the automation doc), runnable manually via CLI with a hand-written `config.yaml`. No API yet. Get one bacterial genome through the full pipeline successfully.
2. **Week 2** — Wrap it: FastAPI control plane with `POST /runs` + `GET /runs/{id}`, SQLite job table, a worker loop that shells out to `snakemake`. This is your MVP system.
3. **Week 3** — Storage conventions (`raw/work/results` layout), `run_summary.json` schema, MultiQC final aggregation, watch-folder ingestion.
4. **Later** — Redis/Celery for concurrency, cloud/HPC executor profile, notifications, a minimal frontend or CLI (`genomectl run sample_sheet.csv`) for ergonomics.

---

## 7. Tech Stack Summary

| Layer | Choice | Why |
|---|---|---|
| API | FastAPI | Already in your stack |
| Workflow engine | Snakemake | Python-native, fits your background better than Nextflow's Groovy DSL |
| Containerization | Docker | Already in your stack; one image per bioinformatics tool |
| Queue (v1) | SQLite table + polling worker | Zero extra infra for solo use |
| Queue (v2) | Redis + RQ/Celery | When you need concurrency or remote workers |
| Metadata DB | SQLite → Postgres later | Start simple, migrate only when multi-user/concurrent |
| Reporting | MultiQC + custom `run_summary.json` | Human-readable + machine-readable in one pass |
