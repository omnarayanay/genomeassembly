from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from sqlalchemy.orm import Session
from datetime import datetime
import uuid
import yaml
import os
import json
import shutil
from pathlib import Path

from ..db import get_db, RunRecord
from ..models.schemas import SampleSheet, RunRecordResponse, RunStatus

router = APIRouter(prefix="/runs", tags=["runs"])

@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    # Save to data/raw directory
    upload_dir = "data/raw"
    os.makedirs(upload_dir, exist_ok=True)
    
    file_path = os.path.join(upload_dir, file.filename)
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Return absolute or relative path for Snakemake
    return {"path": file_path}

CONFIG_DIR = "pipeline/config"
os.makedirs(CONFIG_DIR, exist_ok=True)

@router.post("", response_model=RunRecordResponse)
def create_run(sample_sheet: SampleSheet, db: Session = Depends(get_db)):
    run_id = str(uuid.uuid4())
    
    starting_point = sample_sheet.params.starting_point if sample_sheet.params else "reads"
    
    # Create config dict
    config_data = {
        "run_id": run_id,
        "samples": [
            {**s.dict()}
            for s in sample_sheet.samples
        ],
        "params": {
            "starting_point": starting_point,
            "fastp": {"qualified_quality_phred": 15},
            "flye": {"iterations": 1},
            "quast": {"min_contig": 500},
            "busco": {"lineage": sample_sheet.params.busco_lineage if sample_sheet.params else "bacteria_odb10"},
            "blast": {"taxid": sample_sheet.params.taxid if sample_sheet.params else "4910"},
            "selected_tools": sample_sheet.params.selected_tools if sample_sheet.params else []
        },
        "resources": {
            "threads": 4,
            "mem_mb": 8192
        }
    }
    
    # Write config yaml
    config_path = os.path.join(CONFIG_DIR, f"{run_id}.yaml")
    with open(config_path, "w") as f:
        yaml.dump(config_data, f)
        
    # Handle Starting Point Logic
    if starting_point == "assembly":
        # The user provided a FASTA. Snakemake expects a scaffold output. 
        # We copy/symlink their fasta into the expected output path so the DAG resumes from there!
        for sample in sample_sheet.samples:
            if sample.assembly_fasta and os.path.exists(sample.assembly_fasta):
                scaffold_dir = Path("data/work") / run_id / "05_scaffold"
                scaffold_dir.mkdir(parents=True, exist_ok=True)
                dest = scaffold_dir / f"{sample.sample_id}_scaffold.fasta"
                shutil.copy2(sample.assembly_fasta, dest)
        
    # Create DB record
    now = datetime.utcnow().isoformat()
    db_run = RunRecord(
        run_id=run_id,
        sample_id=sample_sheet.samples[0].sample_id if sample_sheet.samples else "unknown",
        status=RunStatus.queued.value,
        config_snapshot=config_data,
        created_at=now
    )
    db.add(db_run)
    db.commit()
    db.refresh(db_run)
    
    return db_run

@router.get("/{run_id}", response_model=RunRecordResponse)
def get_run(run_id: str, db: Session = Depends(get_db)):
    run = db.query(RunRecord).filter(RunRecord.run_id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
    return run

@router.get("/{run_id}/report")
def get_run_report(run_id: str, db: Session = Depends(get_db)):
    run = db.query(RunRecord).filter(RunRecord.run_id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
        
    report_path = f"data/results/{run_id}/report/run_summary.json"
    if not os.path.exists(report_path):
        raise HTTPException(status_code=404, detail="Report not generated yet")
        
    with open(report_path, "r") as f:
        return json.load(f)

@router.get("/{run_id}/logs")
def get_run_logs(run_id: str, db: Session = Depends(get_db)):
    run = db.query(RunRecord).filter(RunRecord.run_id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
        
    if not run.log_path or not os.path.exists(run.log_path):
        raise HTTPException(status_code=404, detail="Log file not found")
        
    with open(run.log_path, "r") as f:
        log_content = f.read()
        
    failing_rule = None
    if run.status == RunStatus.failed.value:
        # Simple extraction logic for Snakemake errors
        import re
        match = re.search(r"Error in rule (\w+):", log_content)
        if match:
            failing_rule = match.group(1)
            
    return {
        "logs": log_content,
        "failing_rule": failing_rule
    }

@router.post("/{run_id}/stop")
def stop_run(run_id: str, db: Session = Depends(get_db)):
    run = db.query(RunRecord).filter(RunRecord.run_id == run_id).first()
    if not run:
        raise HTTPException(status_code=404, detail="Run not found")
        
    if run.status != RunStatus.running.value:
        raise HTTPException(status_code=400, detail="Run is not currently running")
        
    # Find and kill the specific snakemake process for this run
    import subprocess
    try:
        # pkill based on the unique configfile path passed to snakemake
        subprocess.run(["pkill", "-f", f"snakemake.*{run_id}\.yaml"], check=False)
        
        # Mark as failed/stopped in DB
        run.status = RunStatus.failed.value
        run.finished_at = datetime.utcnow().isoformat()
        db.commit()
        
        # Also append to log
        if run.log_path:
            with open(run.log_path, "a") as f:
                f.write("\n[SYSTEM] Run manually stopped by user via GUI.\n")
                
        return {"status": "stopped"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
