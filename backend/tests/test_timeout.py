import requests
import time

def test_timeout():
    # Camera 10291 was showing 404/timeouts in logs. 
    # Camera 8442 was showing timeouts (30s).
    
    # Let's pick a camera that was timing out.
    # From logs: "Stream timeout triggered after 30017 ms" for camera 8442 (or similar in that block)
    # Actually, let's try a few.
    
    targets = ["7542", "8442", "11330"] 
    base_url = "http://127.0.0.1:7071/api/camera_proxy/"
    
    print("Testing Camera Proxy Response Times...")
    
    for cam_id in targets:
        start = time.time()
        try:
            print(f"Requesting {cam_id}...", end="", flush=True)
            response = requests.get(base_url + cam_id, timeout=10) # Client timeout 10s
            duration = time.time() - start
            print(f" Done in {duration:.2f}s | Status: {response.status_code}")
            
            if duration > 5.0:
                print(f"❌ FAIL: Response took too long (>5s). Timeout logic might not be working.")
            else:
                print(f"✅ PASS: Response within acceptable limit.")
                
        except Exception as e:
            duration = time.time() - start
            print(f" Error in {duration:.2f}s: {e}")

if __name__ == "__main__":
    test_timeout()
