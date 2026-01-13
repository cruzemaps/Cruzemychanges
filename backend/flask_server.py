import json
import os
import random
import logging
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename
import requests

# Setup Flask
app = Flask(__name__, static_folder='static')
# Enable CORS for Flutter Web (localhost:7071)
CORS(app)

# Ensure upload directory
UPLOAD_FOLDER = os.path.join('static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
# Enable CORS for Flutter Web (localhost:7071)
CORS(app)

# --- CONFIGURATION (Borrowed from function_app.py) ---
from dotenv import load_dotenv
load_dotenv() # Load .env file

AZURE_MAPS_KEY = os.environ.get("AZURE_MAPS_KEY", "REDACTED_AZURE_MAPS_KEY")

# Cosmos DB Configuration
COSMOS_CONNECTION_STRING = os.environ.get("COSMOS_CONNECTION_STRING")
if COSMOS_CONNECTION_STRING:
    print("✅ COSMOS DB ENABLED: Connection String Found")
else:
    print("⚠️ COSMOS DB DISABLED: Connection String Missing (Using Local Files)")

DATABASE_NAME = "CruzeDB"
CONTAINER_NAME = "CruzeDB"

def get_container(container_name):
    if not COSMOS_CONNECTION_STRING:
        return None
    try:
        from azure.cosmos import CosmosClient, PartitionKey
        client = CosmosClient.from_connection_string(COSMOS_CONNECTION_STRING)
        database = client.create_database_if_not_exists(id=DATABASE_NAME)
        
        # Partition Key: /id for users, /type for incidents (or just /id for simplicity)
        pk_path = "/id"
        
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path=pk_path),
            offer_throughput=400
        )
        return container
    except Exception as e:
        print(f"Error connecting to Cosmos DB ({container_name}): {e}")
        return None

# Persistence - COSMOS DB ONLY
def get_user_container():
    return get_container("users")

def get_incident_container():
    return get_container("incidents")

# --- ROUTES ---

@app.route('/api/signup', methods=['POST'])
def signup():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    name = data.get('name', '')
    
    if not email or not password:
        return jsonify({"error": "Missing fields"}), 400
        
    container = get_user_container()
    if not container:
        return jsonify({"error": "Database unavailable"}), 500

    # check if exists
    try:
        container.read_item(item=email, partition_key=email)
        return jsonify({"error": "User exists"}), 409
    except Exception:
        # Item not found, safe to create
        pass
        
    new_user = {
        'id': email,
        'password': password,
        'name': name,
        'safety_score': 100,
        'profile_picture_url': None
    }
    
    try:
        container.create_item(new_user)
        print(f"User Created: {email}")
        return jsonify({"status": "success", "message": "User created"}), 201
    except Exception as e:
        print(f"Error creating user: {e}")
        return jsonify({"error": "Database error"}), 500

@app.route('/api/update_profile', methods=['POST'])
def update_profile():
    data = request.json
    email = data.get('email')
    name = data.get('name')
    
    if not email or not name:
        return jsonify({"error": "Missing fields"}), 400
        
    container = get_user_container()
    if not container: return jsonify({"error": "Database unavailable"}), 500
        
    try:
        user = container.read_item(item=email, partition_key=email)
        user['name'] = name
        container.upsert_item(user)
        print(f"User Updated: {email} -> {name}")
        return jsonify({"status": "success", "message": "Profile updated"}), 200
    except Exception as e:
        return jsonify({"error": "User not found or DB error"}), 404

@app.route('/api/upload_avatar', methods=['POST'])
def upload_avatar():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    email = request.form.get('email')
    
    if file.filename == '' or not email:
        return jsonify({"error": "No selected file or email missing"}), 400
        
    if file:
        filename = secure_filename(f"{email}_avatar.png")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        file_url = f"/static/uploads/{filename}"
        
        container = get_user_container()
        if container:
            try:
                user = container.read_item(item=email, partition_key=email)
                user['profile_picture_url'] = file_url
                container.upsert_item(user)
            except Exception as e:
                print(f"Error updating avatar in DB: {e}")
            
        print(f"Avatar Uploaded: {email} -> {filepath}")
        return jsonify({"status": "success", "url": file_url}), 200

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    container = get_user_container()
    if not container: return jsonify({"error": "Database unavailable"}), 500
    
    try:
        user = container.read_item(item=email, partition_key=email)
        if user['password'] == password:
            print(f"Login Success: {email}")
            return jsonify({
                "status": "success", 
                "name": user.get('name', 'Driver'),
                "safety_score": user.get('safety_score', 100),
                "profile_picture_url": user.get('profile_picture_url')
            }), 200
    except Exception:
        # User not found
        pass
    
    return jsonify({"error": "Invalid credentials"}), 401

@app.route('/api/telemetry', methods=['POST'])
def telemetry():
    data = request.json
    if data.get('crash_detected'):
        print(f"\n[CRITICAL] 🚨 CRASH DETECTED 🚨")
        print(f"Location: {data.get('lat')}, {data.get('long')}")
        print(f"G-Force: {data.get('g_force')}\n")
    else:
        print(f"[Telemetry] G={data.get('g_force')}")
        
    return jsonify({"status": "received"}), 200

@app.route('/api/telemetry/braking', methods=['POST'])
def braking_event():
    data = request.json
    # Simulate Stream Analytics logic
    # In a real app, we'd window these events.
    print(f"\n[ALERT] 🛑 MICRO-BRAKING DETECTED! Force: {data.get('force')}g Duration: {data.get('duration')}ms")
    return jsonify({"status": "alert_logged"}), 200

@app.route('/api/telemetry/pothole', methods=['POST'])
def pothole_event():
    data = request.json
    print(f"\n[SEISMOGRAPH] 🕳️ POTHOLE DETECTED! Severity: {data.get('severity')}g Location: {data.get('lat')}, {data.get('lon')}")
    return jsonify({"status": "mapped"}), 200

@app.route('/api/diagnostics/log', methods=['POST'])
def diagnostics_log():
    data = request.json
    print(f"\n[SONIC] 🔊 VIBRATION ANOMALY! Jerk Score: {data.get('score')} (Threshold: {data.get('threshold')})")
    return jsonify({"status": "logged", "advice": "Check Suspension"}), 200

@app.route('/api/blackbox/upload', methods=['POST'])
def blackbox_upload():
    data = request.json
    # In reality: Save to Azure Blob Storage (Immutable WORM policy)
    print(f"\n[BLACK BOX] 📦 FORENSIC LOG RECEIVED! Events: {len(data.get('log', []))} Timestamp: {data.get('timestamp')}")
    return jsonify({"status": "secured", "url": "https://azure.blob/forensics/log_123.json"}), 200

@app.route('/api/roads/curvature', methods=['GET'])
def get_curvature():
    # Mocking a sharp curve nearby
    # In reality: lookup based on lat/lon in Azure Maps Data
    return jsonify({
        "radius": 40.0, # meters (Sharp Turn)
        "bank_angle": 5.0, # degrees
        "safe_speed": 25.0 # mph
    }), 200


# Mock SPaT Data (Signal Phase and Timing)
@app.route('/api/signals', methods=['GET'])
def get_signals():
    # In reality: Query City DOT API based on lat/lon
    # Mocking a signal 500m ahead
    return jsonify({
        "next_signal_dist": 500, # meters
        "time_to_green": random.randint(5, 30), # seconds remaining on RED
        "state": "RED" if random.random() > 0.5 else "GREEN",
        "recommended_speed": 35 # mph
    }), 200

# Virtual Platooning (Simple Polling Queue)
platoon_messages = []

@app.route('/api/platoon/message', methods=['POST'])
def send_platoon_message():
    data = request.json
    msg = {
        "id": random.randint(10000, 99999),
        "sender": data.get("sender", "Unknown"),
        "type": data.get("type", "INFO"), # BRAKING, POTHOLE, INFO
        "content": data.get("content", ""),
        "timestamp": random.randint(1000000, 9999999) # Mock TS
    }
    platoon_messages.append(msg)
    # Keep last 50
    if len(platoon_messages) > 50:
        platoon_messages.pop(0)
    print(f"[Platoon] 💬 Message: {msg['type']} - {msg['content']}")
    return jsonify({"status": "sent", "id": msg["id"]}), 200

@app.route('/api/platoon/messages', methods=['GET'])
def get_platoon_messages():
    # Return last 10
    return jsonify({"messages": platoon_messages[-10:]}), 200

# Predictive Lane Optimization (Mock Digital Twins)
@app.route('/api/lanes', methods=['GET'])
def get_lane_recommendation():
    # lat = request.args.get('lat')
    # Mocking logic based on random
    # In reality: Query Azure Digital Twins for segment flow
    r = random.random()
    if r < 0.3:
        return jsonify({"lane": "LEFT", "reason": "Flow +15%", "icon": "MERGE_LEFT"}), 200
    elif r < 0.6:
         return jsonify({"lane": "RIGHT", "reason": "Avoid Exit Queue", "icon": "MERGE_RIGHT"}), 200
    else:
        return jsonify({"lane": "CENTER", "reason": "Optimal Flow", "icon": "STRAIGHT"}), 200

@app.route('/api/route', methods=['GET'])
def get_route():
    start_lat = request.args.get('start_lat')
    start_lon = request.args.get('start_lon')
    end_lat = request.args.get('end_lat')
    end_lon = request.args.get('end_lon')
    avoid_icy = request.args.get('avoid_icy', 'false').lower() == 'true'
    is_truck = request.args.get('is_truck', 'false').lower() == 'true'
    
    if not all([start_lat, start_lon, end_lat, end_lon]):
        return jsonify({"error": "Missing coords"}), 400

    print(f"[Route] Calculating Safe Route: {start_lat},{start_lon} -> {end_lat},{end_lon} (Icy: {avoid_icy}, Truck: {is_truck})")
    
    # Real Proxy to Azure Maps
    query = f"{start_lat},{start_lon}:{end_lat},{end_lon}"
    
    # Dynamic Truck Params
    truck_params = ""
    if is_truck:
        truck_params = "&travelMode=truck&vehicleWidth=2.6&vehicleHeight=4.1&vehicleLength=22.0&vehicleWeight=36000"
    
    # Risk Avoidance (Hackathon Winner Feature)
    # Avoiding rectangular area covering the mocked "High Risk Zones"
    # Format: minLon,minLat,maxLon,maxLat
    # Example Zone: 29.5547, -98.6630 (Bandera) to 29.4241, -98.4936 (Alamo)
    # We construct a avoidAreas parameter. 
    # Azure expects: avoidAreas=minLon,minLat,maxLon,maxLat
    # Let's avoid the "Alamo Plaza" area specifically for the demo:
    # 29.4230, -98.4950 to 29.4250, -98.4900
    risk_params = "&avoidAreas=-98.4950,29.4230,-98.4900,29.4250"

    # Changed instructionsType to 'tagged' for better parsing if needed, though we might use text for simple regex.
    url = f"https://atlas.microsoft.com/route/directions/json?api-version=1.0&query={query}&subscription-key={AZURE_MAPS_KEY}&routeRepresentation=polyline&instructionsType=tagged{truck_params}{risk_params}"
    
    try:
        azure_res = requests.get(url)
        return jsonify(azure_res.json()), azure_res.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Speed Limit Logic
def get_speed_limit_data(lat, lon):
    # Using Search Address Reverse API with returnSpeedLimit=true
    # This is the standard way to get speed limit for a coordinate
    base_url = "https://atlas.microsoft.com/search/address/reverse/json"
    
    params = {
        "api-version": "1.0",
        "subscription-key": AZURE_MAPS_KEY,
        "query": f"{lat},{lon}",
        "returnSpeedLimit": "true",
        "number": 1 # Only need 1 result
    }

    try:
        response = requests.get(base_url, params=params)
        try:
            data = response.json()
        except Exception:
            return {"error": f"JSON Decode Error. Status: {response.status_code}. Body: {response.text[:200]}"}
        
        # Parse the speed limit from the response
        if 'addresses' in data and len(data['addresses']) > 0:
            address_data = data['addresses'][0]
            limit_data = address_data.get('speedLimit')
            
            if limit_data:
                # Format is usually "60 km/h" or similar string
                # Example: "60 KPH"
                val_str = limit_data.split(' ')[0]
                unit_str = ""
                if ' ' in limit_data:
                    unit_str = limit_data.split(' ')[1]
                
                try:
                    val = int(float(val_str)) # Handle "60.0"
                    if "KPH" in unit_str.upper() or "KM/H" in unit_str.upper():
                         # Convert to MPH: 1 KPH = 0.621371 MPH
                         val_mph = int(val * 0.621371)
                         return {"limit": val_mph, "unit": "MPH", "original": limit_data}
                    elif "MPH" in unit_str.upper():
                         return {"limit": val, "unit": "MPH", "original": limit_data}
                except:
                    pass
                    
                return {"limit": limit_data, "unit": "RAW", "original": limit_data}
            else:
                 # Check if street name is available but no speed limit
                 street = address_data.get('address', {}).get('streetName', 'Unknown Road')
                 return {"error": f"Speed limit not available for {street}"}
        else:
            return {"error": "Address not found"}
            
    except Exception as e:
        return {"error": str(e)}

@app.route('/api/speed_limit', methods=['GET'])
def get_speed_limit_endpoint():
    lat = request.args.get('lat')
    lon = request.args.get('lon')
    
    if not lat or not lon:
        return jsonify({"error": "Missing lat/lon"}), 400
        
    result = get_speed_limit_data(lat, lon)
    return jsonify(result), 200

@app.route('/api/report_incident', methods=['POST'])
def report_incident():
    data = request.json
    lat = data.get('lat')
    lon = data.get('lon')
    i_type = data.get('type') # crash, flat_tire, stopped
    description = data.get('description', '')
    
    if not lat or not lon or not i_type:
        return jsonify({"error": "Missing fields"}), 400
        
    container = get_incident_container()
    if not container: return jsonify({"error": "Database unavailable"}), 500

    new_incident = {
        "id": str(random.randint(1000, 9999)), # ID must be string
        "lat": lat,
        "lon": lon,
        "type": i_type,
        "description": description,
        "timestamp": "Now" # In real app use datetime
    }
    
    try:
        container.create_item(new_incident)
        print(f"[Incident] New Report: {i_type} at {lat}, {lon}")
        return jsonify({"status": "success", "id": new_incident["id"]}), 201
    except Exception as e:
        print(f"Error saving incident: {e}")
        return jsonify({"error": "DB Error"}), 500

@app.route('/api/incidents', methods=['GET'])
def get_incidents():
    container = get_incident_container()
    if not container: return jsonify({"error": "Database unavailable"}), 500
    
    try:
        # Simple query to get all items
        items = list(container.query_items(
            query="SELECT * FROM c",
            enable_cross_partition_query=True
        ))
        return jsonify({"incidents": items}), 200
    except Exception as e:
        print(f"Error fetching incidents: {e}")
        return jsonify({"incidents": []}), 200

if __name__ == '__main__':
    print("Starting Cruze Backend (Flask Emulation) on port 7071...")
    # Run on port 7071 to match Azure Functions default
    app.run(host='0.0.0.0', port=7071, debug=True)
