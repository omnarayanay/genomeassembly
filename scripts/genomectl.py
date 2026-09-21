#!/usr/bin/env python
import argparse
import requests
import json
import sys
import time

API_URL = "http://localhost:8000"

def submit_run(sample_sheet_path):
    try:
        with open(sample_sheet_path, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading sample sheet: {e}", file=sys.stderr)
        return
        
    print(f"Submitting {sample_sheet_path} to {API_URL}/runs...")
    try:
        resp = requests.post(f"{API_URL}/runs", json=data)
        resp.raise_for_status()
        run_info = resp.json()
        print(f"Run queued successfully! ID: {run_info['run_id']}")
        return run_info['run_id']
    except requests.exceptions.RequestException as e:
        print(f"API Request failed: {e}", file=sys.stderr)
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}", file=sys.stderr)

def get_status(run_id):
    try:
        resp = requests.get(f"{API_URL}/runs/{run_id}")
        resp.raise_for_status()
        info = resp.json()
        print(f"Run {run_id}: STATUS = {info['status']}")
        if info.get('current_stage'):
            print(f"Stage: {info['current_stage']}")
        if info.get('metrics'):
            print(f"Metrics: {json.dumps(info['metrics'], indent=2)}")
    except requests.exceptions.RequestException as e:
        print(f"API Request failed: {e}", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="CLI for Genome Assembly Platform")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # run command
    run_parser = subparsers.add_parser("run", help="Submit a new sample sheet")
    run_parser.add_argument("sample_sheet", help="Path to JSON sample sheet")
    run_parser.add_argument("--watch", action="store_true", help="Watch progress until complete")
    
    # status command
    status_parser = subparsers.add_parser("status", help="Get run status")
    status_parser.add_argument("run_id", help="UUID of the run")
    
    args = parser.parse_args()
    
    if args.command == "run":
        run_id = submit_run(args.sample_sheet)
        if run_id and args.watch:
            print("Watching progress...")
            while True:
                time.sleep(5)
                get_status(run_id)
                
    elif args.command == "status":
        get_status(args.run_id)

if __name__ == "__main__":
    main()
