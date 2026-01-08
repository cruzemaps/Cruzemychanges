import json
import os
import random
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

# Setup Flask
app = Flask(__name__)
# Enable CORS for Flutter Web (localhost:7071)
CORS(app)

# --- CONFIGURATION (Borrowed from function_app.py) ---
AZURE_MAPS_KEY = os.environ.get("AZURE_MAPS_KEY", "REDACTED_AZURE_MAPS_KEY")

# Persistence
DB_FILE = "users.json"

def load_users():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r') as f: return json.load(f)
        except: pass
    return {}

def save_users(users):
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
        
    users[email] = {'password': password, 'name': name}
    save_users(users)
    
    print(f"User Created: {email}")
    return jsonify({"status": "success", "message": "User created"}), 200

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    email = data.get('email')
    password = data.get('password')
    
    users = load_users()
    user = users.get(email)
    
    if user and user['password'] == password:
        print(f"Login Success: {email}")
        return jsonify({"status": "success", "name": user['name']}), 200
    
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

@app.route('/api/route', methods=['GET'])
def get_route():
    start_lat = request.args.get('start_lat')
    start_lon = request.args.get('start_lon')
    end_lat = request.args.get('end_lat')
    end_lon = request.args.get('end_lon')
    
    if not all([start_lat, start_lon, end_lat, end_lon]):
        return jsonify({"error": "Missing coords"}), 400

    print(f"[Route] Calculating Safe Route: {start_lat},{start_lon} -> {end_lat},{end_lon}")
    
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

if __name__ == '__main__':
    print("Starting HiveMind Backend (Flask Emulation) on port 7071...")
    # Run on port 7071 to match Azure Functions default
    app.run(host='0.0.0.0', port=7071, debug=True)
