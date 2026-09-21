# Automated Genome Assembly Pipeline

A practical, end-to-end roadmap for turning raw sequencing reads into a validated, annotated genome assembly — with every stage wired for automation (Docker + a workflow manager) rather than manual, one-off runs.

---

## 0. Decide Your Inputs Before Writing Any Code

Your pipeline design branches hard depending on these answers, so pin them down first:

- **Read type**: short reads only (Illumina), long reads only (Nanopore/PacBio), or hybrid?
- **Organism complexity**: bacterial/viral (small, mostly haploid) vs. eukaryotic (large, repetitive, often diploid)?
- **Reference available?** Reference-guided assembly is far simpler than de novo.
- **Compute budget**: local (your RTX 3050 laptop is fine for bacterial genomes but will struggle with large eukaryotic de novo assembly — plan on cloud/HPC burst capacity for those).

---

## 1. Environment & Orchestration Setup

This is the automation backbone — build it before touching biology.

1. **Containerize every tool** — one Dockerfile (or Biocontainers/Bioconda image) per tool, or a single multi-tool image if the pipeline is small. Pin versions explicitly; assembly tool versions change results.
2. **Pick a workflow manager**: `Nextflow` (best ecosystem, `nf-core` has production-grade pipelines you can fork) or `Snakemake` (more Pythonic, easier if you want tight control). Given your Python/Docker background, Snakemake will feel native; Nextflow gives you `nf-core/bacass` or `nf-core/reassemble`-style pipelines for free.
3. **Version control** the pipeline repo (Git), with a `config.yaml`/`params.yaml` for run-specific inputs (sample sheet, read paths, genome size estimate, thread count).
4. **Sample sheet convention**: a CSV/JSON manifest (sample_id, read1, read2, long_reads, expected_genome_size) that the pipeline ingests — this is what makes it "automated" rather than "scripted for one sample."

---

## 2. Raw Read QC

1. **`FastQC`** on all raw FASTQ files — automate this as the first DAG node, output HTML/JSON reports per sample.
2. **`MultiQC`** to aggregate FastQC (and later, all other tool) reports into one dashboard — run this at the *end* of every stage, not just once.
3. Flag/fail samples automatically on thresholds you define (e.g., min read count, min average quality, adapter contamination %) — build this as a gate in the workflow, not a manual review step.

---

## 3. Read Preprocessing

1. **Adapter/quality trimming**:
   - Short reads: `fastp` (fast, single-tool, outputs its own QC report — often replaces FastQC + Trimmomatic entirely).
   - Long reads: `Filtlong` or `NanoFilt` for length/quality filtering; `Porechop`/`Porechop_ABI` for adapter removal (Nanopore).
2. **Contamination screening**: `Kraken2` or `Centrifuge` against a contamination DB (human, common lab contaminants) — auto-fail or auto-flag samples exceeding a contamination threshold.
3. **Genome size / coverage estimation**: `k-mer` counting via `Jellyfish` or `KMC`, fed into `GenomeScope2` for estimated genome size, heterozygosity, and repeat content. This estimate feeds parameters into the assembler downstream (e.g., expected size for Flye).

---

## 4. Assembly

Choose based on Step 0:

| Scenario | Tool |
|---|---|
| Bacterial, short reads only | `SPAdes` / `Unicycler` |
| Bacterial, long reads only or hybrid | `Unicycler` (hybrid mode) or `Flye` + `Polypolish`/`Pilon` polishing |
| Eukaryotic, long-read (Nanopore/PacBio HiFi) | `Flye`, `hifiasm` (for HiFi), or `Canu` |
| Eukaryotic, hybrid | `MaSuRCA` or `Flye` + short-read polishing |
| Reference-guided | `RagTag` (scaffold against a reference) instead of pure de novo |

Automation notes:
- Parameterize the assembler's genome-size estimate from Step 3's `GenomeScope2` output rather than hardcoding it.
- Run assembly as an isolated, resource-tagged job (assembly is the most memory/CPU-hungry stage — give the workflow manager explicit resource requests so it doesn't starve other jobs).

---

## 5. Polishing (long-read assemblies especially need this)

1. **Long-read polishing**: `Medaka` (Nanopore) or built-in HiFi consensus if using `hifiasm`.
2. **Short-read polishing** (if hybrid data available): `Pilon` or `Polypolish` — map short reads back to the draft assembly and correct residual errors.
3. Iterate 2–3 rounds automatically, with a convergence check (e.g., diminishing error correction count) rather than a fixed manual number of passes.

---

## 6. Assembly QC & Validation

1. **`QUAST`** — contiguity stats (N50, L50, number of contigs, total length vs. estimated genome size).
2. **`BUSCo`** — completeness against a lineage-specific ortholog set (critical for eukaryotic genomes; tells you if genes are missing/fragmented).
3. **`Merqury`** (k-mer based, reference-free) — QV (consensus quality) and completeness score, especially useful when no reference exists.
4. Re-map reads to the final assembly (`minimap2` + `samtools flagstat`) to catch structural issues.
5. Automate a pass/fail gate: e.g., BUSCo completeness < 90% or N50 below expected → flag for review instead of silently proceeding to annotation.

---

## 7. (Optional) Scaffolding & Structural Refinement

- **Hi-C data available?** `SALSA2` or `YaHS` for chromosome-scale scaffolding.
- **Reference available?** `RagTag scaffold` to order/orient contigs against a related genome.
- **Purge duplicates** (common in diploid long-read assemblies): `purge_dups`.

---

## 8. Annotation (if your use case needs it)

1. **Repeat masking**: `RepeatModeler` + `RepeatMasker`.
2. **Gene prediction**:
   - Prokaryotic: `Prokka` or `Bakta` (fast, single-command, good for automation).
   - Eukaryotic: `BRAKER3` (combines RNA-seq/protein evidence + ab initio) — heavier, but far more automatable than manual `AUGUSTUS` tuning.
3. **Functional annotation**: `eggNOG-mapper` or `InterProScan` for GO terms/pathway assignment.

---

## 9. Reporting & Output Packaging

1. Final **`MultiQC`** aggregation across *all* stages (raw QC → trimming → assembly stats → BUSCo → annotation) — this becomes your automated "is this genome good?" report.
2. Auto-generate a run summary (JSON/Markdown) with: input sample, tool versions used, key metrics (N50, BUSCo %, genome size), and pass/fail gate results — this is what makes a pipeline run auditable/reproducible months later.
3. Package outputs per sample in a consistent directory structure (`results/{sample_id}/{qc,trimmed,assembly,polished,annotation}/`) so downstream tooling (or a future dashboard) can consume it predictably.

---

## 10. Automation Glue

1. **CI trigger**: new sample sheet entry or new FASTQ drop in a watched directory (S3 bucket, local folder + `inotify`, or a cron poll) → pipeline auto-launches.
2. **Resource scaling**: run locally for small (bacterial) genomes; auto-offload to cloud (AWS Batch, GCP Life Sciences API, or a Slurm HPC cluster) for large eukaryotic assemblies via Nextflow/Snakemake's native executor support — no code changes needed, just executor config.
3. **Notifications**: pipe pass/fail + report link to Slack/email on completion.
4. **Caching**: enable Nextflow's `-resume` (or Snakemake's rerun-incomplete logic) so a failed run doesn't force a full restart from raw reads.

---

## Suggested Minimum Viable Pipeline (to build first)

If you want a working automated pipeline fast, before adding every bell above:

1. `fastp` (trim + QC report)
2. `Flye` or `SPAdes`/`Unicycler` (assembly, based on read type)
3. `QUAST` + `BUSCo` (validation)
4. `MultiQC` (single aggregated report)
5. Wrapped in Snakemake, containerized with Docker, driven by a CSV sample sheet.

Everything else in this document (polishing, scaffolding, annotation, cloud scaling) layers on top once this core loop runs reliably end-to-end.
