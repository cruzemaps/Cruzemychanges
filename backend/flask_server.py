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

DATABASE_NAME = "cruze_db"

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

# Persistence
DB_FILE = "users.json"

def load_users():
    # Try Cosmos DB first
    container = get_container("users")
    if container:
        try:
            items = list(container.read_all_items())
            users_dict = {}
            for item in items:
                # Map Cosmos item back to local structure
                email = item.get('id')
                if email:
                    users_dict[email] = {
                        'password': item.get('password'),
                        'name': item.get('name'),
                        'safety_score': item.get('safety_score', 100), # Default 100
                        'profile_picture_url': item.get('profile_picture_url')
                    }
            return users_dict
        except Exception as e:
            print(f"Error loading users from Cosmos: {e}")
            # Fallback? No, if configured, respect it.
            return {}

    # Fallback to Local File
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r') as f: return json.load(f)
        except: pass
    return {}

def save_users(users):
    container = get_container("users")
    if container:
        # Cosmos DB Strategy: Upsert each user
        # Note: This is inefficient for bulk but fine for this demo's load.
        # Ideally we only save the CHANGED user.
        for email, data in users.items():
            item = {
                'id': email,
                'password': data.get('password'),
                'name': data.get('name'),
                'safety_score': data.get('safety_score', 100),
                'profile_picture_url': data.get('profile_picture_url')
            }
            try:
                container.upsert_item(item)
            except Exception as e:
                print(f"Error saving user {email} to Cosmos: {e}")
        return

    with open(DB_FILE, 'w') as f: json.dump(users, f)

# High Risk Zones
HIGH_RISK_ZONES = [
    {"name": "Alamo Plaza", "lat": 29.4241, "lon": -98.4936},
    {"name": "E Houston St & N Alamo St", "lat": 29.4260, "lon": -98.4861}
]

# --- ROUTES ---

@app.route('/api/signup', methods=['POST'])
def signup():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    name = data.get('name', '')
    
    if not email or not password:
        return jsonify({"error": "Missing fields"}), 400
        
    users = load_users()
    if email in users:
        return jsonify({"error": "User exists"}), 409
        
    users[email] = {'password': password, 'name': name, 'safety_score': 100} # Default 100
    save_users(users)
    
    print(f"User Created: {email}")
    return jsonify({"status": "success", "message": "User created"}), 200

@app.route('/api/update_profile', methods=['POST'])
def update_profile():
    data = request.json
    email = data.get('email')
    name = data.get('name')
    
    if not email or not name:
        return jsonify({"error": "Missing fields"}), 400
        
    users = load_users()
    if email not in users:
        return jsonify({"error": "User not found"}), 404
        
    # Update Name
    users[email]['name'] = name
    save_users(users)
    
    print(f"User Updated: {email} -> {name}")
    return jsonify({"status": "success", "message": "Profile updated"}), 200

@app.route('/api/upload_avatar', methods=['POST'])
def upload_avatar():
    if 'file' not in request.files:
        return jsonify({"error": "No file part"}), 400
    
    file = request.files['file']
    email = request.form.get('email')
    
    if file.filename == '' or not email:
        return jsonify({"error": "No selected file or email missing"}), 400
        
    if file:
        filename = secure_filename(f"{email}_avatar.png") # Force png or keep extension
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        
        # Generate URL (assuming localhost access for now)
        # In production, this would be a blob storage URL
        file_url = f"/static/uploads/{filename}"
        
        # Update User Record
        users = load_users()
        if email in users:
            users[email]['profile_picture_url'] = file_url
            save_users(users)
            
        print(f"Avatar Uploaded: {email} -> {filepath}")
        return jsonify({"status": "success", "url": file_url}), 200

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    users = load_users()
    user = users.get(email)
    
    if user and user['password'] == password:
        print(f"Login Success: {email}")
        return jsonify({
            "status": "success", 
            "name": user['name'],
            "safety_score": user.get('safety_score', 100),
            "profile_picture_url": user.get('profile_picture_url')
        }), 200
    
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
    
    if not all([start_lat, start_lon, end_lat, end_lon]):
        return jsonify({"error": "Missing coords"}), 400

    print(f"[Route] Calculating Safe Route: {start_lat},{start_lon} -> {end_lat},{end_lon} (Icy Avoid: {avoid_icy})")
    
    # Real Proxy to Azure Maps
    query = f"{start_lat},{start_lon}:{end_lat},{end_lon}"
    # Adding Truck Constraints (Vertical Slice Requirement)
    # Standard Semi Dimensions: 2.6m width, 4.1m height, 22m length, 36T weight
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

# --- INCIDENT REPORTING ---
INCIDENTS_FILE = "incidents.json"

def load_incidents():
    container = get_container("incidents")
    if container:
        try:
            items = list(container.read_all_items())
            # Convert system properties if needed, but returning dicts is fine
            return items
        except Exception as e:
             print(f"Error loading incidents from Cosmos: {e}")
             return []

    if os.path.exists(INCIDENTS_FILE):
        try:
            with open(INCIDENTS_FILE, 'r') as f: return json.load(f)
        except: pass
    return []

def save_incidents(incidents):
    container = get_container("incidents")
    if container:
        for incident in incidents:
            # Ensure ID is string for Cosmos
            if 'id' in incident:
                incident['id'] = str(incident['id'])
            
            try:
                container.upsert_item(incident)
            except Exception as e:
                print(f"Error saving incident to Cosmos: {e}")
        return

    with open(INCIDENTS_FILE, 'w') as f: json.dump(incidents, f)

@app.route('/api/report_incident', methods=['POST'])
def report_incident():
    data = request.json
    lat = data.get('lat')
    lon = data.get('lon')
    i_type = data.get('type') # crash, flat_tire, stopped
    description = data.get('description', '')
    
    if not lat or not lon or not i_type:
        return jsonify({"error": "Missing fields"}), 400
        
    incidents = load_incidents()
    new_incident = {
        "id": random.randint(1000, 9999), # Simple ID
        "lat": lat,
        "lon": lon,
        "type": i_type,
        "description": description,
        "timestamp": "Now" # In real app use datetime
    }
    
    incidents.append(new_incident)
    save_incidents(incidents)
    
    print(f"[Incident] New Report: {i_type} at {lat}, {lon}")
    return jsonify({"status": "success", "id": new_incident["id"]}), 200

@app.route('/api/incidents', methods=['GET'])
def get_incidents():
    incidents = load_incidents()
    return jsonify({"incidents": incidents}), 200

if __name__ == '__main__':
    print("Starting Cruze Backend (Flask Emulation) on port 7071...")
    # Run on port 7071 to match Azure Functions default
    app.run(host='0.0.0.0', port=7071, debug=True)
