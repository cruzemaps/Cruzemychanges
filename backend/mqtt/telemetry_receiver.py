import paho.mqtt.client as mqtt
import json
import threading
from datetime import datetime

# In-memory store of active trucks for the sensor fusion pipeline
# Dictionary mapping: client_id -> { lat, lon, speed, heading, timestamp }
ACTIVE_TRUCKS = {}
TRUCK_LOCK = threading.Lock()

# Define event callbacks
def on_connect(client, userdata, flags, rc):
    print(f"📡 MQTT Receiver Connected with result code {rc}")
    # Subscribe to the truck telemetry topic
    client.subscribe("cruze/telemetry/trucks")

def on_message(client, userdata, msg):
    try:
        payload = json.loads(msg.payload.decode())
        client_id = payload.get('id')
        
        if client_id:
            with TRUCK_LOCK:
                ACTIVE_TRUCKS[client_id] = {
                    'lat': payload.get('lat'),
                    'lon': payload.get('lon'),
                    'heading': payload.get('heading'),
                    'speed': payload.get('speed'),
                    'accel': payload.get('accel'),
                    'last_seen': datetime.now().timestamp()
                }
            # Optional: Print every nth message or only new connections to avoid log spam
            # print(f"📍 [5Hz V-OBU] {client_id}: {payload.get('speed')}mph at {payload.get('lat')}, {payload.get('lon')}")
            
    except json.JSONDecodeError:
        print("⚠️ Failed to parse MQTT payload")
    except Exception as e:
        print(f"⚠️ MQTT processing error: {e}")

def get_active_trucks():
    """Returns a snapshot of currently broadcasting trucks (used by Sensor Fusion)"""
    with TRUCK_LOCK:
        # Filter out stale trucks (no broadcast in > 2 seconds)
        now = datetime.now().timestamp()
        active = {k: v for k, v in ACTIVE_TRUCKS.items() if (now - v['last_seen']) < 2.0}
        return active

def start_mqtt_receiver(broker="test.mosquitto.org", port=1883):
    """Starts the background MQTT receiver thread"""
    client = mqtt.Client(client_id="cruze_backend_receiver")
    client.on_connect = on_connect
    client.on_message = on_message

    print(f"🔌 Connecting to MQTT Broker: {broker}:{port}...")
    try:
        client.connect(broker, port, 60)
        # Start the loop in a background thread
        client.loop_start()
        print("✅ MQTT Receiver Thread Started")
    except Exception as e:
        print(f"❌ Failed to start MQTT receiver: {e}")

if __name__ == "__main__":
    import time
    start_mqtt_receiver()
    try:
        while True:
            trucks = get_active_trucks()
            print(f"Active Trucks: {len(trucks)}")
            time.sleep(2)
    except KeyboardInterrupt:
        print("Stopping receiver...")
