
import os
from flask import request, jsonify, render_template
from functools import wraps

TXDOT_API_KEY = os.environ.get("TXDOT_API_KEY", "01189de9-8faa-46ed-b066-db7252ed8cbc")

def require_txdot_key(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Check header
        api_key = request.headers.get("X-API-KEY")
        
        # Also check query param (useful for browser/dashboard access)
        if not api_key:
            api_key = request.args.get("key")
            
        if api_key != TXDOT_API_KEY:
            # If it's the dashboard (HTML), we might want a simple error page
            if "/dashboard/" in request.path:
                return "<h1>401 Unauthorized</h1><p>Valid TxDOT API Key required to view this private dashboard.</p>", 401
            return jsonify({"error": "Unauthorized", "message": "Valid API key required in X-API-KEY header"}), 401
            
        return f(*args, **kwargs)
    return decorated_function
