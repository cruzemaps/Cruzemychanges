import requests
import json
import os

def fetch_all_txdot_cameras():
    print("📡 Fetching statewide camera data from DriveTexas (MapLarge)...")
    
    # This table ID was discovered via network inspection of drivetexas.org
    table_id = "appgeo/cameraPoint/639053895056908953"
    api_url = f"https://dtx-e-cdn.maplarge.com/Api/ProcessDirect"
    
    # Query for all cameras (take 5000 to be safe, there are ~3400)
    request_params = {
        "action": "table/query",
        "query": {
            "start": 0,
            "table": table_id,
            "take": 5000
        }
    }
    
    headers = {
        "Referer": "https://drivetexas.org/",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
    
    try:
        response = requests.get(api_url, params={"request": json.dumps(request_params)}, headers=headers, timeout=30)
        if response.status_code == 200:
            raw_data = response.json()
            if raw_data.get("success"):
                data_block = raw_data.get("data", {}).get("data", {})
                
                # Zip attributes into dictionaries
                attributes = list(data_block.keys())
                num_records = len(data_block[attributes[0]])
                
                cameras = []
                for i in range(num_records):
                    cam = {}
                    for attr in attributes:
                        cam[attr] = data_block[attr][i]
                    
                    # Map to the format used by Cruze AI Monitor
                    standardized_cam = {
                        "id": str(cam.get("id")),
                        "name": cam.get("description", "Unknown Camera"),
                        "lat": cam.get("latitude"),
                        "lon": cam.get("longitude"),
                        "httpsurl": cam.get("httpsurl"),
                        "route": cam.get("route"),
                        "jurisdiction": cam.get("jurisdiction")
                    }
                    cameras.append(standardized_cam)
                
                output_path = "backend/cameras_full.json"
                with open(output_path, "w") as f:
                    json.dump({"cameras": cameras}, f, indent=2)
                
                print(f"✅ Successfully saved {len(cameras)} cameras to {output_path}")
                return cameras
            else:
                print(f"❌ API Error: {raw_data.get('errors')}")
        else:
            print(f"❌ HTTP Error: {response.status_code}")
    except Exception as e:
        print(f"❌ Exception during fetch: {e}")
    
    return []

if __name__ == "__main__":
    fetch_all_txdot_cameras()
