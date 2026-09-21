# Project Rules — Automated Genome Assembly Platform

Read this before writing any code for this project — human or AI agent. If you're using an AI coding assistant (Claude Code, Cursor, etc.), point it at this file (and `PHASES.md` for current status) at the start of every session.

---

## 1. Source of Truth Order
1. `PRD.md` — what the system must do and why
2. `ARCHITECTURE.md` — how it's built, data models, API contracts
3. `PHASES.md` — what's done, what's in progress, what's next
4. This file — how to write the code

Never contradict `ARCHITECTURE.md`'s component boundaries without updating that file first. If a build decision changes the architecture, edit the doc in the same commit as the code.

---

## 2. Directory & Naming Conventions
- Follow the repo layout in `ARCHITECTURE.md` §2 exactly — don't introduce new top-level directories without adding them there first.
- Snakemake rule files: `snake_case.smk`, one pipeline stage per file (`qc.smk`, `assemble.smk`, etc.) — never one giant `Snakefile` with everything inline.
- Docker images: `docker/{tool}.Dockerfile`, tagged `{tool}:{pinned-version}` — never `:latest`.
- Run/sample IDs: lowercase, underscore-separated, no spaces or special characters (they become directory names).

## 3. Pipeline (Snakemake) Rules
- Every rule declares explicit `input`/`output` — no rule should read/write files outside its declared I/O (breaks DAG correctness and remote-executor portability).
- Every rule that calls an external tool runs it inside its pinned Docker container — no bare-metal tool calls, even "just for testing."
- Resource-heavy rules (assembly, polishing) must declare `threads` and `mem_mb` — untyped/unlimited resource rules are not acceptable, even in dev.
- Any rule that makes a pass/fail judgment (QC gates) must raise a clear, loggable error on failure — never a silent `pass`/warning that lets a bad result flow downstream.
- Paths inside rules are always relative to `work/{run_id}/` or `results/{run_id}/` — never hardcode absolute host paths (this is what keeps cloud/HPC executor swap possible later, per `ARCHITECTURE.md` §5).

## 4. API (FastAPI) Code
- Route handlers stay thin: validate input, touch the DB, enqueue/dispatch — no pipeline logic in `api/`. Pipeline logic lives only in `pipeline/`.
- All request/response bodies are typed Pydantic models — no raw dict passing across route boundaries.
- Every endpoint that can fail returns a real HTTP status code + structured error body, not a 200 with an error string inside.

## 5. Config & Secrets
- No credentials, API keys, or absolute local paths committed to the repo. Local-only config goes in a gitignored `.env` / `config/local.yaml`.
- `config.template.yaml` in the repo must always be valid and runnable against the test fixtures — it's the reference config, keep it in sync with any new pipeline parameter.

## 6. Testing
- Every new Snakemake rule gets a test run against the small synthetic fixture in `tests/fixtures/` before being considered done — not just "ran once on a real sample and it looked fine."
- API endpoints get at least one happy-path and one validation-failure test (`tests/test_api/`).
- Don't test against multi-GB real genome data in CI/local test runs — use the small fixtures; real-scale runs are manual verification, not automated tests.

## 7. Reproducibility Non-Negotiables
- Tool versions are pinned (Docker tags) — bumping a tool version is a deliberate, logged change, not a side effect of a base image update.
- Every completed run's `config_snapshot` and `tool_versions` are persisted in `runs.sqlite` — if you can't answer "what exact config/versions produced this assembly" from the DB alone, that's a bug.
- Raw input data (`data/raw/`) is treated as immutable — never write pipeline outputs into `raw/`, and never edit a `raw/` file in place.

## 8. When Working With an AI Coding Agent
- Give it `PHASES.md` first — it should identify the current active phase before writing code, and update the phase checkboxes as work completes.
- It should not skip ahead to a later phase's tasks (e.g., writing cloud executor config in Phase 1) — flag it if asked to, per `PHASES.md`'s "don't pre-build speculatively" note in Phase 6.
- Any architectural deviation it proposes (new component, changed data model) should be called out explicitly and reflected in `ARCHITECTURE.md`, not silently implemented.
- Prefer direct, unvarnished status updates over optimistic framing — say plainly when a phase's acceptance criteria aren't actually met yet, rather than marking it done prematurely.

## 9. Commit Discipline
- One phase's worth of work (or a clearly-scoped sub-task within a phase) per commit/PR — not one giant commit spanning multiple `PHASES.md` phases.
- Commit messages reference the phase/task, e.g. `Phase 1: add fastp trim rule + fixture test`.
