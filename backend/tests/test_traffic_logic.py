import cv2
import sys
import numpy as np
from cameras.traffic_pipeline import TrafficAnalyzer

def test_traffic_logic():
    print("Initializing TrafficAnalyzer...")
    analyzer = TrafficAnalyzer()
    
    # 1. Test with a blank image (0 density)
    print("\n--- Test 1: Blank Image ---")
    blank_frame = np.zeros((640, 640, 3), dtype=np.uint8)
    annotated, anomalies, data = analyzer.process_frame(blank_frame)
    
    print(f"Vehicle Count: {data['vehicle_count']}")
    print(f"Density: {data['density']:.2f}")
    print(f"Recommended Speed: {data['recommended_speed']} MPH")
    print(f"Message: {data['message']}")
    
    if data['density'] == 0.0 and data['recommended_speed'] == 65:
        print("✅ PASS: Correct logic for empty road.")
    else:
        print("❌ FAIL: Logic error for empty road.")

    # 2. Test with Real Image (Camera 7542)
    print("\n--- Test 2: Real Camera Image ---")
    img_path = "/Users/sujeethreddythatiparthi/.gemini/antigravity/brain/764ce97e-6553-4c0f-b6d9-12ebced35e07/verified_camera_7542.jpg"
    try:
        frame = cv2.imread(img_path)
        if frame is None:
            print(f"Could not load {img_path}, skipping real image test.")
            return

        annotated, anomalies, data = analyzer.process_frame(frame)
        
        print(f"Vehicle Count: {data['vehicle_count']}")
        print(f"Density: {data['density']:.2f}")
        print(f"Recommended Speed: {data['recommended_speed']} MPH")
        print(f"Message: {data['message']}")
        
        output_filename = "verified_traffic_density.jpg"
        cv2.imwrite(output_filename, annotated)
        print(f"Saved annotated image to {output_filename}")
        print("✅ PASS: Processed real image successfully.")
        
    except Exception as e:
        print(f"❌ FAIL: Error processing real image: {e}")

if __name__ == "__main__":
    test_traffic_logic()
