import flask_server
import json


def test_api():
    app = flask_server.app
    client = app.test_client()
    
    print("\n🧪 Testing Route Monitor API Integration...")
    
    # 1. Test Set Route
    route_payload = {
        "route": [
            [29.4241, -98.4936],
            [30.2672, -97.7431] # SA to Austin
        ]
    }
    
    response = client.post('/api/set_route', 
                           data=json.dumps(route_payload),
                           content_type='application/json')
    
    print(f"POST /api/set_route Status: {response.status_code}")
    print(f"Response: {response.json}")
    
    if response.status_code == 200 and response.json.get('cameras_in_corridor') > 0:
        print("✅ Route Set Successfully")
    else:
        print("❌ Route Set Failed")

    # 2. Test Update Location
    loc_payload = {"lat": 29.4300, "lon": -98.4900}
    response = client.post('/api/update_location',
                           data=json.dumps(loc_payload),
                           content_type='application/json')

    print(f"POST /api/update_location Status: {response.status_code}")
    print(f"Response: {response.json}")
    
    if response.status_code == 200:
        print("✅ Location Update Successful")
        active = response.json.get('active_cameras', [])
        print(f"Active Cameras: {len(active)}")
    else:
        print("❌ Location Update Failed")

if __name__ == "__main__":
    test_api()
