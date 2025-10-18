#!/bin/bash
# Fix pyxcursor import path issue
set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log "Fixing pyxcursor import path..."

# Stop the service
log "Stopping osworld-server..."
sudo systemctl stop osworld-server || true

# The issue is that pyxcursor.py is in desktop_env/server/ but the import is "from pyxcursor import Xcursor"
# We need to add the server directory to PYTHONPATH

log "Updating osworld-server service with correct PYTHONPATH..."
sudo tee /etc/systemd/system/osworld-server.service > /dev/null <<'EOF'
[Unit]
Description=OSWorld Desktop Environment Server
After=openbox.service
Requires=openbox.service

[Service]
Type=simple
User=osworld
WorkingDirectory=/opt/osworld
Environment=DISPLAY=:99
Environment=PYTHONPATH=/opt/osworld:/opt/osworld/desktop_env/server
Environment=XAUTHORITY=/opt/osworld/.Xauthority
ExecStart=/usr/bin/python3 -m desktop_env.server.main --port 5000
Restart=always
RestartSec=10
StandardOutput=append:/opt/osworld/logs/server.log
StandardError=append:/opt/osworld/logs/server-error.log

[Install]
WantedBy=multi-user.target
EOF

log "✓ Service updated with correct PYTHONPATH"

# Reload and restart
log "Reloading systemd and restarting service..."
sudo systemctl daemon-reload
sudo systemctl restart osworld-server
sleep 5

# Verify it's running
log "Verifying service..."

if pgrep -f "desktop_env.server.main" > /dev/null; then
    log "✓ OSWorld server is running"
else
    error "✗ OSWorld server is not running"
    echo ""
    echo "Checking error logs..."
    sudo journalctl -u osworld-server -n 30 --no-pager
    echo ""
    echo "Try running manually:"
    echo "  sudo -u osworld bash -c 'cd /opt/osworld && export DISPLAY=:99 && export PYTHONPATH=/opt/osworld:/opt/osworld/desktop_env/server && python3 -m desktop_env.server.main --port 5000'"
    exit 1
fi

# Test the screenshot endpoint
log "Testing screenshot endpoint..."
if curl -s http://localhost:5000/screenshot -o /tmp/test_screenshot.png; then
    if [ -s /tmp/test_screenshot.png ]; then
        SIZE=$(stat -c%s /tmp/test_screenshot.png 2>/dev/null || stat -f%z /tmp/test_screenshot.png 2>/dev/null)
        log "✓ Screenshot endpoint is working! (${SIZE} bytes)"
        ls -lh /tmp/test_screenshot.png
    else
        error "✗ Screenshot file is empty"
        exit 1
    fi
else
    error "✗ Screenshot endpoint failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "SUCCESS! Native OSWorld is working! 🎉"
echo "=========================================="
echo ""
echo "Test it yourself:"
echo "  curl http://localhost:5000/screenshot -o test.png"
echo "  sudo /opt/osworld/test_native.sh"
echo ""
echo "View logs:"
echo "  sudo journalctl -u osworld-server -f"
echo ""
