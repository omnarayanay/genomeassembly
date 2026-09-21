import time
import os
import requests
import json
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

API_URL = "http://localhost:8000/runs"
WATCH_DIR = "data/raw"

class SampleSheetHandler(FileSystemEventHandler):
    def on_created(self, event):
        if event.is_directory:
            return
        
        filepath = event.src_path
        if filepath.endswith('.json'):
            print(f"New sample sheet detected: {filepath}")
            time.sleep(1) # wait for file write to complete
            
            try:
                with open(filepath, 'r') as f:
                    data = json.load(f)
                
                # POST to API
                response = requests.post(API_URL, json=data)
                
                if response.status_code == 200:
                    run_id = response.json().get('run_id')
                    print(f"Successfully queued run: {run_id}")
                    # Move to processed or delete so we don't process again
                    os.rename(filepath, filepath + ".processed")
                else:
                    print(f"Failed to queue run: {response.status_code} - {response.text}")
                    os.rename(filepath, filepath + ".failed")
                    
            except Exception as e:
                print(f"Error processing {filepath}: {e}")
                os.rename(filepath, filepath + ".error")

if __name__ == "__main__":
    os.makedirs(WATCH_DIR, exist_ok=True)
    event_handler = SampleSheetHandler()
    observer = Observer()
    observer.schedule(event_handler, WATCH_DIR, recursive=False)
    
    print(f"Watching {WATCH_DIR} for new sample sheets...")
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
