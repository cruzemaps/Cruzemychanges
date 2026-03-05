import cv2
import numpy as np
import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cameras.traffic_pipeline import TrafficAnalyzer

def create_synthetic_night_scene():
    # 640x480 canvas
    img = np.zeros((480, 640, 3), dtype=np.uint8)
    
    # Draw a "road" (dark gray)
    cv2.fillPoly(img, [np.array([[200, 480], [440, 480], [360, 200], [280, 200]])], (30, 30, 30))
    
    # Draw some "cars" (dim rectangles)
    cv2.rectangle(img, (300, 350), (340, 390), (40, 40, 50), -1) # Dark blue/grey car
    cv2.rectangle(img, (290, 250), (320, 280), (50, 20, 20), -1) # Dark red car
    
    # Draw "headlights" (dim yellow/white) - very low value to test enhancement
    cv2.circle(img, (310, 390), 3, (100, 100, 80), -1)
    cv2.circle(img, (330, 390), 3, (100, 100, 80), -1)
    
    return img

def run_demo():
    print("Initializing TrafficAnalyzer...")
    analyzer = TrafficAnalyzer() 
    
    print("Generating synthetic night scene...")
    original = create_synthetic_night_scene()
    
    print("Applying Night-Time Enhancement...")
    enhanced = analyzer._enhance_night_frame(original)
    
    # Save results
    cv2.imwrite("demo_night_original.jpg", original)
    cv2.imwrite("demo_night_enhanced.jpg", enhanced)
    
    print(f"Saved 'demo_night_original.jpg' and 'demo_night_enhanced.jpg'")
    
    # Calculate brightness stats
    orig_hsv = cv2.cvtColor(original, cv2.COLOR_BGR2HSV)
    enh_hsv = cv2.cvtColor(enhanced, cv2.COLOR_BGR2HSV)
    
    print(f"Original Avg Brightness: {np.mean(orig_hsv[:,:,2]):.2f}")
    print(f"Enhanced Avg Brightness: {np.mean(enh_hsv[:,:,2]):.2f}")

if __name__ == "__main__":
    run_demo()
