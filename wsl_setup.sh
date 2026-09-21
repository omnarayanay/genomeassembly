#!/bin/bash
set -e

echo "========================================="
echo "   Bioinformatics WSL Setup Script       "
echo "========================================="

echo "[1/4] Updating Ubuntu packages..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[2/4] Installing Apptainer (Singularity) for containers..."
# Install prerequisites
sudo apt-get install -y software-properties-common curl wget git

# Add Apptainer PPA and install
sudo add-apt-repository -y ppa:apptainer/ppa
sudo apt-get update
sudo apt-get install -y apptainer

echo "[3/4] Installing Python dependencies..."
sudo apt-get install -y python3-pip python3-venv

# Create a virtual environment for the pipeline
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate

echo "[4/4] Installing Snakemake and FastAPI..."
pip install snakemake fastapi uvicorn sqlalchemy pyyaml requests python-multipart

echo "========================================="
echo "   Setup Complete!                       "
echo "========================================="
echo "To run your pipeline in WSL:"
echo "1. Activate the environment: source venv/bin/activate"
echo "2. Start the API: python -m uvicorn api.main:app --host 0.0.0.0 --port 8000 &"
echo "3. Start the worker: python -m api.worker"
echo "========================================="
