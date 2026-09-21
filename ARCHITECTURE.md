# Architecture Design: Automated Genome Assembly Platform

Companion to `PRD.md` (what/why) and `PHASES.md` (build order). This document is the *how* — concrete enough to start writing code against.

---

## 1. System Overview

```
raw FASTQ + sample_sheet.csv
        │
        ▼
 ┌───────────────┐      ┌────────────┐      ┌──────────────────┐
 │ Ingestion      │─────▶│ Control    │─────▶│ Job Queue          │
 │ (watch-folder/ │      │ Plane      │      │ (SQLite → Redis)   │
 │  FastAPI POST) │      │ (FastAPI)  │      └─────────┬──────────┘
 └───────────────┘      └────────────┘                │
                                                        ▼
                                          ┌──────────────────────┐
                                          │ Worker Process         │
                                          │ generates config.yaml  │
                                          │ invokes Snakemake       │
                                          └───────────┬───────────┘
                                                       ▼
                                          ┌──────────────────────┐
                                          │ Snakemake DAG          │
                                          │ (rules run in Docker)  │
                                          └───────────┬───────────┘
                                                       ▼
                                          ┌──────────────────────┐
                                          │ Storage: raw/work/    │
                                          │ results/{run_id}/     │
                                          │ + runs.sqlite metadata│
                                          └───────────┬───────────┘
                                                       ▼
                                          ┌──────────────────────┐
                                          │ Reporting: MultiQC +   │
                                          │ run_summary.json +     │
                                          │ notification webhook   │
                                          └──────────────────────┘
```

---

## 2. Repository Structure

```
genome-assembly-platform/
├── api/                        # FastAPI control plane
│   ├── main.py
│   ├── routes/
│   │   ├── runs.py
│   │   └── health.py
│   ├── models/                 # Pydantic schemas
│   │   ├── sample_sheet.py
│   │   └── run.py
│   ├── db.py                   # SQLite/SQLAlchemy session
│   └── worker.py                # polling loop / job dispatch
├── pipeline/                    # Snakemake workflow
│   ├── Snakefile
│   ├── rules/
│   │   ├── qc.smk
│   │   ├── trim.smk
│   │   ├── assemble.smk
│   │   ├── polish.smk
│   │   ├── validate.smk
│   │   └── report.smk
│   ├── envs/                    # per-tool Docker/conda specs
│   └── config/
│       └── config.template.yaml
├── docker/
│   ├── fastp.Dockerfile
│   ├── flye.Dockerfile
│   ├── spades.Dockerfile
│   ├── quast.Dockerfile
│   ├── busco.Dockerfile
│   └── ...
├── data/
│   ├── raw/{sample_id}/
│   ├── work/{run_id}/
│   ├── results/{run_id}/
│   └── db/runs.sqlite
├── tests/
│   ├── test_api/
│   ├── test_pipeline/           # small synthetic FASTQ fixtures
│   └── fixtures/
├── scripts/
│   └── genomectl                # thin CLI wrapper around the API
├── PRD.md
├── ARCHITECTURE.md
├── PHASES.md
├── RULES.md
└── docker-compose.yml            # local dev: api + worker + (later) redis
```

---

## 3. Core Data Models

### 3.1 Sample Sheet (input contract)
```yaml
samples:
  - sample_id: sample_01
    read_type: short          # short | long | hybrid
    read1: raw/sample_01/R1.fastq.gz
    read2: raw/sample_01/R2.fastq.gz
    long_reads: null
    expected_genome_size: null   # optional override; else estimated via GenomeScope2
    organism_type: bacterial     # bacterial | eukaryotic
```

### 3.2 Run record (`runs.sqlite`)
| Field | Type | Notes |
|---|---|---|
| run_id | UUID | primary key |
| sample_id | str | FK to sample sheet entry |
| status | enum | queued, running, done, failed, cancelled |
| current_stage | str | last/active Snakemake rule |
| config_snapshot | JSON | full resolved config used for this run |
| tool_versions | JSON | captured from Docker image tags at run time |
| metrics | JSON | N50, BUSCo %, genome size, etc. |
| created_at / started_at / finished_at | timestamp | |
| log_path | str | pointer to full log file |

### 3.3 Run summary (`results/{run_id}/report/run_summary.json`)
Machine-readable output — same shape as the `metrics`/`tool_versions` fields above, written by the final Snakemake rule so the API doesn't need to parse MultiQC HTML.

---

## 4. API Contract (v1)

| Endpoint | Method | Purpose |
|---|---|---|
| `/runs` | POST | Submit a sample sheet, create run(s), enqueue |
| `/runs/{run_id}` | GET | Status, current stage, timestamps |
| `/runs/{run_id}/report` | GET | Final `run_summary.json` + link to MultiQC HTML |
| `/runs/{run_id}/logs` | GET | Tail or full log for debugging |
| `/runs/{run_id}/cancel` | POST | Kill a running job |
| `/health` | GET | Liveness check |

Request/response bodies are Pydantic models mirroring section 3.1/3.2 — keep the API layer a thin validator/dispatcher, not where pipeline logic lives.

---

## 5. Execution Model

- **Worker loop** (v1): a single Python process polls `runs.sqlite` for `status=queued`, marks `running`, writes `config/{run_id}.yaml`, shells out to:
  ```
  snakemake --configfile config/{run_id}.yaml --use-docker --cores N --rerun-incomplete
  ```
- **Concurrency** (v2): swap the polling loop for Redis + RQ workers; multiple runs execute in parallel, each still calling Snakemake with its own `run_id`-scoped config and working directory.
- **Executor swap** (v3, cloud/HPC): only the Snakemake profile changes (`--slurm`, or a cloud executor plugin) — the `Snakefile` and rules are untouched. This is the architectural seam that must be kept clean from day one: **rules never assume local filesystem paths beyond the `work/{run_id}/` and `results/{run_id}/` convention**, so they're portable to remote executors later.

---

## 6. Failure & Recovery Design

- Snakemake's own file-based dependency tracking gives resume-from-failure for free (`--rerun-incomplete`) — the worker doesn't need custom checkpoint logic.
- A dedicated `validate_qc` rule (reads QUAST/BUSCo output, compares to thresholds in config, raises `AssertionError` on failure) turns a soft "bad result" into a hard pipeline failure with a clear log line and a `status=failed` run record — never a silently-passed bad assembly.
- Worker catches the Snakemake subprocess's non-zero exit, extracts the failing rule from Snakemake's own log, writes it to `runs.sqlite.current_stage`, sets `status=failed`.

---

## 7. Key Design Decisions & Rationale

| Decision | Rationale |
|---|---|
| Snakemake over Nextflow | Python-native rules/config match your existing stack; lower ramp-up |
| SQLite before Postgres | Solo-user v1 doesn't need a client-server DB; migration path is trivial (SQLAlchemy handles both) |
| Docker per-tool, not one mega-image | Assemblers/polishers pin conflicting dependency versions; isolation avoids dependency hell |
| FastAPI as thin control plane | Keeps orchestration logic in Snakemake (where it belongs) rather than duplicated in API code |
| `run_summary.json` alongside MultiQC | MultiQC HTML is for humans; the JSON is the stable machine-readable contract for the API/future dashboard |

---

## 8. Extension Points (for later, don't build yet)

- Swap SQLite → Postgres when concurrent runs need real transactional guarantees.
- Swap polling worker → Redis/RQ when you need parallel run execution.
- Add a `cloud.smk` profile for AWS Batch/Slurm — no rule logic changes.
- Add a minimal frontend (or just extend `genomectl` CLI) once the API contract is stable — don't build UI before the pipeline is proven correct.
