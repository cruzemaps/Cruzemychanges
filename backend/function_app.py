import azure.functions as func
import logging
import json
import random
import os

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

# Simple File-Based DB for Hackathon Demo (Persists locally)
DB_FILE = "users.json"

def load_users():
    if not os.path.exists(DB_FILE):
        return {}
    try:
        with open(DB_FILE, 'r') as f:
            return json.load(f)
    except:
        return {}

def save_users(users):
    with open(DB_FILE, 'w') as f:
        json.dump(users, f)

# Mock Data for High Risk Intersections (San Antonio)
HIGH_RISK_INTERSECTIONS = [
    {"lat": 29.4241, "lon": -98.4936, "name": "Alamo Plaza"},
    {"lat": 29.4260, "lon": -98.4861, "name": "E Houston St & N Alamo St"},
    {"lat": 29.4100, "lon": -98.5000, "name": "S Flores St & W Cesar E Chavez Blvd"},
    {"lat": 29.4300, "lon": -98.4800, "name": "Broadway & E Jones Ave"},
    {"lat": 29.4150, "lon": -98.4700, "name": "S Hackberry St & E Cesar E Chavez Blvd"}
]

@app.route(route="telemetry", methods=["POST"])
def telemetry(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Processing telemetry data.')

    try:
        req_body = req.get_json()
        lat = req_body.get('lat')
        long = req_body.get('long')
        crash_detected = req_body.get('crash_detected')
        g_force = req_body.get('g_force')

        if crash_detected:
            logging.warning(f"CRASH DETECTED at {lat}, {long} with G-Force {g_force}")
            # In a real app, this would write to Cosmos DB
            # container.create_item(body=req_body)

        return func.HttpResponse(
            json.dumps({"status": "success", "message": "Telemetry received"}),
            mimetype="application/json",
            status_code=200
        )
    except ValueError:
        return func.HttpResponse(
            "Invalid JSON",
            status_code=400
        )

@app.route(route="route", methods=["GET"])
def get_route(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Calculating safe route.')

    start_lat = req.params.get('start_lat')
    start_lon = req.params.get('start_lon')
    end_lat = req.params.get('end_lat')
    end_lon = req.params.get('end_lon')

    if not all([start_lat, start_lon, end_lat, end_lon]):
        return func.HttpResponse(
            "Missing coordinates",
            status_code=400
        )

    # Simulate calling Azure Maps Route API with avoid polygons
    # In reality, this would construct a request to:
    # https://atlas.microsoft.com/route/directions/json?api-version=1.0&query={start}:{end}&avoid[areas]=...

    logging.info("Avoiding High Risk Intersections:")
    for intersection in HIGH_RISK_INTERSECTIONS:
        logging.info(f" - {intersection['name']} ({intersection['lat']}, {intersection['lon']})")

    # Mock response returning a simple line for demo purposes
    # Just returning the start and end points as a straight line
    route_points = [
        [float(start_lat), float(start_lon)],
        [29.4200, -98.4900], # Waypoint midway
        [float(end_lat), float(end_lon)]
    ]

    return func.HttpResponse(
        json.dumps({
            "route": route_points,
            "risk_analysis": "Safe route calculated avoiding 5 high-risk zones."
        }),
        mimetype="application/json",
        status_code=200
    )

@app.route(route="ai_summary", methods=["POST"])
def ai_summary(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Generating AI Summary.')
    
    # Mock OpenAI Integration
    # In reality: client = AzureOpenAI(...) -> response = client.chat.completions.create(...)
    
    return func.HttpResponse(
        json.dumps({
            "summary": "Driver risk is elevated due to hard braking events detected near Alamo Plaza.",
            "recommendation": "Suggest enabling collision avoidance mode."
        }),
        mimetype="application/json",
        status_code=200
    )
