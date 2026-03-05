import cv2
import numpy as np
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cameras.traffic_pipeline import TrafficAnalyzer

def test_night_enhancement():
    print("Initializing TrafficAnalyzer (this might load YOLO)...")
    # minimal init to avoid loading heavy model if we mock it? 
    # But init loads it. Let's just let it load or mock it if needed.
    # The class loads YOLO in init. 
    analyzer = TrafficAnalyzer() 
    
    # Create a dark gradient image to test contrast enhancement
    print("\nCreating Dark Gradient Image (Brightness ~30)...")
    width, height = 640, 640
    # Create a gradient from 10 to 50
    gradient = np.linspace(10, 50, width, dtype=np.uint8)
    dark_image = np.tile(gradient, (height, 1))
    dark_image = cv2.merge([dark_image, dark_image, dark_image])
    
    # Check initial brightness
    hsv = cv2.cvtColor(dark_image, cv2.COLOR_BGR2HSV)
    v = hsv[:,:,2]
    initial_brightness = np.mean(v)
    print(f"Initial Brightness: {initial_brightness}")
    
    # Run Enhancement
    print("Running _enhance_night_frame...")
    enhanced_image = analyzer._enhance_night_frame(dark_image)
    
    # Check enhanced brightness
    hsv_enhanced = cv2.cvtColor(enhanced_image, cv2.COLOR_BGR2HSV)
    v_enhanced = hsv_enhanced[:,:,2]
    final_brightness = np.mean(v_enhanced)
    print(f"Final Brightness: {final_brightness}")
    
    if final_brightness > initial_brightness + 10:
        print("✅ SUCCESS: Image was enhanced successfully.")
        return True
    else:
        print("❌ FAILURE: Image was not significantly enhanced.")
        return False

def test_day_no_enhancement():
    print("\nCreating Bright Image (Brightness ~200)...")
    analyzer = TrafficAnalyzer()
    bright_image = np.ones((640, 640, 3), dtype=np.uint8) * 200
    
    hsv = cv2.cvtColor(bright_image, cv2.COLOR_BGR2HSV)
    initial_brightness = np.mean(hsv[:,:,2])
    print(f"Initial Brightness: {initial_brightness}")
    
    enhanced_image = analyzer._enhance_night_frame(bright_image)
    
    hsv_enhanced = cv2.cvtColor(enhanced_image, cv2.COLOR_BGR2HSV)
    final_brightness = np.mean(hsv_enhanced[:,:,2])
    print(f"Final Brightness: {final_brightness}")
    
    # Allow small float diffs
    if abs(final_brightness - initial_brightness) < 1.0:
        print("✅ SUCCESS: Bright image was NOT enhanced (as expected).")
        return True
    else:
        print(f"❌ FAILURE: Bright image was altered! Diff: {abs(final_brightness - initial_brightness)}")
        return False

if __name__ == "__main__":
    if test_night_enhancement() and test_day_no_enhancement():
        print("\nAll Tests Passed!")
        exit(0)
    else:
        print("\nTests Failed!")
        exit(1)
