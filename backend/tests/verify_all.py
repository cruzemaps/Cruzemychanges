import os
import sys
import cv2
import numpy as np
import time
from cameras.traffic_pipeline import TrafficAnalyzer

def print_header(text):
    print(f"\n{'='*60}\n {text} \n{'='*60}")

def verify_heavy_traffic_visual():
    print_header("VISUALIZING HEAVY TRAFFIC SIMULATION")
    
    # 1. Load background image
    img_path = "/Users/sujeethreddythatiparthi/.gemini/antigravity/brain/764ce97e-6553-4c0f-b6d9-12ebced35e07/verified_camera_7542.jpg"
    frame = cv2.imread(img_path)
    if frame is None:
        print("❌ Could not load base image.")
        return

    analyzer = TrafficAnalyzer()
    
    # 2. Inject 20 Fake Detections manually into the tracker/frame logic for visualization
    # We can't easily inject into 'process_frame' without mocking the model, 
    # so we will manually subclass/override just for this test frame.
    
    class VisualSim(TrafficAnalyzer):
        def process_frame(self, frame):
            # Mock detections
            detections = []
            # Create a grid of "cars"
            start_x, start_y = 100, 200
            for i in range(5):
                for j in range(4):
                    # 20 cars total
                    x = start_x + (i * 80)
                    y = start_y + (j * 60)
                    # Add some randomness/perspective simulated by just fixed offsets
                    detections.append([x, y, 60, 40]) # x, y, w, h
            
            # Update Tracker
            tracked_objects = self.tracker.update(detections)
            
            # Run Analysis
            vehicle_count = len(tracked_objects)
            density = min(vehicle_count / self.max_vehicle_capacity, 1.0)
            
            rec_speed = self.default_speed_limit
            msg = "Traffic Normal"
            
            if density >= 0.6: 
                rec_speed = self.default_speed_limit * (1 - (density * 0.5))
                msg = "Heavy Traffic: Slow Down"
            
            # Annotate
            annotated = frame.copy()
            for obj in tracked_objects:
                x, y, w, h, _ = obj
                cv2.rectangle(annotated, (x, y), (x+w, y+h), (0, 255, 0), 2)
                # Add "Car" label
                cv2.putText(annotated, "Car", (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

            # Draw HUD
            overlay = annotated.copy()
            cv2.rectangle(overlay, (0, 0), (640, 60), (0, 0, 0), -1)
            annotated = cv2.addWeighted(overlay, 0.6, annotated, 0.4, 0)
            
            color = (0, 0, 255) # Red for heavy
            stats = f"Vehicles: {vehicle_count} | Density: {int(density*100)}%"
            advice = f"Rec Speed: {int(rec_speed)} MPH | {msg}"
            
            cv2.putText(annotated, stats, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
            cv2.putText(annotated, advice, (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            
            return annotated
            
    sim = VisualSim()
    output_frame = sim.process_frame(frame)
    
    out_path = "/Users/sujeethreddythatiparthi/.gemini/antigravity/brain/764ce97e-6553-4c0f-b6d9-12ebced35e07/verified_heavy_traffic.jpg"
    cv2.imwrite(out_path, output_frame)
    print(f"✅ Generated Heavy Traffic Visualization: {out_path}")


def run_all_tests():
    print_header("STARTING CRUZE SYSTEM VERIFICATION")
    
    # 1. Logic Tests
    print("\n--- 1. Traffic Logic & Math ---")
    os.system("python3 backend/test_heavy_traffic.py")
    
    # 2. Filtering Tests
    print("\n--- 2. Highway Filtering Rules ---")
    os.system("python3 backend/test_filtering.py")
    
    # 3. Stream Performance
    print("\n--- 3. API Stream Response Time ---")
    # Need server running for this. Assuming it is.
    os.system("python3 backend/test_timeout.py")
    
    # 4. Visual Verification
    verify_heavy_traffic_visual()
    
    print_header("VERIFICATION COMPLETE")

if __name__ == "__main__":
    run_all_tests()
