from cameras.route_monitor import RouteManager, simulate_route_traversal
from cameras.traffic_pipeline import TrafficAnalyzer, StreamManager
import time
import random

def run_texas_simulation():
    print("🚦 Initializing Texas I-35 Traffic Monitor (SA -> Dallas)...")
    
    # 1. Setup Route: San Antonio -> Austin -> Waco -> Dallas
    route_coords = [
        (29.4241, -98.4936), # San Antonio
        (29.7030, -98.1245), # New Braunfels
        (29.8833, -97.9414), # San Marcos
        (30.2672, -97.7431), # Austin
        (31.0665, -97.3468), # Temple
        (31.5493, -97.1467), # Waco
        (32.7767, -96.7970)  # Dallas
    ]
    
    # 2. Initialize Manager
    rm = RouteManager()
    
    # 3. Data Check & Mock Injection
    # Check if we have enough valid cameras for this demo
    valid_cams = [c for c in rm.all_cameras if c.get('lat') is not None]
    
    if len(valid_cams) < 5:
        print("⚠️  Warning: Real camera data lacks coordinates. Injecting active I-35 mock cameras for simulation.")
        rm.all_cameras = [
            {'id': 'cam_sa_downtown', 'lat': 29.4250, 'lon': -98.4940, 'name': 'SA Downtown I-35', 'httpsurl': 'mock'},
            {'id': 'cam_nb_buccees', 'lat': 29.7040, 'lon': -98.1250, 'name': 'New Braunfels (Buc-ees)', 'httpsurl': 'mock'},
            {'id': 'cam_sm_outlet', 'lat': 29.8840, 'lon': -97.9420, 'name': 'San Marcos Outlets', 'httpsurl': 'mock'},
            {'id': 'cam_atx_capitol', 'lat': 30.2680, 'lon': -97.7440, 'name': 'Austin I-35 Upper Deck', 'httpsurl': 'mock'},
            {'id': 'cam_waco_silo', 'lat': 31.5500, 'lon': -97.1470, 'name': 'Waco Silos I-35', 'httpsurl': 'mock'},
            {'id': 'cam_dal_reunion', 'lat': 32.7770, 'lon': -96.7980, 'name': 'Dallas Mixmaster', 'httpsurl': 'mock'}
        ]
    
    # 4. Set Route
    print(f"📍 Setting Route: {len(route_coords)} waypoints along I-35 corridor...")
    active_corridor = rm.set_route(route_coords)
    
    if not active_corridor:
        print("❌ No cameras found in corridor! (This shouldn't happen with mocks)")
        return

    # 5. Initialize Traffic Analyzer Logic
    print("🧠 Spinning up Traffic Inference Engine...")
    analyzer = TrafficAnalyzer() 
    # Link StreamManager (Mock) - In real app, this would get updates from rm
    
    # 6. Run Simulation
    print("\n🚗 STARTING DRIVE: San Antonio -> Dallas")
    print("------------------------------------------------")
    
    # Custom simulation loop to show more detail
    steps = 20
    segment_idx = 0
    
    # Interpolate through waypoints
    # Simple logic: Move point to point
    total_segments = len(route_coords) - 1
    
    for segment in range(total_segments):
        p1 = route_coords[segment]
        p2 = route_coords[segment+1]
        
        steps_per_segment = 5
        for i in range(steps_per_segment):
            ratio = i / steps_per_segment
            lat = p1[0] + (p2[0] - p1[0]) * ratio
            lon = p1[1] + (p2[1] - p1[1]) * ratio
            
            # Update System
            active_cams = rm.update_user_location(lat, lon)
            
            # Print Status
            print(f"📍 GPS: {lat:.4f}, {lon:.4f} | Active Cameras: {len(active_cams)}")
            
            for cam in active_cams:
                dist = rm.get_incident_distance(cam['id'])
                status = "🟢 Clear"
                # Mock an incident near Austin
                if cam['id'] == 'cam_atx_capitol' and dist < 2.0:
                    status = "🔴 SLOW TRAFFIC (Mock)"
                    
                print(f"   🎥 Monitoring: {cam['name']:<25} | Dist: {dist:.1f} mi | Status: {status}")
            
            time.sleep(0.3)

    print("\n🏁 ARRIVED: Dallas")

if __name__ == "__main__":
    run_texas_simulation()
