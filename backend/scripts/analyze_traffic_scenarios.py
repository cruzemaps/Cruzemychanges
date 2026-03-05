import sys
import os
import json
import cv2

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
    if not os.path.exists(cameras_path):
        print(f"Cameras file not found: {cameras_path}")
        return
        
    with open(cameras_path, 'r') as f:
        data = json.load(f)
    
    cameras = data.get('cameras', [])
    
    print(f"Loaded {len(cameras)} cameras.")
    analyzer = TrafficAnalyzer()
    
    high_traffic_img = None
    moderate_traffic_img = None
    low_traffic_img = None
    
    out_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'images')
    os.makedirs(out_dir, exist_ok=True)
    
    for i, cam in enumerate(cameras):
        # We process cameras until we find all three scenarios
        name = cam.get('name', 'Unknown')
        print(f"[{i}/{len(cameras)}] Checking Camera {cam.get('id')} ({name}) in {cam.get('jurisdiction')}...")
        img = fetch_image(cam)
        if img is not None:
            height, width = img.shape[:2]
            # Define a generic trapezoid
            roi_polygon = [
                [int(width * 0.30), int(height * 0.35)], # Top Left
                [int(width * 0.70), int(height * 0.35)], # Top Right
                [int(width * 0.95), height],             # Bottom Right
                [int(width * 0.05), height]              # Bottom Left
            ]
            
            annotated_frame, anomalies, analysis_data = analyzer.process_frame(img, roi_polygon=roi_polygon)
            v_count = analysis_data.get('vehicle_count', 0)
            print(f"  -> Found {v_count} vehicles.")
            
            if v_count >= 10 and high_traffic_img is None:
                high_traffic_img = annotated_frame
                print(f"  -> Found HIGH traffic scenario ({v_count} vehicles, cam {name})")
                cv2.imwrite(os.path.join(out_dir, 'high_traffic.jpg'), high_traffic_img)
            elif 4 <= v_count <= 9 and moderate_traffic_img is None:
                moderate_traffic_img = annotated_frame
                print(f"  -> Found MODERATE traffic scenario ({v_count} vehicles, cam {name})")
                cv2.imwrite(os.path.join(out_dir, 'moderate_traffic.jpg'), moderate_traffic_img)
            elif 1 <= v_count <= 2 and low_traffic_img is None and 'FM' not in name:
                low_traffic_img = annotated_frame
                print(f"  -> Found LOW traffic scenario ({v_count} vehicles, cam {name})")
                cv2.imwrite(os.path.join(out_dir, 'low_traffic.jpg'), low_traffic_img)

            if high_traffic_img is not None and moderate_traffic_img is not None and low_traffic_img is not None:
                print("All scenarios found!")
                break

if __name__ == '__main__':
    main()
