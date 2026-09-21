<div align="center">
  <img src="https://img.shields.io/badge/Snakemake-Pipeline-0071C5?style=for-the-badge&logo=snakemake" alt="Snakemake">
  <img src="https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi" alt="FastAPI">
  <img src="https://img.shields.io/badge/Docker-Containerized-2496ED?style=for-the-badge&logo=docker" alt="Docker">
  <h1>🧬 Comprehensive Genomic & Annotation Pipeline (GUI)</h1>
  <p><strong>An advanced, end-to-end, containerized bioinformatics workflow powered by Snakemake with an interactive web GUI.</strong></p>
</div>

<br/>

## 🔬 Overview

This repository houses a state-of-the-art bioinformatics pipeline designed to handle short-read (Illumina), long-read (Nanopore), and hybrid sequence data. It automates everything from raw read quality control to advanced functional annotation and NCBI identification. 

The pipeline is entirely **container-driven**, ensuring 100% reproducibility across environments without the headache of resolving dependency conflicts. It features a modern **interactive web GUI** that dynamically generates Directed Acyclic Graphs (DAGs) and configuration files based on the tools you select.

## ✨ Key Features

* **🖥️ Interactive Web GUI**: A dynamic frontend that adapts to your sequencing technology and allows you to toggle pipeline steps with a single click.
* **⚡ Dynamic DAG Routing**: The Snakemake backend intelligently multiplexes workflows. If you inject a pre-assembled `.fasta`, it bypasses QC and Assembly and resumes directly at the Annotation phase.
* **📦 100% Containerized**: Every tool is executed inside its own official Docker/Apptainer image (e.g., `staphb/`, `nanozoo/`, `ncbi/`).
* **📡 Remote Database Execution**: Avoid downloading terabytes of databases! The pipeline leverages public APIs (e.g., NCBI `-remote` BLAST execution) to run alignments on supercomputers while returning standard XML formats to your local machine.
* **📁 Standardized Serial Outputs**: Outputs are cleanly organized into `01_qc/`, `04_assembly/`, `07_annotation/`, etc., inspired by nf-core best practices.
* **📊 Live Logging**: Built-in visual tracker with a live progress bar, tracking exact parameters (e.g., TaxID filters, BUSCO lineages) during execution.

## 🧰 Supported Tools

The pipeline supports an extensive and growing array of 25+ industry-standard tools:

| Category | Tools Included |
| :--- | :--- |
| **Quality Control** | FastQC, NanoPlot |
| **Read Trimming** | fastp, NanoFilt, Chopper |
| **Contamination & Screening** | Kraken2, FastQ Screen |
| **De Novo Assembly** | SPAdes, SKESA, MEGAHIT, Flye, Raven, Canu, Unicycler, MaSuRCA |
| **Scaffolding** | RagTag |
| **Validation** | QUAST, BUSCO (Dynamic Lineages) |
| **Core Annotation** | RepeatMasker, Prokka, Bakta, DFAST, Augustus, Funannotate, BRAKER/MAKER |
| **Functional / Pathways** | EggNOG-mapper, InterProScan, KofamScan, dbCAN |
| **AMR & Plasmids** | Abricate, AMRFinderPlus, PlasmidFinder, Phigaro, CRISPRCasFinder |
| **Taxonomy / Comparative** | AntiSMASH, Roary |
| **Identification** | BLASTn, BLASTp, BLASTx (Remote Execution) |
| **Reporting** | MultiQC |

---

## 🚀 Getting Started

This pipeline is fully supported on **Ubuntu/Linux** and **Windows** (via WSL2). Because it relies on Linux-based container technologies (Docker/Apptainer), Windows users must run the pipeline inside the Windows Subsystem for Linux.

### 1. Requirements

Ensure you have the following installed on your system:
* **Python 3.9+**
* **Snakemake** (`pip install snakemake`)
* **FastAPI & Uvicorn** (`pip install fastapi uvicorn pydantic sqlalchemy pyyaml`)
* A container engine: **Docker** or **Apptainer/Singularity**

### 2. Installation

#### 🐧 For Ubuntu / Linux Users
1. Install Docker or Apptainer via your package manager:
   ```bash
   sudo apt update
   sudo apt install docker.io
   # Or for Apptainer:
   sudo apt install apptainer
   ```
2. Clone the repository and install Python dependencies:
   ```bash
   git clone https://github.com/yourusername/genomic-pipeline-gui.git
   cd genomic-pipeline-gui
   pip install -r requirements.txt
   ```

#### 🪟 For Windows Users
1. Open PowerShell as Administrator and install WSL2 (Windows Subsystem for Linux):
   ```powershell
   wsl --install
   ```
2. Restart your computer and open the newly installed **Ubuntu** terminal.
3. Install **Docker Desktop for Windows** and ensure the **"Use the WSL 2 based engine"** setting is checked in Docker Desktop Settings.
4. Inside your Ubuntu terminal, clone the repository and install dependencies:
   ```bash
   git clone https://github.com/yourusername/genomic-pipeline-gui.git
   cd genomic-pipeline-gui
   sudo apt update && sudo apt install python3-pip
   pip3 install -r requirements.txt
   ```

### 3. Running the GUI & Backend Worker

To run the pipeline, you need to start **both** the FastAPI web server and the background Snakemake worker.

#### 🪟 For Windows Users
Simply double-click the `start.bat` file in the project directory. This script will automatically:
1. Activate your virtual environment (if available).
2. Start the FastAPI web server in the background.
3. Open your default web browser to the GUI (**`http://127.0.0.1:8000`**).
4. Start the background job worker in the console.

#### 🐧 For Ubuntu / Linux Users
From your terminal, execute the following:

```bash
# 1. Navigate to the project directory
cd "/mnt/c/Users/Vishwajeet Maurya/Desktop/biotech"  # (Adjust path to your repository)

# 2. Activate your virtual environment (if you are using one)
source venv/bin/activate

# 3. Start the FastAPI web server in the background
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 &

# 4. Start the background job worker
python -m api.worker
```

Then, open your web browser and navigate to:
**`http://127.0.0.1:8000`**

### 4. Running the Pipeline

1. Select your **Starting Point** (Raw Reads or Assembled FASTA).
2. Choose your **Sequencing Technology** (Illumina, Nanopore, or Hybrid).
3. Provide the absolute paths to your data.
4. Check the boxes for the analysis tools you wish to run. 
5. Click **Launch Pipeline**.

The backend will automatically generate the config, compile the Snakemake DAG, and launch the workflow. You can monitor the live execution logs directly inside the GUI!

---

## 📂 Directory Structure

```text
genomic-pipeline-gui/
├── api/
│   ├── static/
│   │   └── index.html         # Frontend Interactive GUI
│   ├── routes/
│   │   └── runs.py            # FastAPI endpoints & Snakemake triggers
│   └── models/                # Pydantic schemas
├── pipeline/
│   ├── Snakefile              # Master workflow orchestrator
│   ├── config/                # Dynamically generated run configurations
│   ├── scripts/               # Custom Python wrapper scripts
│   └── rules/
│       ├── qc.smk             # Quality Control
│       ├── trim.smk           # Read Trimming
│       ├── assemble.smk       # Dynamic Assembly multiplexer
│       ├── assemble_extra.smk # Canu, SKESA, MEGAHIT, etc.
│       ├── validate.smk       # QUAST, BUSCO
│       ├── annotate.smk       # Core annotation tools
│       ├── annotate_extra.smk # Functional and specialized tools
│       └── identify.smk       # NCBI BLAST remote endpoints
└── data/                      # Generated by the pipeline
    ├── raw/                   # Input data
    ├── work/                  # Temporary intermediate files (Trim, Assembly)
    └── results/
        └── {run_id}/          # Final serialized outputs (01_qc, 07_annotation...)
```

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.
