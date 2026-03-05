import cv2
import numpy as np
import time
from datetime import datetime
from ultralytics import YOLO

class EuclideanTracker:
    def __init__(self, dist_threshold=50):
        self.center_points = {} # id: (cx, cy)
        self.id_count = 0
        self.dist_threshold = dist_threshold

    def update(self, boxes):
        # boxes: list of [x, y, w, h]
        objects_bbs_ids = []
        
        for box in boxes:
            x, y, w, h = box
            cx = (x + x + w) // 2
            cy = (y + y + h) // 2
            
            same_object_detected = False
            for id, pt in self.center_points.items():
                dist = math.hypot(cx - pt[0], cy - pt[1])
                if dist < self.dist_threshold:
                    self.center_points[id] = (cx, cy)
                    objects_bbs_ids.append([x, y, w, h, id])
                    same_object_detected = True
                    break
            
            if not same_object_detected:
                self.center_points[self.id_count] = (cx, cy)
                objects_bbs_ids.append([x, y, w, h, self.id_count])
                self.id_count += 1
                
        # Clean up old ids
        new_center_points = {}
        for obj in objects_bbs_ids:
            _, _, _, _, object_id = obj
            center = self.center_points[object_id]
            new_center_points[object_id] = center
        self.center_points = new_center_points.copy()
        
        return objects_bbs_ids

import math

class TrafficAnalyzer:
    def __init__(self, model_path='yolov8n.pt', calibration_factor=0.05):
        try:
            self.model = YOLO('yolo11n.pt') 
            print("Loaded YOLO11n")
        except:
            print("YOLO11n not found, falling back to yolov8n.pt")
            self.model = YOLO('yolov8n.pt')

        self.tracker = EuclideanTracker()
        
        # Analytics State
        self.calibration_factor = calibration_factor
        self.previous_positions = {} 
        self.vehicle_speeds = {} 
        self.anomalies = []
        
        # Configuration
        self.accident_threshold_mph = 40
        self.standstill_speed_threshold_mph = 5
        self.standstill_density_threshold = 5 
        
        # Night-time Enhancement Config
        self.night_mode_threshold = 85  # Average pixel intensity threshold (0-255)
        self.gamma_correction = 1.5     # Gamma value for darkening/brightening

        # Traffic Density & Speed Advice Config
        self.max_vehicle_capacity = 25  # Max estimated vehicles in view for 100% density
        self.default_speed_limit = 65   # MPH
        
    def process_frame(self, frame, roi_polygon=None):
        timestamp = time.time()
        
        # 1. Enhance specific frames (Night Mode)
        processed_frame = self._enhance_night_frame(frame)

        # 2. Detection (No internal tracking)
        # Classes: 2=car, 3=motorcycle, 5=bus, 7=truck
        results = self.model(processed_frame, classes=[2, 3, 5, 7], verbose=False)[0]
        
        detections = []
        if results.boxes:
            for box in results.boxes.xywh.cpu().numpy():
                x, y, w, h = box
                # YOLO xywh is center_x, center_y, width, height
                x_c, y_c, w, h = x, y, w, h
                x_tl = int(x_c - w/2)
                y_tl = int(y_c - h/2)
                
                # Check ROI
                if roi_polygon is not None:
                    # check if center is in polygon
                    point = (float(x_c), float(y_c))
                    roi_pts = np.array(roi_polygon, dtype=np.int32)
                    # pointPolygonTest returns >0 if inside, 0 if on edge, <0 if outside
                    dist = cv2.pointPolygonTest(roi_pts, point, False)
                    if dist < 0:
                        continue # Skip this vehicle, it's outside the ROI

                detections.append([x_tl, y_tl, int(w), int(h)])

        # 2. Custom Tracking
        tracked_objects = self.tracker.update(detections)
        
        # 3. Analytics & Speed Advice
        # Calculate Density
        vehicle_count = len(tracked_objects)
        density = min(vehicle_count / self.max_vehicle_capacity, 1.0) # Cap at 1.0
        
        # Calculate Recommended Speed
        recommended_speed = self.default_speed_limit
        advice_message = "Traffic Normal"
        
        if density >= 0.6: # Heavy Traffic (>60%)
            # Reduce speed significantly
            recommended_speed = self.default_speed_limit * (1 - (density * 0.5))
            advice_message = "Heavy Traffic: Slow Down"
        elif density >= 0.3: # Moderate
            recommended_speed = self.default_speed_limit * 0.85
            advice_message = "Moderate Traffic"
            
        recommended_speed = int(recommended_speed)

        self._analyze_traffic(tracked_objects, timestamp)
        
        # 4. Annotate
        annotated_frame = processed_frame.copy() # Use processed frame (enhanced)
        
        # Draw Objects (Green Boxes)
        for obj in tracked_objects:
            x, y, w, h, id = obj
            speed = self.vehicle_speeds.get(id, 0)
            label = f"#{id}"
            cv2.rectangle(annotated_frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
            # cv2.putText(annotated_frame, label, (x, y-5), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)
            
        # Draw HUD (Speed Advice)
        overlay = annotated_frame.copy()
        cv2.rectangle(overlay, (0, 0), (640, 60), (0, 0, 0), -1)
        annotated_frame = cv2.addWeighted(overlay, 0.6, annotated_frame, 0.4, 0)
        
        color = (0, 255, 0) if density < 0.5 else (0, 165, 255) if density < 0.7 else (0, 0, 255)
        stats = f"Vehicles: {vehicle_count} | Density: {int(density*100)}%"
        advice = f"Rec Speed: {recommended_speed} MPH | {advice_message}"
        
        cv2.putText(annotated_frame, stats, (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
        cv2.putText(annotated_frame, advice, (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)
            
        # Draw ROI Polygon if provided
        if roi_polygon is not None:
            cv2.polylines(annotated_frame, [np.int32(roi_polygon)], isClosed=True, color=(255, 0, 0), thickness=2)
            cv2.putText(annotated_frame, "HIGHWAY ROI ENFORCED", (10, 75), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 1)

        analysis_data = {
            "vehicle_count": vehicle_count,
            "density": density,
            "recommended_speed": recommended_speed,
            "message": advice_message
        }
            
        return annotated_frame, self.anomalies, analysis_data

    def _analyze_traffic(self, tracked_objects, current_time):
        self.anomalies = []
        current_speeds = []
        
        for obj in tracked_objects:
            x, y, w, h, id = obj
            cx = x + w//2
            cy = y + h//2
            
            if id in self.previous_positions:
                prev_x, prev_y, prev_time = self.previous_positions[id]
                dist = math.hypot(cx - prev_x, cy - prev_y)
                time_delta = current_time - prev_time
                
                if time_delta > 0:
                    speed_px = dist / time_delta
                    speed_mph = speed_px * self.calibration_factor
                    
                    prev_speed = self.vehicle_speeds.get(id, speed_mph)
                    avg_speed = (prev_speed * 0.7) + (speed_mph * 0.3)
                    self.vehicle_speeds[id] = avg_speed
                    current_speeds.append(avg_speed)
                    
                    if prev_speed > self.accident_threshold_mph and avg_speed < 1:
                        self.anomalies.append({
                            "type": "ACCIDENT_POTENTIAL",
                            "id": id,
                            "desc": f"Vehicle {id} stopped abruptly"
                        })
            
            self.previous_positions[id] = (cx, cy, current_time)
            
        if len(current_speeds) > self.standstill_density_threshold:
            avg_traffic = sum(current_speeds) / len(current_speeds)
            if avg_traffic < self.standstill_speed_threshold_mph:
                 self.anomalies.append({"type": "STANDSTILL", "desc": "Traffic standstill"})

    def detect_construction(self, frame):
        pass

    def _enhance_night_frame(self, frame):
        """
        Detects if the frame is too dark and applies enhancement (CLAHE + Gamma).
        """
        # Convert to HSV to check brightness (Value channel)
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        h, s, v = cv2.split(hsv)
        avg_brightness = np.mean(v)
        
        if avg_brightness < self.night_mode_threshold:
            # It's dark! Apply Night Mode Enhancement
            
            # 1. CLAHE (Contrast Limited Adaptive Histogram Equalization)
            clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
            v_enhanced = clahe.apply(v)
            
            # 2. Merge back
            hsv_enhanced = cv2.merge([h, s, v_enhanced])
            enhanced_frame = cv2.cvtColor(hsv_enhanced, cv2.COLOR_HSV2BGR)
            
            # 3. Optional Gamma Correction for further brightness
            invGamma = 1.0 / self.gamma_correction
            table = np.array([((i / 255.0) ** invGamma) * 255 for i in np.arange(0, 256)]).astype("uint8")
            enhanced_frame = cv2.LUT(enhanced_frame, table)
            
            return enhanced_frame
            
        return frame

# Mock for processing 800+ streams (Stream Manager)
class StreamManager:
    def __init__(self, sources, analyzer):
        self.sources = sources
        self.analyzer = analyzer
        
    def process_streams_mock(self, duration_sec=5):
        """
        Simulate processing multiple streams by iterating through them with a frame sampler.
        """
        print(f"Starting Traffic Intelligence for {len(self.sources)} streams...")
        print(f"Sampling Rate: 3 FPS (Every 10th frame @ 30fps source)")
        
        start_time = time.time()
        frame_count = 0
        
        # Simulate a loop
        while time.time() - start_time < duration_sec:
            frame_count += 1
            
            # Processing loop uses dynamic self.sources list
            current_sources = list(self.sources) # Snapshot for this iteration
            
            # Mock getting a frame for each source
            for src in current_sources:
                # In real life: frame = src.read()
                # Here: Create dummy frame
                dummy_frame = np.zeros((640, 640, 3), dtype=np.uint8)
                
                # Only process every 10th frame (Mock 3 FPS)
                if frame_count % 10 == 0:
                    annotated, anomalies = self.analyzer.process_frame(dummy_frame)
                    if anomalies:
                        print(f"[STREAM {src}] ANOMALY: {anomalies}")
            
            time.sleep(0.01) # Simulate processing time
            
        print("Stream processing finished.")

    def update_streams(self, new_sources):
        """
        Update the list of active streams dynamically.
        :param new_sources: List of source IDs/URLs
        """
        # In a real implementation with threads, we would start/stop threads here.
        # For this mock, we just update the list.
        self.sources = new_sources
        print(f"[StreamManager] Active streams updated: {len(self.sources)} streams active.")
