import io
import json
import os
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import List

import boto3
from PIL import Image
from pydantic import BaseModel
from ultralytics import YOLO

LOCAL_WEIGHTS_PATH = "/tmp/rail_defect_yolov11_weights.pt"


class DefectDetails(BaseModel):
    """Aggregated metrics for a specific class of defect within an image."""
    defect_type: str
    count: int
    highest_confidence: float


class ImageInferenceSummary(BaseModel):
    """The final structured database payload for the image entry."""
    has_defect: bool
    total_defect_count: int
    defects: List[DefectDetails]


def main():
    print("--- STARTING RAIL DEFECT INFERENCE BATCH ---")
    
    batch_payload = os.environ.get("BATCH_FILES")
    bucket_name = os.environ.get("SOURCE_BUCKET_NAME", "rdp-dev-datasync-destination")
    
    if not batch_payload:
        print("Error: BATCH_FILES environment variable missing.")
        sys.exit(1)
        
    try:
        payload_dict = json.loads(batch_payload)
        files_to_process = payload_dict.get("Items", [])
    except Exception as e:
        print(f"Error parsing BATCH_FILES JSON: {e}")
        sys.exit(1)
        
    if not files_to_process:
        print("No files found in batch payload to process.")
        sys.exit(0)

    s3_client = boto3.client("s3")
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table(os.environ.get("DYNAMODB_TABLE_NAME", "rdp-dev-inference-results"))
    
    if not os.path.exists(LOCAL_WEIGHTS_PATH):
        print(f"Downloading model weights from S3: s3://{bucket_name}/models/rail_defect_yolov11_weights.pt...")
        try:
            s3_client.download_file(bucket_name, "models/rail_defect_yolov11_weights.pt", LOCAL_WEIGHTS_PATH)
            print("Weights downloaded successfully.")
        except Exception as e:
            print(f"Failed to download weights: {e}")
            sys.exit(1)

    print("Loading weights into YOLO framework...")
    try:
        model = YOLO(LOCAL_WEIGHTS_PATH)
    except Exception as e:
        print(f"Failed to load model weights: {e}")
        sys.exit(1)
        
    print(f"Processing {len(files_to_process)} entries.")
    
    for index, file_info in enumerate(files_to_process):
        s3_key = file_info.get('Key')
        if not s3_key or s3_key.endswith('/'):
            continue
            
        print(f"\n[{index + 1}/{len(files_to_process)}] Fetching image: s3://{bucket_name}/{s3_key}")
        
        try:
            s3_response = s3_client.get_object(Bucket=bucket_name, Key=s3_key)
            image_bytes = s3_response['Body'].read()
            pil_image = Image.open(io.BytesIO(image_bytes))
            
            results = model(source=pil_image, conf=0.25, max_det=50)

            defect_counts = defaultdict(int)
            defect_max_conf = defaultdict(float)
            total_detections = 0

            if results and results[0].boxes:
                first_result = results[0]
                boxes = first_result.boxes

                confidences = boxes.conf.cpu().numpy()
                class_indices = boxes.cls.cpu().numpy()
                class_names_map = first_result.names

                for conf, cls_idx in zip(confidences, class_indices):
                    cls_name = class_names_map[int(cls_idx)]
                    conf_val = float(conf)
                    
                    total_detections += 1
                    defect_counts[cls_name] += 1
                    if conf_val > defect_max_conf[cls_name]:
                        defect_max_conf[cls_name] = conf_val

            aggregated_defects: List[DefectDetails] = []
            for cls_name in defect_counts.keys():
                aggregated_defects.append(
                    DefectDetails(
                        defect_type=cls_name,
                        count=defect_counts[cls_name],
                        highest_confidence=round(defect_max_conf[cls_name], 4)
                    )
                )

            db_summary = ImageInferenceSummary(
                has_defect=total_detections > 0,
                total_defect_count=total_detections,
                defects=aggregated_defects
            )

            print(f"Inference summary for {s3_key}: {db_summary.model_dump_json(indent=2)}")

            table.put_item(Item={
                "image_key": s3_key,
                "processed_at": datetime.now(timezone.utc).isoformat(),
                "has_defect": db_summary.has_defect,
                "total_defect_count": db_summary.total_defect_count,
                "defects": [d.model_dump() for d in db_summary.defects],
            })
            print(f"Written to DynamoDB: {s3_key}")
            
        except Exception as e:
            print(f"Failed to process image {s3_key}. Error: {e}")

    print("\n--- AWS BATCH INFERENCE JOB COMPLETED ---")
    sys.exit(0)


if __name__ == "__main__":
    main()