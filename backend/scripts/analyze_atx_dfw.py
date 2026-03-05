import sys
import os
import json
import cv2
import requests
import numpy as np
import time

# Add backend dir to PYTHONPATH to import TrafficAnalyzer
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from cameras.traffic_pipeline import TrafficAnalyzer

def fetch_image(cam):
    url = cam.get('httpsurl')
    if not url or not url.endswith('.m3u8'):
        return None
    try:
        cap = cv2.VideoCapture(url)
        if cap.isOpened():
            ret, frame = cap.read()
            cap.release()
            if ret:
                return frame
    except Exception as e:
        pass
    return None

def main():
    cameras_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'cameras_full.json')
    with open(cameras_path, 'r') as f:
        data = json.load(f)
    
    cameras = data.get('cameras', [])
    
    # Filter cameras on I-35 between Austin and Dallas
    # Jurisdictions: Austin, Waco, Dallas
    target_cams = []
    for cam in cameras:
        route = cam.get('route', '').upper()
        jurisdiction = cam.get('jurisdiction', '')
        if '35' in route and jurisdiction in ['Austin', 'Waco', 'Dallas']:
            target_cams.append(cam)
            
    print(f"Found {len(target_cams)} cameras on I-35 corridor (Austin/Waco/Dallas)")
    
    analyzer = TrafficAnalyzer()
    
    # We want a high traffic image
    best_img = None
    max_vehicles = -1
    best_cam = None
    
    for i, cam in enumerate(target_cams):
        print(f"[{i}/{len(target_cams)}] Checking Camera {cam['id']} ({cam['name']}) in {cam['jurisdiction']}...")
        img = fetch_image(cam)
        if img is not None:
            height, width = img.shape[:2]
            # Define a generic trapezoid isolating the central highway lanes from adjacent frontage roads
            roi_polygon = [
                [int(width * 0.30), int(height * 0.35)], # Top Left
                [int(width * 0.70), int(height * 0.35)], # Top Right
                [int(width * 0.95), height],             # Bottom Right
                [int(width * 0.05), height]              # Bottom Left
            ]
            
            annotated_frame, anomalies, analysis_data = analyzer.process_frame(img, roi_polygon=roi_polygon)
            v_count = analysis_data['vehicle_count']
            print(f"  -> Successfully Loaded Frame! Found {v_count} vehicles.")
            
            if v_count > max_vehicles:
                max_vehicles = v_count
                best_img = annotated_frame
                best_cam = cam
                
            # If we find a highly congested one, just save it and break
            if v_count >= 1:
                break
                
        # Don't check forever, stop after 50
        if i >= 50 and best_img is not None:
            break

    if best_img is not None:
        save_path = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'images', 'austin_dallas_traffic.jpg')
        cv2.imwrite(save_path, best_img)
        print(f"✅ Saved image with {max_vehicles} vehicles from {best_cam['name']} to {save_path}")
    else:
        print("❌ Could not find a suitable image.")

if __name__ == '__main__':
    main()
