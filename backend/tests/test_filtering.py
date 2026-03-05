def is_highway(cam_data):
    if not cam_data: return False
    route = str(cam_data.get('route') or '').upper()
    # Highways: IH (Interstate), US (US Hwy), SH (State Hwy), SL (State Loop), LP (Loop), TOLL
    return route.startswith(('IH', 'US', 'SH', 'SL', 'LP', 'TOLL'))

def test_filtering():
    cameras = [
        {"id": "1", "route": "IH35", "expected": True},
        {"id": "2", "route": "US290", "expected": True},
        {"id": "3", "route": "SH71", "expected": True},
        {"id": "4", "route": "SL360", "expected": True},
        {"id": "5", "route": "LP1", "expected": True},
        {"id": "6", "route": "TOLL45", "expected": True},
        {"id": "7", "route": "FM1709", "expected": False},
        {"id": "8", "route": "Main St", "expected": False},
        {"id": "9", "route": "", "expected": False},
        {"id": "10", "route": None, "expected": False},
    ]
    
    print("Testing is_highway logic...")
    passed = 0
    for cam in cameras:
        result = is_highway(cam)
        status = "✅ PASS" if result == cam["expected"] else "❌ FAIL"
        if result == cam["expected"]: passed += 1
        print(f"Cam {cam.get('route', 'None')}: {result} | Expected: {cam['expected']} | {status}")
        
    print(f"\nResult: {passed}/{len(cameras)} Passed")

if __name__ == "__main__":
    test_filtering()
