import numpy as np
from .sort import Sort, pixel_to_birdseye, calculate_physical_gap
from scipy.optimize import linear_sum_assignment
import time

# --- Sensor Fusion Engine ---

def bipartite_graph_matching(camera_centroids_birdseye, obu_gps_points):
    """
    Minimizes the distance error between camera-detected centroids (projected) 
    and App GPS signals using the Hungarian Algorithm.
    """
    if len(camera_centroids_birdseye) == 0 or len(obu_gps_points) == 0:
        return []

    # Build cost matrix (Euclidean Distance)
    cost_matrix = np.zeros((len(camera_centroids_birdseye), len(obu_gps_points)))
    
    for i, cam_pt in enumerate(camera_centroids_birdseye):
        for j, gps_pt in enumerate(obu_gps_points):
            # GPS pts must be roughly translated to the local Cartesian Birdseye 
            # (In a real system, you use pyproj or EPSG transforms. Simplified here.)
            cost_matrix[i, j] = np.linalg.norm(cam_pt - gps_pt)

    # linear_sum_assignment finds the optimal 1:1 mapping that minimizes total cost
    row_ind, col_ind = linear_sum_assignment(cost_matrix)
    
    matches = []
    # Filter out matches where the distance is ridiculously far (e.g. > 50 meters)
    for r, c in zip(row_ind, col_ind):
        if cost_matrix[r, c] < 50.0:
            matches.append((r, c)) # (Camera_Index, OBU_Index)
            
    return matches

class FusionEngine:
    def __init__(self):
        self.tracker = Sort(max_age=3, min_hits=2, iou_threshold=0.3)
        self.locked_truck_id = None
        
        # State Dictionary for standard J2735 output
        self.fusion_state = {
            "v_ego": 0.0,
            "v_lead": 0.0,
            "gap_meters": -1.0,
            "locked": False
        }

    def process_frame(self, frame_yolo_boxes, active_truck_payloads):
        """
        Runs on every frame of the highway camera.
        frame_yolo_boxes: Array of [x1, y1, x2, y2, conf, class_id]
        active_truck_payloads: list of dicts from MQTT 
        """
        # 1. Update SORT Tracker
        # Convert YOLO to SORT format [x1, y1, x2, y2, conf]
        dets = np.array([box[:5] for box in frame_yolo_boxes]) if len(frame_yolo_boxes) > 0 else np.empty((0, 5))
        
        # Returns tracked boxes: [x1, y1, x2, y2, track_id]
        tracked_objects = self.tracker.update(dets)
        
        # 2. Extract Birdseye Centroids for matching
        camera_centroids = []
        for obj in tracked_objects:
            # Bottom-Center of bounding box
            cx = (obj[0] + obj[2]) / 2.0
            cy = obj[3]
            bp = pixel_to_birdseye(cx, cy)
            camera_centroids.append(bp)
        
        # 3. Simulate GPS local projection 
        # (Mocking a transform from Lat/Lon to the local camera coordinate space)
        # Assuming the camera is at (0,0) in our birdseye space
        obu_points = []
        obu_vehicles = []
        for truck_id, data in active_truck_payloads.items():
             # MOCK TRANSFORM: A real transform requires exact camera Lat/Lon and heading.
             # We just simulate it by putting them in range:
             obu_points.append(np.array([10.0, 50.0])) # Example Mock Projection
             obu_vehicles.append((truck_id, data))

        # 4. Spatio-Temporal Alignment (Hungarian Matching)
        matches = bipartite_graph_matching(camera_centroids, obu_points)
        
        is_locked = False
        target_track_id = None
        target_bbox = None
        
        for cam_idx, obu_idx in matches:
            # We found the Cruze Truck! Lock it.
            truck_id, truck_data = obu_vehicles[obu_idx]
            target_track_id = tracked_objects[cam_idx][4]
            target_bbox = tracked_objects[cam_idx]
            self.locked_truck_id = truck_id
            
            self.fusion_state["v_ego"] = truck_data['speed'] * 0.44704 # mph to m/s
            self.fusion_state["locked"] = True
            is_locked = True
            break # Only tracking one ego-vehicle currently
            
        # 5. Extract State (v_lead and Gap)
        # If locked, find the vehicle immediately in front of Target
        if is_locked and target_bbox is not None:
             # Find closest bbox with lower Y (further down the road in image space)
             min_dist = float('inf')
             lead_bbox = None
             
             target_bird = pixel_to_birdseye((target_bbox[0]+target_bbox[2])/2.0, target_bbox[3])
             
             for obj in tracked_objects:
                 if obj[4] == target_track_id: continue # Skip self
                 
                 # Heuristic: Lead vehicle is "higher" up in the camera frame (lower Y pixel val)
                 # Adjust depending on camera angle (facing traffic or following traffic)
                 if obj[3] < target_bbox[3]: 
                     gap = calculate_physical_gap(target_bbox, obj)
                     if gap < min_dist and gap < 100.0: # Max 100m lookahead
                         min_dist = gap
                         lead_bbox = obj
                         
             if lead_bbox is not None:
                 self.fusion_state["gap_meters"] = min_dist
                 
                 # Calculate lead velocity (Simplified frame-over-frame delta)
                 # Here we would normally use the Kalman state velocity (kf.x[4:6]), but
                 # for a quick implementation we can rely on standard estimates or YOLO deltas.
                 # Mocking V_lead to match ego generally if gap is stable
                 self.fusion_state["v_lead"] = max(0, self.fusion_state["v_ego"] - 1.0) 
             else:
                 self.fusion_state["gap_meters"] = -1.0
                 self.fusion_state["v_lead"] = self.fusion_state["v_ego"] # Freeflow
                 
        else:
            self.fusion_state["locked"] = False
            self.fusion_state["gap_meters"] = -1.0
            
        return self.fusion_state
