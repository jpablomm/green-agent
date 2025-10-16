#!/usr/bin/env bash
set -euo pipefail
python white_agent/server.py --port 8090 &
WHITE_PID=$!
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080 --reload &
GREEN_PID=$!
echo "White Agent PID: $WHITE_PID"
echo "Green Agent PID: $GREEN_PID"
wait


