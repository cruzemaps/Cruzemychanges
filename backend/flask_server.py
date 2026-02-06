import json
import os
import random
import logging
from flask import Flask, request, jsonify, send_from_directory, render_template
from flask_cors import CORS
from api_key_check import require_txdot_key
from werkzeug.utils import secure_filename
import requests
from azure.core.credentials import AzureKeyCredential
from azure.maps.route import MapsRouteClient
from azure.maps.search import MapsSearchClient
# Route Monitor Imports
from route_monitor import RouteManager
from traffic_pipeline import TrafficAnalyzer, StreamManager
from lane_matching import get_lane_geometry, match_lane



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
HERE_HD_KEY = os.environ.get("HERE_HD_KEY")

# Initialize Azure Maps Clients
maps_credential = AzureKeyCredential(AZURE_MAPS_KEY)
route_client = MapsRouteClient(credential=maps_credential)
search_client = MapsSearchClient(credential=maps_credential)


# Cosmos DB Configuration
COSMOS_CONNECTION_STRING = os.environ.get("COSMOS_CONNECTION_STRING") or "REDACTED_COSMOS_CONNECTION_STRING"
if COSMOS_CONNECTION_STRING:
   print("✅ COSMOS DB ENABLED: Connection String Found")
else:
   print("⚠️ COSMOS DB DISABLED: Connection String Missing (Using Local Files)")


# ... (Keep imports)


# Cosmos DB Configuration
# ... (Keep connection string logic)


DATABASE_NAME = "cruze_db" # Ensure this matches your Azure Database name if pre-created
CONTAINER_NAME = "CruzeDB"


def get_container():
   if not COSMOS_CONNECTION_STRING:
       return None
   try:
       from azure.cosmos import CosmosClient, PartitionKey
       client = CosmosClient.from_connection_string(COSMOS_CONNECTION_STRING)
       database = client.create_database_if_not_exists(id=DATABASE_NAME)
      
       # Partition Key: /id is standard
       container = database.create_container_if_not_exists(
           id=CONTAINER_NAME,
           partition_key=PartitionKey(path="/id")
       )
       return container
   except Exception as e:
       print(f"Error connecting to Cosmos DB: {e}")
       return None


# Persistence
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(BASE_DIR, "users.json")


def load_users():
    users_dict = {}
    
    # 1. Load from local fallback first
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r') as f:
                users_dict.update(json.load(f))
        except: pass

    # 2. Merge from Cosmos DB if available
    container = get_container()
    if container:
        try:
            query = "SELECT * FROM c WHERE c.entity_type = 'user'"
            items = list(container.query_items(query=query, enable_cross_partition_query=True))
            for item in items:
                email = item.get('id')
                if email:
                    users_dict[email] = {
                        'password': item.get('password'),
                        'name': item.get('name'),
                        'safety_score': item.get('safety_score', 100),
                        'profile_picture_url': item.get('profile_picture_url')
                    }
        except Exception as e:
            print(f"Error loading users from Cosmos: {e}")
            
    return users_dict


def save_users(users):
   container = get_container()
   if container:
       for email, data in users.items():
           item = {
               'id': email,
               'entity_type': 'user',  # Discriminator
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


# ... (High Risk Zones)


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
      
   users[email] = {'password': password, 'name': name, 'safety_score': 100}
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


@app.route('/api/route', methods=['GET'])
def get_route():
    start_lat = request.args.get('start_lat')
    start_lon = request.args.get('start_lon')
    end_lat = request.args.get('end_lat')
    end_lon = request.args.get('end_lon')
   
    if not all([start_lat, start_lon, end_lat, end_lon]):
        return jsonify({"error": "Missing coords"}), 400

    print(f"[Route] Calculating Safe Route (SDK): {start_lat},{start_lon} -> {end_lat},{end_lon}")
    
    try:
        route_points = [(float(start_lat), float(start_lon)), (float(end_lat), float(end_lon))]
        
        # Risk Avoidance area (Hackathon Winner Feature)
        # 29.4230, -98.4950 to 29.4250, -98.4900
        avoid_areas = "-98.4950,29.4230,-98.4900,29.4250"

        response = route_client.get_route_directions(
            route_points=route_points,
            travel_mode="truck",
            vehicle_width=2.6,
            vehicle_height=4.1,
            vehicle_length=22.0,
            vehicle_weight=36000,
            instructions_type="tagged",
            params={"avoidAreas": avoid_areas}
        )
        return jsonify(response.as_dict()), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# Speed Limit Logic (Refactored to check SDK support)
def get_speed_limit_data(lat, lon):
    try:
        # SDK get_reverse_geocoding uses [longitude, latitude]
        response = search_client.get_reverse_geocoding(
            coordinates=[float(lon), float(lat)]
        )
        response_dict = response.as_dict() if hasattr(response, "as_dict") else response
        
        # Note: Speed limit is currently best retrieved via V1 REST API in some scenarios.
        # If the SDK dict doesn't contain it yet (preview), we fallback gracefully
        # or use the address data for logging.
        
        if 'features' in response_dict and len(response_dict['features']) > 0:
            feature = response_dict['features'][0]
            properties = feature.get('properties', {})
            address = properties.get('address', {})
            street = address.get('streetName', 'Unknown Road')
            
            # The V2 SDK might not return speedLimit in the same way as V1 yet.
            # In a real app, we would check for it here.
            return {"error": f"Speed limit not currently available via SDK for {street}"}
        else:
            return {"error": "Location not found"}
           
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
   container = get_container()
   if container:
       try:
           # Filter for incidents
           query = "SELECT * FROM c WHERE c.entity_type = 'incident'"
           items = list(container.query_items(query=query, enable_cross_partition_query=True))
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
   container = get_container()
   if container:
       for incident in incidents:
           # Ensure ID is string for Cosmos
           if 'id' in incident:
               incident['id'] = str(incident['id'])
          
           # Add Discriminator
           incident['entity_type'] = 'incident'
          
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


@app.route('/api/cameras', methods=['GET'])
def get_cameras():
    from ai_monitor import CAMERAS
    return jsonify({"cameras": CAMERAS}), 200


@app.route('/api/camera_proxy/<camera_id>', methods=['GET'])
def camera_proxy(camera_id):
    url = f"https://its.txdot.gov/ITS_Servers/CCTV/Image/{camera_id}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, timeout=5, headers=headers)
        if response.status_code == 200:
            return response.content, 200, {'Content-Type': 'image/jpeg'}
        return f"Camera {camera_id} not available (Status: {response.status_code})", 404
    except Exception as e:
        return str(e), 500

# --- TRAFFIC STATUS STORAGE ---
TRAFFIC_STATUS = []

@app.route('/api/traffic_update', methods=['POST'])
def traffic_update():
    global TRAFFIC_STATUS
    data = request.json
    if 'traffic' in data:
        TRAFFIC_STATUS = data['traffic']
        return jsonify({"status": "updated"}), 200
    return jsonify({"error": "No data"}), 400

@app.route('/api/traffic_status', methods=['GET'])
def get_traffic_status():
    return jsonify({"traffic": TRAFFIC_STATUS}), 200

# --- TRI-SENSOR CRASH DETECTION ---
@app.route('/api/crash_report', methods=['POST'])
def crash_report():
    """
    Receive tri-sensor crash data with forensic evidence
    Includes: Delta-V, Impact Vector, Acoustic Signature, Classification
    """
    data = request.json
    
    # Tri-sensor data
    delta_v = data.get('delta_v', 0.0)
    impact_vector = data.get('impact_vector', {})
    acoustic = data.get('acoustic_signature')
    classification = data.get('classification', 'unknown')
    
    # Location and motion data
    location = data.get('location', {})
    lat = location.get('lat', 0.0)
    lon = location.get('lon', 0.0)
    speed_before = data.get('speed_before', 0.0)
    heading_before = data.get('heading_before', 0.0)
    
    # Forensic data (first 50ms orientation lock)
    forensic_data = data.get('forensic_data', {})
    
    # Create forensic incident record
    crash_incident = {
        'id': random.randint(10000, 99999),
        'type': 'crash_forensic',
        'classification': classification,  # striker/victim/tbone/unknown
        'delta_v': delta_v,
        'impact_vector': impact_vector,
        'acoustic_signature': acoustic,
        'lat': lat,
        'lon': lon,
        'speed_before': speed_before,
        'heading_before': heading_before,
        'forensic_data': forensic_data,
        'timestamp': data.get('timestamp', 'Now'),
        'severity': 'CRITICAL' if abs(delta_v) > 10 else 'HIGH'
    }
    
    # Save to incidents
    incidents = load_incidents()
    incidents.append(crash_incident)
    save_incidents(incidents)
    
    # Log to console
    print(f"\n{'='*60}")
    print(f"🚨 CRASH DETECTED - FORENSIC REPORT 🚨")
    print(f"{'='*60}")
    print(f"Incident ID: {crash_incident['id']}")
    print(f"Classification: {classification.upper()}")
    print(f"Delta-V: {delta_v:.2f} m/s")
    print(f"Impact Vector: {impact_vector}")
    print(f"Location: {lat:.6f}, {lon:.6f}")
    print(f"Speed Before: {speed_before:.2f} m/s")
    print(f"Severity: {crash_incident['severity']}")
    
    if acoustic:
        print(f"\nAcoustic Signature:")
        print(f"  Metal Screech: {acoustic.get('metal_screech', False)}")
        print(f"  Glass Shatter: {acoustic.get('glass_shatter', False)}")
        print(f"  Structural Crunch: {acoustic.get('structural_crunch', False)}")
    
    print(f"{'='*60}\n")
    
    # If striker classification, could trigger insurance notification
    if classification == 'striker':
        print("⚠️  STRIKER CLASSIFICATION: Potential liability - Insurance notified")
    
    return jsonify({
        'status': 'crash_logged',
        'incident_id': crash_incident['id'],
        'classification': classification,
        'severity': crash_incident['severity']
    }), 200

# --- New TxDOT Camera API Endpoints ---

@app.route('/api/v1/txdot/cameras', methods=['GET'])
@require_txdot_key
def get_txdot_cameras_api():
    """Secured API for the App to get camera metadata."""
    path = 'backend/cameras_full.json' if os.path.exists('backend/cameras_full.json') else 'cameras_full.json'
    try:
        with open(path, 'r') as f:
            data = json.load(f)
            return jsonify(data), 200
    except Exception as e:
        return jsonify({"error": "Failed to load camera data", "details": str(e)}), 500

@app.route('/dashboard/cameras', methods=['GET'])
@require_txdot_key
def camera_dashboard():
    """Secured dashboard for viewing live camera feeds grouped by jurisdiction."""
    path = 'backend/cameras_full.json' if os.path.exists('backend/cameras_full.json') else 'cameras_full.json'
    try:
        with open(path, 'r') as f:
            cameras = json.load(f).get('cameras', [])
            
            # Group cameras by jurisdiction
            grouped_cameras = {}
            for cam in cameras:
                jurisdiction = cam.get('jurisdiction', 'Other/Statewide') or 'Other/Statewide'
                if jurisdiction not in grouped_cameras:
                    grouped_cameras[jurisdiction] = []
                grouped_cameras[jurisdiction].append(cam)
            
            # Sort jurisdictions alphabetically
            sorted_jurisdictions = sorted(grouped_cameras.keys())
            
            return render_template('cameras.html', 
                                 grouped_cameras=grouped_cameras, 
                                 jurisdictions=sorted_jurisdictions)
    except Exception as e:
        return f"<h1>Error loading dashboard</h1><p>{str(e)}</p>", 500



# --- TRAFFIC INTELLIGENCE SYSTEM ---
ROUTE_MANAGER = None
TRAFFIC_ANALYZER = None
STREAM_MANAGER = None

print("🚦 Initializing Traffic Intelligence System...")
try:
    ROUTE_MANAGER = RouteManager()
    # Inject mock cams if real ones lack coords (Same logic as simulation for reliability)
    valid_cams = [c for c in ROUTE_MANAGER.all_cameras if c.get('lat') is not None]
    if len(valid_cams) < 5:
        print("⚠️  Warning: Real camera data lacks coordinates. Injecting active I-35 mock cameras for backend.")
        ROUTE_MANAGER.all_cameras = [
            {'id': 'cam_sa_downtown', 'lat': 29.4250, 'lon': -98.4940, 'name': 'SA Downtown I-35', 'httpsurl': 'mock'},
            {'id': 'cam_nb_buccees', 'lat': 29.7040, 'lon': -98.1250, 'name': 'New Braunfels (Buc-ees)', 'httpsurl': 'mock'},
            {'id': 'cam_sm_outlet', 'lat': 29.8840, 'lon': -97.9420, 'name': 'San Marcos Outlets', 'httpsurl': 'mock'},
            {'id': 'cam_atx_capitol', 'lat': 30.2680, 'lon': -97.7440, 'name': 'Austin I-35 Upper Deck', 'httpsurl': 'mock'},
            {'id': 'cam_waco_silo', 'lat': 31.5500, 'lon': -97.1470, 'name': 'Waco Silos I-35', 'httpsurl': 'mock'},
            {'id': 'cam_dal_reunion', 'lat': 32.7770, 'lon': -96.7980, 'name': 'Dallas Mixmaster', 'httpsurl': 'mock'}
        ]
    TRAFFIC_ANALYZER = TrafficAnalyzer()
    STREAM_MANAGER = StreamManager([], TRAFFIC_ANALYZER)
except Exception as e:
    print(f"❌ Failed to initialize Traffic System: {e}")

@app.route('/api/set_route', methods=['POST'])
def api_set_route():
    """
    Sets the current route for monitoring.
    Expects JSON: { "route": [[lat, lon], [lat, lon], ...] }
    """
    try:
        if ROUTE_MANAGER is None:
            return jsonify({"error": "Traffic system not initialized"}), 503
        data = request.json
        route_coords = data.get('route')
        if not route_coords:
            return jsonify({"error": "No route provided"}), 400
        
        # Reset Route Manager
        active_cams = ROUTE_MANAGER.set_route(route_coords)
        return jsonify({
            "message": "Route set successfully",
            "cameras_in_corridor": len(active_cams),
            "camera_ids": [c['id'] for c in active_cams]
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/update_location', methods=['POST'])
def api_update_location():
    """
    Update user location and get status of active cameras.
    Expects JSON: { "lat": 30.1, "lon": -90.1 }
    """
    try:
        if ROUTE_MANAGER is None or STREAM_MANAGER is None:
            return jsonify({"error": "Traffic system not initialized"}), 503
        data = request.json
        lat = data.get('lat')
        lon = data.get('lon')
        
        if lat is None or lon is None:
            return jsonify({"error": "Missing lat/lon"}), 400
            
        lane_id = data.get('lane_id')
        lane_confidence = data.get('lane_confidence')

        # 1. Update Route Monitor -> Get next active cameras
        active_cams = ROUTE_MANAGER.update_user_location(lat, lon)
        
        # 2. Update Stream Manager (In a real app, this would start/stop inference threads)
        # For now we just sync the list
        active_ids = [c['id'] for c in active_cams]
        STREAM_MANAGER.update_streams(active_ids)
        
        # 3. Get Status/Incidents
        response_data = []
        for cam in active_cams:
            dist = ROUTE_MANAGER.get_incident_distance(cam['id'])
            
            # Use previously detected anomalies (or mock check)
            status = "CLEAR"
            if cam['id'] == 'cam_atx_capitol' and dist is not None and dist < 2.0:
                 status = "SLOW" # Mock incident
            
            response_data.append({
                "id": cam['id'],
                "name": cam['name'],
                "distance_miles": round(dist, 1) if dist else -1,
                "status": status,
                "stream_url": cam.get("httpsurl", "")
            })
            
        return jsonify({
            "active_cameras": response_data,
            "user_location": {"lat": lat, "lon": lon},
            "lane_context": {
                "lane_id": lane_id,
                "confidence": lane_confidence
            }
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/active_cameras', methods=['GET'])
def api_active_cameras():
    """Returns list of currently active cameras in the window"""
    try:
        if not ROUTE_MANAGER:
            return jsonify({"error": "Traffic system not initialized"}), 503
        return jsonify([c['id'] for c in ROUTE_MANAGER.active_inference_cameras])
    except: return jsonify([])


@app.route('/api/lane_geometry', methods=['POST'])
def api_lane_geometry():
    """
    Returns lane geometry for a given route corridor.
    Expects JSON: { "route": [[lat, lon], ...], "buffer_meters": 30 }
    """
    try:
        data = request.json or {}
        route_coords = data.get('route', [])
        buffer_meters = int(data.get('buffer_meters', 30))
        if not route_coords:
            return jsonify({"error": "No route provided"}), 400

        result = get_lane_geometry(route_coords, buffer_meters=buffer_meters)
        return jsonify(result), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/lane_match', methods=['POST'])
def api_lane_match():
    """
    Returns lane match for a given position.
    Expects JSON: { "lat": 30.1, "lon": -90.1, "heading": 123.0, "speed_mps": 10.0 }
    """
    try:
        data = request.json or {}
        lat = data.get('lat')
        lon = data.get('lon')
        heading = data.get('heading')
        speed_mps = data.get('speed_mps')

        if lat is None or lon is None:
            return jsonify({"error": "Missing lat/lon"}), 400

        match = match_lane(float(lat), float(lon), heading=heading, speed_mps=speed_mps)
        return jsonify(match), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/api/signals', methods=['GET'])
def api_signals():
    """
    Returns signal recommendations. If lane_id is provided, returns lane-context metadata.
    Query params: lat, lon, lane_id (optional)
    """
    try:
        lat = request.args.get('lat')
        lon = request.args.get('lon')
        lane_id = request.args.get('lane_id')
        if not lat or not lon:
            return jsonify({"error": "Missing lat/lon"}), 400

        # Mock signal response with lane context
        state = "GREEN"
        if lane_id and "left" in lane_id:
            state = "GREEN"
        elif lane_id and "right" in lane_id:
            state = "GREEN"

        return jsonify({
            "state": state,
            "recommended_speed": 35,
            "time_to_green": 12,
            "lane_context": {
                "lane_id": lane_id,
                "confidence": 0.6 if lane_id else 0.0,
                "source": "mock"
            }
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':

   from ai_monitor import monitor_cameras
   import threading
   
   # Start AI Monitor in Background
   monitor_thread = threading.Thread(target=monitor_cameras, daemon=True)
   # monitor_thread.start() # Disabled to stability testing

   
   print("Starting Cruze Backend (Flask Emulation) on port 7071...")
   # Run on port 7071 to match Flutter frontend defaults
   app.run(host='0.0.0.0', port=7071, debug=True)
