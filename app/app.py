import os
import json
import sys

print("--- AWS BATCH JOB STARTED ---")

# 1. Read the environment variable passed by the Step Function
batch_payload = os.environ.get("BATCH_FILES")

if not batch_payload:
    print("Error: BATCH_FILES environment variable not found!")
    sys.exit(1)

try:
    files_to_process = json.loads(batch_payload)
    print(f"Successfully parsed batch payload. Found {len(files_to_process)} files.")
    
    # 2. Print out the files to prove the plumbing works
    for index, file_info in enumerate(files_to_process):
        print(f"[{index + 1}] Batch scheduler told me to process S3 Key: {file_info.get('Key')}")

except Exception as e:
    print(f"Failed to parse payload JSON. Error: {e}")
    sys.exit(1)

print("--- AWS BATCH JOB FINISHED SUCCESSFULLY ---")
sys.exit(0)