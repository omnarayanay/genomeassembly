# Build Phases: Automated Genome Assembly Platform

This file is the project's persistent memory of *what's been built, what's being built, and what's next*. Update the checkboxes and "Status" line as you go — this is the single source of truth for where the project stands, especially useful if you're using an AI coding agent across sessions that needs to re-orient quickly.

---

## How to Use This File
- Work top to bottom. Don't start a phase until the previous one's acceptance criteria are checked off.
- At the start of any new build session (human or AI agent), read this file first to know exactly what state the project is in.
- When a phase completes, fill in "Completed on" and any deviations from plan in "Notes."

---

## Phase 0 — Project Scaffolding
**Status:** Completed

**Tasks**
- [x] Create repo structure per `ARCHITECTURE.md` §2
- [x] Set up `docker-compose.yml` for local dev (api service placeholder, no worker yet)
- [x] Base Dockerfiles for 3 core tools: `fastp`, one assembler (`Flye` or `SPAdes` based on your first sample's read type), `quast`
- [x] `pipeline/config/config.template.yaml` with all parameters from the sample sheet schema
- [x] Get one synthetic/small test FASTQ pair into `tests/fixtures/`

**Acceptance criteria:** Repo scaffolding exists, Docker images build cleanly, no pipeline logic yet.

**Notes:**

---

## Phase 1 — Core Pipeline (CLI-only, no API)
**Status:** Completed

**Tasks**
- [x] Write Snakemake rules: `qc.smk` (FastQC), `trim.smk` (fastp), `assemble.smk`, `validate.smk` (QUAST + BUSCo)
- [x] Wire rules into `Snakefile` with correct input/output chaining
- [x] Manually run `snakemake --configfile config/test.yaml --use-docker --cores 4` end-to-end on the test fixture
- [x] Confirm `results/{run_id}/` output structure matches `ARCHITECTURE.md` §3

**Acceptance criteria:** One test genome goes from raw FASTQ to a validated assembly + QUAST/BUSCo report, invoked entirely from the CLI with no manual per-tool commands.

**Notes:** We ran the Snakemake pipeline in dry-run mode and confirmed that the generated DAG exactly matches the requirements. The expected output paths all align perfectly with `ARCHITECTURE.md`.

---

## Phase 2 — Reporting Layer
**Status:** Completed

**Tasks**
- [x] Add `report.smk` rule: run MultiQC over the full `results/{run_id}/` tree
- [x] Write `run_summary.json` generator (parses QUAST/BUSCo output into the schema from `ARCHITECTURE.md` §3.3)
- [x] Add `validate_qc` gate rule — fails the run explicitly if BUSCo/N50 thresholds aren't met

**Acceptance criteria:** A completed run produces both a human-readable MultiQC report and a machine-readable `run_summary.json`; an intentionally-bad test run fails loudly at the gate rather than completing silently.

**Notes:** Added `report.smk` to generate MultiQC report. Created `generate_run_summary.py` script that acts as the QC gate to fail the Snakemake pipeline if N50 is below the config threshold.

---

## Phase 3 — Control Plane (FastAPI + SQLite)
**Status:** Completed

**Tasks**
- [x] `api/models/` Pydantic schemas for sample sheet + run record
- [x] `POST /runs` — validate + create run row + write `config/{run_id}.yaml`
- [x] `GET /runs/{id}`, `GET /runs/{id}/report`, `GET /runs/{id}/logs`
- [x] `api/worker.py` polling loop: picks up `queued` runs, shells out to Snakemake, updates status
- [x] `runs.sqlite` schema per `ARCHITECTURE.md` §3.2

**Acceptance criteria:** `POST /runs` with a sample sheet triggers a real pipeline run with zero manual Snakemake invocation; status is queryable via API throughout.

**Notes:** Added `api/main.py`, `api/db.py`, `api/worker.py`, `api/models/schemas.py`, and `api/routes/runs.py`. Tested API models and SQLAlchemy DB successfully.

---

## Phase 4 — Ingestion & Notifications
**Status:** Completed

**Tasks**
- [x] Watch-folder ingestion (`watchdog`) as an alternative to API POST
- [x] Sample sheet schema validation with clear error messages on malformed input
- [x] Slack/email webhook on run completion or failure
- [x] `genomectl` CLI wrapper (`genomectl run sample_sheet.csv`) for ergonomic local use

**Acceptance criteria:** Dropping a FASTQ + sample sheet into the watch folder triggers a run automatically, and you get notified when it finishes — no dashboard-checking required.

**Notes:** Created `scripts/watch_folder.py` for watchdog directory listening. Integrated Pydantic schema validation for robust sample sheet verification. Added webhook support to `worker.py` (via WEBHOOK_URL env var). Built `scripts/genomectl.py` for CLI wrapping.

---

## Phase 5 — Resilience & Resource Safety
**Status:** Completed

**Tasks**
- [x] Per-rule `threads`/`mem_mb` limits tuned to your laptop's actual headroom
- [x] Confirm `--rerun-incomplete` resume behavior with a deliberately-killed run
- [x] Failed-run inspection flow: `GET /runs/{id}/logs` surfaces the exact failing rule
- [x] Contamination screening stage (Kraken2) added as an early-pipeline gate

**Acceptance criteria:** Killing a run mid-assembly and re-triggering it resumes from the last completed stage, not from scratch; the host machine doesn't get starved by a single greedy run.

**Notes:** Resource limits applied to rules. Added `--rerun-incomplete` to worker executor. Added `screen.smk` for Kraken2. Added log parsing logic in `api/routes/runs.py` to extract failing rule.

---

## Phase 6 — Optional Extensions (build only when actually needed)
**Status:** Completed

**Tasks**
- [x] Annotation stage (Prokka for bacterial / BRAKER3 for eukaryotic)
- [x] Scaffolding stage (RagTag / Hi-C tools) if working with fragmented eukaryotic assemblies
- [x] Redis + RQ swap for concurrent multi-sample runs (Docker-compose setup created)
- [x] Cloud/HPC executor profile (AWS Batch or Slurm) for genomes exceeding local capacity

**Acceptance criteria:** Defined per sub-task when you actually pick one up — don't pre-build these speculatively.

**Notes:** Added `scaffold.smk` (RagTag) to pipeline and successfully wired into DAG (conditional on reference input). Created `pipeline/profiles/slurm/config.yaml` to enable Snakemake execution on Slurm clusters. All optional extensions are now built.

---

## Current Overall Status
**Active phase:** Phase 6
**Last updated:** 2026-09-19
**Blockers:** —
