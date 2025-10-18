#!/bin/bash
# Fix X11 authentication issue for OSWorld
set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log "Fixing X11 authentication for OSWorld..."

# Step 1: Stop the crashing service
log "Stopping osworld-server..."
sudo systemctl stop osworld-server || true

# Step 2: Create .Xauthority file
log "Creating .Xauthority file..."
sudo touch /opt/osworld/.Xauthority
sudo chown osworld:osworld /opt/osworld/.Xauthority
sudo chmod 600 /opt/osworld/.Xauthority

# Step 3: Update Xvfb service to disable authentication
log "Updating Xvfb service to disable access control..."
sudo tee /etc/systemd/system/xvfb.service > /dev/null <<'EOF'
[Unit]
Description=X Virtual Frame Buffer
After=network.target

[Service]
Type=simple
User=osworld
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

log "✓ Xvfb service updated with -ac flag (disables access control)"

# Step 4: Update OSWorld server service with proper environment
log "Updating osworld-server service..."
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
Environment=PYTHONPATH=/opt/osworld
Environment=XAUTHORITY=/opt/osworld/.Xauthority
ExecStart=/usr/bin/python3 -m desktop_env.server.main --port 5000
Restart=always
RestartSec=10
StandardOutput=append:/opt/osworld/logs/server.log
StandardError=append:/opt/osworld/logs/server-error.log

[Install]
WantedBy=multi-user.target
EOF

log "✓ osworld-server service updated"

# Step 5: Reload systemd and restart services in order
log "Reloading systemd daemon..."
sudo systemctl daemon-reload

log "Restarting services in order..."
sudo systemctl restart xvfb
sleep 2

sudo systemctl restart openbox
sleep 2

sudo systemctl restart osworld-server
sleep 5

# Step 6: Verify everything is running
log "Verifying services..."

if pgrep -f "Xvfb :99" > /dev/null; then
    log "✓ Xvfb is running"
else
    error "✗ Xvfb is not running"
    sudo systemctl status xvfb
    exit 1
fi

if pgrep -f openbox > /dev/null; then
    log "✓ Openbox is running"
else
    error "✗ Openbox is not running"
    sudo systemctl status openbox
    exit 1
fi

if pgrep -f "desktop_env.server.main" > /dev/null; then
    log "✓ OSWorld server is running"
else
    error "✗ OSWorld server is not running"
    echo "Check logs with: sudo journalctl -u osworld-server -n 50"
    exit 1
fi

# Step 7: Test the screenshot endpoint
log "Testing screenshot endpoint..."
if curl -s http://localhost:5000/screenshot -o /tmp/test_screenshot.png; then
    if [ -s /tmp/test_screenshot.png ]; then
        SIZE=$(stat -c%s /tmp/test_screenshot.png 2>/dev/null || stat -f%z /tmp/test_screenshot.png 2>/dev/null)
        log "✓ Screenshot endpoint is working! ($(numfmt --to=iec-i --suffix=B $SIZE || echo "${SIZE} bytes"))"
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
