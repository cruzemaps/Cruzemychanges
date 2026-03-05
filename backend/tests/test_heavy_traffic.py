import cv2
import time
from cameras.traffic_pipeline import TrafficAnalyzer

# Mock class to simulate heavy traffic detections without needing a real heavy traffic image
class HeavyTrafficSim(TrafficAnalyzer):
    def process_frame(self, frame):
        timestamp = time.time()
        
        # 1. Skip Enhancement (not needed for logic test)
        processed_frame = frame
        
        # 2. Mock Detections: Create 20 fake boxes
        # Max capacity is 25. 20/25 = 0.8 density (80%).
        detections = []
        for i in range(20):
            # Just some random boxes
            detections.append([100 + i*10, 100 + i*10, 50, 50])

        # 2. Custom Tracking
        tracked_objects = self.tracker.update(detections)
        
        # 3. Analytics & Speed Advice Logic (Copied/Inherited from original, but we verify the output)
        vehicle_count = len(tracked_objects)
        density = min(vehicle_count / self.max_vehicle_capacity, 1.0)
        
        recommended_speed = self.default_speed_limit
        advice_message = "Traffic Normal"
        
        if density >= 0.6: 
            recommended_speed = self.default_speed_limit * (1 - (density * 0.5))
            advice_message = "Heavy Traffic: Slow Down"
        elif density >= 0.3:
            recommended_speed = self.default_speed_limit * 0.85
            advice_message = "Moderate Traffic"
            
        recommended_speed = int(recommended_speed)
        
        print(f"\n--- Heavy Traffic Simulation ---")
        print(f"Simulated Vehicles: {vehicle_count}")
        print(f"Density: {density:.2f} (Target: > 0.6)")
        print(f"Recommended Speed: {recommended_speed} MPH (Default: {self.default_speed_limit})")
        print(f"Message: {advice_message}")
        
        return processed_frame, [], {
            "vehicle_count": vehicle_count,
            "density": density,
            "recommended_speed": recommended_speed,
            "message": advice_message
        }

def run_simulation():
    sim = HeavyTrafficSim()
    # Dummy frame
    import numpy as np
    dummy = np.zeros((640, 640, 3), dtype=np.uint8)
    sim.process_frame(dummy)

if __name__ == "__main__":
    run_simulation()
