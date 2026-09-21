import time
import subprocess
import os
from datetime import datetime
from .db import SessionLocal, RunRecord
from .models.schemas import RunStatus
import requests

WEBHOOK_URL = os.environ.get("WEBHOOK_URL")

def send_webhook(run_id, status, details=""):
    if not WEBHOOK_URL:
        return
    try:
        payload = {"text": f"Run {run_id} {status}. Details: {details}"}
        requests.post(WEBHOOK_URL, json=payload, timeout=5)
    except Exception as e:
        print(f"Failed to send webhook: {e}")

def get_queued_run(db):
    return db.query(RunRecord).filter(RunRecord.status == RunStatus.queued.value).first()

def run_worker_loop():
    print("Worker started. Polling for queued runs...")
    os.makedirs("data/logs", exist_ok=True)
    
    while True:
        db = SessionLocal()
        try:
            run = get_queued_run(db)
            if run:
                print(f"Found queued run: {run.run_id}")
                run.status = RunStatus.running.value
                run.started_at = datetime.utcnow().isoformat()
                log_file = f"data/logs/{run.run_id}.log"
                run.log_path = log_file
                db.commit()
                
                # Execute Snakemake
                config_path = f"pipeline/config/{run.run_id}.yaml"
                cmd = [
                    "python", "-m", "snakemake",
                    "--configfile", config_path,
                    "-s", "pipeline/Snakefile",
                    "--cores", "4",
                    "--rerun-incomplete",
                    "--use-singularity",
                    "--singularity-prefix", "/tmp/singularity"
                ]
                
                print(f"Executing: {' '.join(cmd)}")
                with open(log_file, "w") as log:
                    process = subprocess.Popen(
                        cmd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1
                    )
                    
                    for line in process.stdout:
                        # Write everything to the log file for the Web GUI
                        log.write(line)
                        log.flush()
                        
                        # Filter for "big steps" to show in the Ubuntu terminal
                        clean_line = line.strip()
                        if clean_line.startswith("rule ") or clean_line.startswith("Finished job") or " steps (" in clean_line or clean_line.startswith("Building DAG"):
                            print(f" ➔ {clean_line}")
                            
                    process.wait()
                
                run.finished_at = datetime.utcnow().isoformat()
                
                if process.returncode == 0:
                    print(f"Run {run.run_id} completed successfully.")
                    run.status = RunStatus.done.value
                    
                    # Try to parse run_summary.json to update DB metrics
                    summary_path = f"data/results/{run.run_id}/report/run_summary.json"
                    if os.path.exists(summary_path):
                        import json
                        with open(summary_path, "r") as f:
                            summary_data = json.load(f)
                            run.metrics = summary_data.get("metrics")
                    send_webhook(run.run_id, "Completed", str(run.metrics))
                else:
                    print(f"Run {run.run_id} failed with code {process.returncode}.")
                    run.status = RunStatus.failed.value
                    send_webhook(run.run_id, "Failed", f"Exit code {process.returncode}")
                    
                db.commit()
            else:
                time.sleep(5)
        except Exception as e:
            print(f"Worker error: {e}")
            time.sleep(5)
        finally:
            db.close()

if __name__ == "__main__":
    run_worker_loop()
