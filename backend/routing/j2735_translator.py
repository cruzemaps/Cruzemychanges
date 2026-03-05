import json
import time
import requests

# BSM Part II Extension for Vehicle Matrix (Custom Extension)
# Standard J2735 BSM primarily describes the ego vehicle.
# Cruze extends this to send the calculated Lead Vehicle metrics.

def generate_bsm(ego_id, lat, lon, heading, speed_mps, lead_speed_mps, gap_meters):
    """
    Generates a SAE J2735 compliant Basic Safety Message (BSM) payload.
    Cruze acts as the translator between raw CV/Telemetry and the DOT's ATMS format.
    """
    # J2735 formats typically use specific integer scaling (e.g. speed in 0.02 m/s units)
    # For this implementation we'll keep the numbers readable but structure them 
    # as a standard BSM JSON.
    
    bsm = {
        "messageId": 20, # MsgID for BSM
        "coreData": {
            "msgCnt": int(time.time() % 127),
            "id": ego_id,
            "secMark": int((time.time() % 60) * 1000), 
            "lat": int(lat * 10000000),
            "long": int(lon * 10000000),
            "elev": 0,
            "accuracy": {
                "semiMajor": 255,
                "semiMinor": 255,
                "orientation": 65535
            },
            "transmission": "FORWARDGEARS",
            "speed": int(speed_mps / 0.02), # standard 0.02 m/s precision
            "heading": int(heading / 0.0125), # standard 0.0125 degree precision
            "angle": 127,
            "accelSet": {
                "long": 0,
                "lat": 0,
                "vert": 0,
                "yaw": 0
            },
            "brakes": {
                "wheelBrakes": "0000",
                "traction": "unavailable",
                "abs": "unavailable",
                "scs": "unavailable",
                "brakeBoost": "unavailable",
                "auxBrakes": "unavailable"
            },
            "size": {
                "width": 260,
                "length": 2200
            }
        },
        # -- Cruze Specific Value-Add (Part II Extension) --
        "partII": [
            {
                "partII-Id": 2, # Supplementary Vehicle Extensions
                "partII-Value": {
                    "cruzeLeadMatrix": {
                        "leadSpeed": lead_speed_mps,
                        "gapMeters": gap_meters
                    }
                }
            }
        ]
    }
    return bsm

def process_phantom_jam_logic(bsm_payload):
    """
    Mock implementation of a DOT iNET/ATMS Phantom Jam algorithm.
    Reads the incoming BSM, identifies if the lead gap is compressing 
    while the lead speed is dropping, and issues a TIM if necessary.
    """
    core = bsm_payload["coreData"]
    partII = bsm_payload.get("partII", [])[0]["partII-Value"]["cruzeLeadMatrix"]
    
    v_ego = core["speed"] * 0.02 # Convert back to m/s
    v_lead = partII["leadSpeed"]
    gap = partII["gapMeters"]
    
    # Simple phantom jam heuristic:
    # If gap is tight (< 30m), speed is high (> 20m/s), and lead is slowing significantly
    if gap > 0 and gap < 30.0 and v_ego > 20.0 and v_lead < (v_ego - 5.0):
        # Determine advisory speed to absorb the shockwave
        advisory_speed_mph = 55 
        return {
            "messageId": 31, # Traveler Information Message
            "timId": f"jam_wave_{core['secMark']}",
            "msg": f"UDOT Advisory: Maintain {advisory_speed_mph} mph to clear traffic wave."
        }
    return None

def send_tim_alert_to_app(ego_id, tim_msg):
    """
    Routes the TIM back to the Cruze mobile app via Firebase FCM or MQTT.
    """
    print(f"📡 [C2C Mock] Sending TIM to {ego_id}: {tim_msg['msg']}")
    
    # In a real app we'd dispatch to FCM or publish a downlink MQTT message
    # Here we can just append it to a global log that the Flutter app polls
    try:
         requests.post("http://localhost:7071/api/internal/tim_dispatch", 
                      json={"target_id": ego_id, "tim": tim_msg}, 
                      timeout=2)
    except:
        pass
