# PRD: Automated Genome Assembly Platform

## 1. Problem Statement
Genome assembly today is a manual, error-prone chain of CLI tool invocations (QC → trim → assemble → polish → validate) that a researcher/engineer re-runs by hand for every sample, with no consistent audit trail of what tool versions or parameters produced a given result. There is no single system that takes raw FASTQ in and reliably produces a validated, reported assembly out — without hand-holding each stage.

## 2. Goal
Build a system where dropping raw sequencing reads + a sample sheet into the platform produces, unattended:
- A validated genome assembly
- A QC/validation report (pass/fail against defined thresholds)
- A fully reproducible audit trail (tool versions, config, timing)

## 3. Non-Goals (v1)
- Multi-user auth/permissions — this is a single-operator tool initially.
- A polished web frontend — API + generated reports are sufficient for v1.
- Cloud/HPC execution — architecture must support it later, but v1 runs local/Docker only.
- Real-time streaming assembly (e.g., adaptive sampling during sequencing) — out of scope entirely.

## 4. Target User
You (Vishwajeet), running this locally to process bacterial/small genome samples first, with the system designed to not require a rewrite when eukaryotic/larger genomes or cloud execution are added later.

## 5. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR1 | Accept raw FASTQ + sample sheet via watch-folder or API | Must |
| FR2 | Validate sample sheet schema before enqueueing a run | Must |
| FR3 | Run full DAG: QC → trim → contamination screen → k-mer/genome-size estimate → assembly → polish → validate → report | Must |
| FR4 | Auto-select assembler based on read type (short/long/hybrid) declared in sample sheet | Must |
| FR5 | Enforce QC gates (e.g., BUSCo completeness, N50 threshold) — fail the run explicitly if not met, don't silently continue | Must |
| FR6 | Persist run metadata (config, tool versions, timing, status, metrics) queryable after the fact | Must |
| FR7 | Expose run status + final report via API (`GET /runs/{id}`, `GET /runs/{id}/report`) | Must |
| FR8 | Resume a failed/interrupted run without re-running completed stages | Should |
| FR9 | Notify (Slack/email) on run completion or failure | Should |
| FR10 | Support annotation stage (Prokka/BRAKER3) as an optional post-assembly step | Could |
| FR11 | Swap execution backend (local Docker → cloud/HPC) via config only, no pipeline rewrite | Should |

## 6. Non-Functional Requirements

- **Reproducibility**: identical inputs + config → identical outputs. All tool versions pinned via Docker image tags.
- **Isolation**: every tool runs in its own container; no bare-metal tool installs on the host beyond Docker/Python/Snakemake/FastAPI.
- **Observability**: every run's logs, per-stage status, and resource usage are retrievable after the fact, not just streamed and lost.
- **Resource safety**: per-rule thread/memory caps so one greedy job doesn't starve the host machine (relevant on your current laptop: i5-13420H, RTX 3050).
- **Extensibility**: adding a new pipeline stage (e.g., a new polisher) should mean adding one Snakemake rule, not touching the control plane.

## 7. Success Metrics
- A raw FASTQ sample sheet dropped into the watch folder produces a completed, validated assembly + report with **zero manual CLI intervention**.
- A previously-failed run can be resumed from its last completed stage in under the time it'd take to redo it from scratch.
- Run metadata for any past run (tool versions, metrics, config) is retrievable via a single API call, not by digging through log files.

## 8. Risks / Open Questions
- **Compute ceiling**: local laptop will not handle large eukaryotic de novo assembly — cloud burst is a Should-have, not deferred indefinitely, if that's a realistic near-term need.
- **Reference database sizes**: Kraken2/BUSCo lineage DBs are large (multi-GB to 100+ GB) — disk budget needs planning before Phase 1 build.
- **Tool version drift**: bioinformatics tools update frequently; pinning Docker tags avoids silent behavior changes but requires periodic deliberate upgrades.

## 9. Release Plan (tie-in to phases)
See `PHASES.md` for the phased build plan and acceptance criteria per phase. This PRD defines *what* the system must do; that document defines *in what order* it gets built and how each phase is verified before moving to the next.
