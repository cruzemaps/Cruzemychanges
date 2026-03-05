import requests
import cv2
import numpy as np

def fetch_and_save(camera_id, filename):
    url = f"http://127.0.0.1:7071/api/camera_proxy/{camera_id}"
    print(f"Fetching {url}...")
    try:
        response = requests.get(url, timeout=30)
        if response.status_code == 200:
            with open(filename, 'wb') as f:
                f.write(response.content)
            print(f"Saved to {filename}")
            
            # Verify it's a valid image
            nparr = np.frombuffer(response.content, np.uint8)
            img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            if img is not None:
                print(f"Image shape: {img.shape}")
                print(f"Average brightness: {np.mean(img)}")
            else:
                print("Failed to decode image with OpenCV")
        else:
            print(f"Failed: {response.status_code}")
            print(response.text[:100])
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    fetch_and_save('7542', 'debug_7542.jpg')
    fetch_and_save('10464', 'debug_10464.jpg')
