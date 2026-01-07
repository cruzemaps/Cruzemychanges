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
    url = f"https://atlas.microsoft.com/route/directions/json?api-version=1.0&query={query}&subscription-key={AZURE_MAPS_KEY}&routeRepresentation=polyline&instructionsType=text"
    
    try:
        azure_res = requests.get(url)
        return jsonify(azure_res.json()), azure_res.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("Starting HiveMind Backend (Flask Emulation) on port 7071...")
    # Run on port 7071 to match Azure Functions default
    app.run(host='0.0.0.0', port=7071, debug=True)
