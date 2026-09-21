# Genome Assembly Pipeline: WSL Execution Guide

Since bioinformatics tools (like SPAdes, Flye, FastQC) are built for Linux, we use Windows Subsystem for Linux (WSL) to run the pipeline "for real" on your Windows machine.

Follow these exact steps when you are ready to process your actual `.fastq.gz` data.

## Step 1: Open your Linux Terminal

1. Open your standard Windows **PowerShell**
2. Ensure you are in your project folder (`cd C:\Users\Vishwajeet Maurya\Desktop\biotech`)
3. Type the following command to switch into your Linux environment:
   ```powershell
   wsl
   ```
   *Your prompt will change from `PS C:\...>` to something like `username@hostname:/mnt/c/...$`. You are now inside Linux!*

## Step 2: Run the Setup Script (First Time Only)

I have created an automated setup script (`wsl_setup.sh`) that installs Apptainer (the container engine) and Snakemake.

1. In your new Linux prompt, run:
   ```bash
   bash wsl_setup.sh
   ```
2. *Note: It may ask for your Linux password to install the system packages.*
3. Wait for it to print **"Setup Complete!"**.

## Step 3: Start the Pipeline Engine

Once setup is complete (or whenever you return to work on this in the future), you need to start the backend servers.

Copy and paste these three commands into your Linux terminal:

```bash
# 1. Activate the Python environment
source venv/bin/activate

# 2. Start the FastAPI Web Server in the background
python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 &

# 3. Start the Background Worker (Leave this running!)
python -m api.worker
```

## Step 4: Launch from the GUI

1. Open your web browser on Windows and go to: **http://localhost:8000/**
2. Select your pipeline configuration (Illumina, Nanopore, or Hybrid).
3. Use the file selectors to upload your real `.fastq.gz` files.
4. Click **Launch Pipeline**.

### What happens next?
If you look back at your Linux terminal, you will see the worker instantly detect the job and launch Snakemake. Snakemake will automatically download the required Docker containers (SPAdes, Flye, MultiQC, etc.) and begin processing your genome. All output files will be saved natively to the `data/results/` and `data/work/` folders on your hard drive!
