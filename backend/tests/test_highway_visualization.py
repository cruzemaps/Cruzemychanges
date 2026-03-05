import cv2
import sys
import numpy as np
# Mock traffic_pipeline to test logic without loading heavy models if we can, 
# but we need the real process_frame. Let's just use the `is_highway` logic from flask server 
# combined with TrafficAnalyzer.

from cameras.traffic_pipeline import TrafficAnalyzer

# Copy of the is_highway Logic from flask_server.py to test it in isolation with TrafficAnalyzer
def is_highway(cam_data):
    if not cam_data: return False
    route = str(cam_data.get('route') or '').upper()
    return route.startswith(('IH', 'US', 'SH', 'SL', 'LP', 'TOLL'))

def test_highway_viz():
    print("Initializing logic...")
    analyzer = TrafficAnalyzer()
    
    # Load Real Image
    img_path = "/Users/sujeethreddythatiparthi/.gemini/antigravity/brain/764ce97e-6553-4c0f-b6d9-12ebced35e07/verified_camera_7542.jpg"
    frame = cv2.imread(img_path)
    if frame is None:
        print("Could not load image.")
        return

    # Case 1: Highway Camera (Must show boxes)
    print("\n--- Test 1: Highway Camera (IH35) ---")
    cam_highway = {"id": "1", "route": "IH35"}
    
    if is_highway(cam_highway):
        print("Camera identifies as Highway. Processing...")
        annotated_highway, _, _ = analyzer.process_frame(frame.copy())
        cv2.imwrite("test_highway_output.jpg", annotated_highway)
        print("Saved test_highway_output.jpg")
    else:
        print("❌ Error: Should be highway.")

    # Case 2: Non-Highway Camera (FM1709)
    # The real camera 7542 is FM1709. In our new logic, this should NOT get boxes.
    print("\n--- Test 2: Non-Highway Camera (FM1709) ---")
    cam_local = {"id": "7542", "route": "FM1709"}
    
    if is_highway(cam_local):
         print("❌ Error: FM1709 should not be highway.")
    else:
        print("Camera identifies as Non-Highway. enhancing only...")
        # Simulate flask logic
        annotated_local = analyzer._enhance_night_frame(frame.copy())
        cv2.imwrite("test_nonhighway_output.jpg", annotated_local)
        print("Saved test_nonhighway_output.jpg")

    print("\nDone. Check images.")

if __name__ == "__main__":
    test_highway_viz()
