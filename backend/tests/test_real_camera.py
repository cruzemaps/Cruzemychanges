import cv2
import numpy as np
import sys
import os
import requests
import time

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cameras.traffic_pipeline import TrafficAnalyzer

def fetch_camera_image(camera_id):
    url = f"https://its.txdot.gov/ITS_Servers/CCTV/Image/{camera_id}"
    print(f"Fetching from {url}...")
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, timeout=10, headers=headers)
        if response.status_code == 200:
            image_array = np.asarray(bytearray(response.content), dtype=np.uint8)
            img = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
            return img
        else:
            print(f"Failed to fetch camera {camera_id}: Status {response.status_code}")
            return None
    except Exception as e:
        print(f"Error fetching camera {camera_id}: {e}")
        return None

def run_real_test():
    # Camera 7542 HLS URL
    # https://s70.us-east-1.skyvdn.com:443/rtplive/TX_FTW_085/playlist.m3u8
    hls_url = "https://s70.us-east-1.skyvdn.com:443/rtplive/TX_FTW_085/playlist.m3u8"
    cam_id = "7542"
    
    analyzer = TrafficAnalyzer()
    
    print(f"\nTesting Camera {cam_id} using HLS stream...")
    print(f"URL: {hls_url}")
    
    cap = cv2.VideoCapture(hls_url)
    if not cap.isOpened():
        print("❌ Failed to open HLS stream.")
        return

    # Read a frame
    ret, frame = cap.read()
    cap.release()
    
    if ret:
        print("✅ Frame captured successfully!")
        
        # Save original
        cv2.imwrite(f"camera_{cam_id}_real_day.jpg", frame)
        
        # Simulate Night (Darken the image)
        print("Simulating night processing on real frame...")
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        h, s, v = cv2.split(hsv)
        v_dark = (v * 0.2).astype(np.uint8) # Darken to 20%
        hsv_dark = cv2.merge([h, s, v_dark])
        frame_night = cv2.cvtColor(hsv_dark, cv2.COLOR_HSV2BGR)
        cv2.imwrite(f"camera_{cam_id}_real_night_sim.jpg", frame_night)
        
        # Enhance the simulated night frame
        enhanced = analyzer._enhance_night_frame(frame_night)
        cv2.imwrite(f"camera_{cam_id}_real_night_enhanced.jpg", enhanced)
        
        print(f"Saved: Day, Night Sim, and Enhanced Night Sim versions.")
        print("✅ Demonstration complete.")

            
    else:
        print("❌ Failed to read frame from stream.")


if __name__ == "__main__":
    run_real_test()
