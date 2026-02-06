import time
import requests
import cv2
import numpy as np
import random
import threading
import json
from ultralytics import YOLO
import os

# Load a lightweight YOLOv8 model
# It will download the model on first run
model = YOLO('yolov8n.pt')

# Load Statewide Cameras
try:
    with open('backend/cameras_full.json', 'r') as f:
        CAMERAS = json.load(f)['cameras']
    print(f"✅ Loaded {len(CAMERAS)} cameras from cameras_full.json")
except Exception as e:
    print(f"⚠️ Failed to load statewide cameras: {e}. Falling back to core SA list.")
    CAMERAS = [
        {"id": "171", "name": "I-10 @ Wurzbach", "lat": 29.5168, "lon": -98.5583},
        {"id": "250", "name": "I-35 @ Frost Bank Center", "lat": 29.4267, "lon": -98.4375},
        {"id": "312", "name": "US-281 @ Airport", "lat": 29.5292, "lon": -98.4719},
    ]


TRAFFIC_SEGMENTS = [] # Global to hold results
T_LOCK = threading.Lock()

BACKEND_REPORT_URL = "http://localhost:7071/api/report_incident"
BACKEND_TRAFFIC_URL = "http://localhost:7071/api/traffic_update"

def fetch_image(id):
    url = f"https://its.txdot.gov/ITS_Servers/CCTV/Image/{id}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, timeout=5, headers=headers)
        if response.status_code == 200:
            nparr = np.frombuffer(response.content, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            return img
    except Exception as e:
        print(f"Error fetching image from {url}: {e}")
    return None

def analyze_with_ai(image):
    if image is None:
        return {
            "vehicle_count": 0,
            "density": 0,
            "speed": 65,
            "incident": None,
            "description": None
        }
    
    # Run YOLOv8 inference
    results = model(image, verbose=False)
    
    # Class IDs for cars (2), buses (5), and trucks (7) in COCO
    target_classes = [2, 5, 7]
    boxes = results[0].boxes
    detected_vehicles = [box for box in boxes if int(box.cls) in target_classes]
    vehicle_count = len(detected_vehicles)
    print(f"  AI Detected: {vehicle_count} vehicles")
    
    # Max vehicles for density calculation (based on typical TxDOT frame)
    max_capacity = 40 
    density = min(1.0, vehicle_count / max_capacity)
    
    # Speed is inversely proportional to density (mocked for demo)
    # If density is 100%, speed is ~5mph. If 0%, speed is ~75mph.
    base_speed = max(5, 75 - (density * 70))
    speed = int(base_speed + random.randint(-3, 3))
    
    incident_type = None
    description = None
    
    # 10% Manual Force Trigger for testing AI Route Alerts
    if random.random() < 0.10: 
        incident_type = "CRASH"
        description = "AI Test Incident (Forced) for Route Alert Verification"
    elif density > 0.85:
        incident_type = "STOPPED CAR"
        description = "AI Detected Major Congestion / Potential Stalled Vehicle"
    elif speed < 15 and density > 0.9:
        incident_type = "GRIDLOCK"
        description = "AI Detected Localized Gridlock"

    return {
        "vehicle_count": vehicle_count,
        "density": density,
        "speed": speed,
        "incident": incident_type,
        "description": description
    }

def analyze_camera_batch(cameras):
    """Worker function to analyze a small batch of cameras."""
    batch_traffic = []
    for cam in cameras:
        img = fetch_image(cam['id'])
        if img is not None:
            ai_results = analyze_with_ai(img)
            
            if ai_results['incident']:
                payload = {
                    "lat": cam["lat"],
                    "lon": cam["lon"],
                    "type": ai_results['incident'],
                    "description": f"[AI] {ai_results['description']} at {cam['name']}"
                }
                try: requests.post(BACKEND_REPORT_URL, json=payload, timeout=2)
                except: pass
            
            batch_traffic.append({
                "camera_id": cam["id"],
                "lat": cam["lat"],
                "lon": cam["lon"],
                "speed": ai_results["speed"],
                "density": ai_results["density"],
                "name": cam["name"]
            })
    
    with T_LOCK:
        TRAFFIC_SEGMENTS.extend(batch_traffic)

def monitor_cameras():
    print("🚀 Real AI Camera Monitor Started (YOLOv8 - Statewide Edition)...")
    while True:
        global TRAFFIC_SEGMENTS
        TRAFFIC_SEGMENTS = []
        
        # Split cameras into small batches for threading
        batch_size = 20
        batches = [CAMERAS[i:i + batch_size] for i in range(0, len(CAMERAS), batch_size)]
        
        print(f"📡 Starting Statewide Sweep of {len(CAMERAS)} cameras...")
        threads = []
        # Limit concurrency to 5 threads to avoid overwhelming CPU/Network
        max_threads = 5 
        
        for i, batch in enumerate(batches):
            t = threading.Thread(target=analyze_camera_batch, args=(batch,))
            threads.append(t)
            t.start()
            
            if len(threads) >= max_threads:
                for t in threads: t.join()
                threads = []
                print(f"  Processed {min((i+1)*batch_size, len(CAMERAS))}/{len(CAMERAS)}...")

        for t in threads: t.join() # Join remaining
            
        try:
            requests.post(BACKEND_TRAFFIC_URL, json={"traffic": TRAFFIC_SEGMENTS}, timeout=5)
            print(f"✅ Uploaded AI Traffic Status for {len(TRAFFIC_SEGMENTS)} segments")
        except Exception as e:
            print(f"Failed to upload traffic data: {e}")
            
        print("💤 Sweep complete. Sleeping for 15 minutes...")
        time.sleep(15 * 60) 

if __name__ == "__main__":
    monitor_cameras()
