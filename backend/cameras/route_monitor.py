import json
import time
import math
import os
import numpy as np

try:
    from shapely.geometry import LineString, Point
    from shapely.ops import nearest_points
    _SHAPELY_AVAILABLE = True
except Exception:
    _SHAPELY_AVAILABLE = False

# Simple Haversine implementation since Shapely is unavailable
def haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371  # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlon/2) * math.sin(dlon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    distance_km = R * c
    distance_miles = distance_km * 0.621371
    return distance_miles

def point_line_distance(px, py, x1, y1, x2, y2):
    # Calculate distance from point (px, py) to line segment (x1,y1)-(x2,y2)
    # Using planar approximation for short distances
    vx, vy = x2 - x1, y2 - y1
    wx, wy = px - x1, py - y1
    
    c1 = vx * wx + vy * wy
    c2 = vx * vx + vy * vy
    
    if c2 <= 0: # Start point
        return math.sqrt((px - x1)**2 + (py - y1)**2)
        
    b = c1 / c2
    if b <= 0: # Start point
        return math.sqrt((px - x1)**2 + (py - y1)**2)
    elif b >= 1: # End point
        return math.sqrt((px - x2)**2 + (py - y2)**2)
        
    # Projection falls on segment
    p_proj_x = x1 + b * vx
    p_proj_y = y1 + b * vy
    return math.sqrt((px - p_proj_x)**2 + (py - p_proj_y)**2)


class RouteManager:
    def __init__(self, cameras_file='cameras_full.json'):
        """
        Initialize with the full list of cameras.
        """
        self.all_cameras = self._load_cameras(cameras_file)
        self.route_line = None
        self.route_line_geom = None
        self.active_corridor_cameras = []
        self.current_user_location = None # (lat, lon)
        self.active_inference_cameras = [] # Subset of corridor cameras currently active

    def _resolve_camera_path(self, filepath):
        if os.path.isabs(filepath) and os.path.exists(filepath):
            return filepath
        if os.path.exists(filepath):
            return filepath
        backend_dir = os.path.dirname(os.path.dirname(__file__))
        backend_path = os.path.join(backend_dir, filepath)
        if os.path.exists(backend_path):
            return backend_path
        return filepath

    def _load_cameras(self, filepath):
        try:
            resolved_path = self._resolve_camera_path(filepath)
            with open(resolved_path, 'r') as f:
                data = json.load(f)
                cameras = data.get('cameras', [])
                # Filter out cameras without coordinates
                valid_cameras = [c for c in cameras if c.get('lat') is not None and c.get('lon') is not None]
                print(f"Loaded {len(valid_cameras)} valid cameras from {len(cameras)} total.")
                return valid_cameras
        except Exception as e:
            print(f"Error loading cameras: {e}")
            return []

    def set_route(self, route_coords):
        """
        Set the route and filter cameras within the corridor.
        :param route_coords: List of (lat, lon) tuples
        """
        if not route_coords or len(route_coords) < 2:
            print("Route set failed: need at least 2 coordinates.")
            self.route_line = None
            self.route_line_geom = None
            self.active_corridor_cameras = []
            return []

        self.route_line = route_coords
        self.active_corridor_cameras = []
        self.route_line_geom = None
        if _SHAPELY_AVAILABLE:
            self.route_line_geom = LineString([(lon, lat) for lat, lon in route_coords])
        
        # 1 Mile Buffer (~1609 meters)
        buffer_miles = 1.0 
        
        for cam in self.all_cameras:
            c_lat, c_lon = cam['lat'], cam['lon']
            
            # Check proximity to ANY segment of the route (1 mile corridor)
            if _SHAPELY_AVAILABLE and self.route_line_geom is not None:
                cam_point = Point(c_lon, c_lat)
                nearest_point = nearest_points(self.route_line_geom, cam_point)[0]
                dist_miles = haversine_distance(c_lat, c_lon, nearest_point.y, nearest_point.x)
                if dist_miles <= buffer_miles:
                    self.active_corridor_cameras.append(cam)
            else:
                for i in range(len(route_coords) - 1):
                    p1_lat, p1_lon = route_coords[i]
                    p2_lat, p2_lon = route_coords[i+1]
                    
                    # Approximate distance in degrees, then convert to miles
                    # 1 degree lat ~= 69 miles.
                    dist_deg = point_line_distance(c_lon, c_lat, p1_lon, p1_lat, p2_lon, p2_lat)
                    if dist_deg < (buffer_miles / 69.0):
                        self.active_corridor_cameras.append(cam)
                        break
        
        # Rough sort: Distance to start point
        start_lat, start_lon = route_coords[0]
        for cam in self.active_corridor_cameras:
            cam['dist_from_start'] = haversine_distance(start_lat, start_lon, cam['lat'], cam['lon'])
            
        self.active_corridor_cameras.sort(key=lambda x: x['dist_from_start'])
        print(f"Route set. Identified {len(self.active_corridor_cameras)} cameras in corridor.")
        return self.active_corridor_cameras

    def update_user_location(self, lat, lon):
        """
        Update user location and return the next N active cameras.
        """
        self.current_user_location = (lat, lon)
        
        # Find which segment user is closest to (or simply distance from start)
        if not self.route_line: return []
        
        start_lat, start_lon = self.route_line[0]
        user_dist_from_start = haversine_distance(start_lat, start_lon, lat, lon)
        
        # Next 2 cameras ahead
        upcoming_cameras = []
        for cam in self.active_corridor_cameras:
            if cam['dist_from_start'] > user_dist_from_start:
                upcoming_cameras.append(cam)
                if len(upcoming_cameras) >= 2:
                    break
        
        # Check if active set changed
        new_ids = set(c['id'] for c in upcoming_cameras)
        old_ids = set(c['id'] for c in self.active_inference_cameras)
        
        if new_ids != old_ids:
            print(f"[RouteMonitor] Activating cameras: {list(new_ids)}")
            self.active_inference_cameras = upcoming_cameras
            
        return upcoming_cameras

    def get_incident_distance(self, incident_camera_id):
        """
        Calculate distance from user to the incident camera.
        """
        if not self.current_user_location:
            return None
            
        cam = next((c for c in self.active_corridor_cameras if c['id'] == incident_camera_id), None)
        if not cam:
            return None
            
        dist = haversine_distance(self.current_user_location[0], self.current_user_location[1], cam['lat'], cam['lon'])
        return max(0.0, dist)

# Simulation Mock
def simulate_route_traversal(manager, steps=20):
    """
    Simulate user moving along the route.
    """
    if not manager.route_line:
        print("No route set.")
        return

    # User moves from Start to End directly
    p_start = manager.route_line[0]
    p_end = manager.route_line[-1]
    
    print(f"Simulating {steps} steps along route...")
    
    for i in range(steps + 1):
        ratio = i / steps
        lat = p_start[0] + (p_end[0] - p_start[0]) * ratio
        lon = p_start[1] + (p_end[1] - p_start[1]) * ratio
        
        print(f"\nStep {i}: User at {lat:.4f}, {lon:.4f}")
        active_cams = manager.update_user_location(lat, lon)
        
        # Mock Inference if active cameras exist
        for cam in active_cams:
            print(f" -> Inference Active on {cam['name']}")
        
        time.sleep(0.5)

if __name__ == "__main__":
    # Test Stub
    rm = RouteManager()
    
    # Create a mock route (Simple diagonal line for testing)
    # Assumes cameras_full.json has some data, or we mock it.
    # Since we saw cameras had null lat/lon in earlier turns, we might need synthetic data for this test.
    if not rm.all_cameras:
        print("Note: Injecting dummy cameras for testing since json might lack coords.")
        rm.all_cameras = [
            {'id': 'cam1', 'lat': 30.01, 'lon': -90.01, 'name': 'Cam 1'},
            {'id': 'cam2', 'lat': 30.02, 'lon': -90.02, 'name': 'Cam 2'},
            {'id': 'cam3', 'lat': 30.05, 'lon': -90.05, 'name': 'Cam 3'},
             {'id': 'cam4', 'lat': 30.08, 'lon': -90.08, 'name': 'Cam 4'}
        ]
        
    route = [(30.00, -90.00), (30.10, -90.10)]
    rm.set_route(route)
    simulate_route_traversal(rm)
