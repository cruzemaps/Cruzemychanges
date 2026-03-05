from cameras.traffic_pipeline import TrafficAnalyzer, StreamManager
from cameras.route_monitor import RouteManager, simulate_route_traversal
import cv2
import numpy as np

def verify_pipeline():
    print("Initializing TrafficAnalyzer...")
    analyzer = TrafficAnalyzer()
    
    print("Testing StreamManager Logic...")
    # Mocking 800 streams (just string IDs)
    streams = [f"camera_{i}" for i in range(800)]
    manager = StreamManager(streams, analyzer)
    
    # Run mock processing
    manager.process_streams_mock(duration_sec=1)
    
    print("\n--- Testing Route Monitor ---")
    rm = RouteManager()
    
    # Inject dummy cameras for testing route logic if needed
    if not rm.all_cameras:
        print("Injecting dummy cameras with coordinates...")
        rm.all_cameras = [
            {'id': 'cam_start', 'lat': 30.01, 'lon': -90.01, 'name': 'Cam Start', 'httpsurl': 'mock'},
            {'id': 'cam_mid', 'lat': 30.05, 'lon': -90.05, 'name': 'Cam Mid', 'httpsurl': 'mock'},
            {'id': 'cam_end', 'lat': 30.09, 'lon': -90.09, 'name': 'Cam End', 'httpsurl': 'mock'},
            {'id': 'cam_far', 'lat': 31.00, 'lon': -91.00, 'name': 'Cam Far', 'httpsurl': 'mock'}
        ]

    # Build a route that intersects real camera locations
    # Use three distinct cameras to form the route polyline
    route = []
    unique_points = []
    for cam in rm.all_cameras:
        lat = cam.get('lat')
        lon = cam.get('lon')
        if lat is None or lon is None:
            continue
        if abs(lat) > 90 or abs(lon) > 180:
            continue
        point = (round(lat, 6), round(lon, 6))
        if point not in unique_points:
            unique_points.append(point)
        if len(unique_points) >= 3:
            break

    if len(unique_points) >= 3:
        route = unique_points[:3]
    else:
        route = [(30.00, -90.00), (30.10, -90.10)]

    print(f"Setting route: {route}")
    active_cams = rm.set_route(route)
    
    print(f"Cameras in corridor: {len(active_cams)}")
    for c in active_cams:
        print(f" - {c['name']} (Dist: {c['dist_from_start']:.4f})")
        
    if len(active_cams) >= 3:
        print("✅ Route Filtering Verified: Identified 3+ cameras in corridor.")
    else:
        print(f"❌ Route Filtering Failed: Expected 3+, got {len(active_cams)}")

    print("\nStarting Simulation...")
    simulate_route_traversal(rm, steps=10)
    
    print("\n✅ Universal Route-Aware Monitor verification complete.")

if __name__ == "__main__":
    verify_pipeline()
