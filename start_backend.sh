#!/bin/bash
# start_backend.sh

# Navigate to the script's directory (project root)
cd "$(dirname "$0")"

echo "Starting Cruze Backend..."
echo "Ensure you have the virtual environment set up."

if [ -f "backend/flask_server.py" ]; then
    ./.venv/bin/python backend/flask_server.py
else
    echo "Error: backend/flask_server.py not found!"
    exit 1
fi
