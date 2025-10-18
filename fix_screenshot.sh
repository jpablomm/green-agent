#!/bin/bash
# Fix screenshot functionality - install gnome-screenshot and upgrade Pillow
set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log "Fixing screenshot dependencies..."

# Install gnome-screenshot
log "Installing gnome-screenshot..."
sudo apt-get update -qq
sudo apt-get install -y gnome-screenshot

log "✓ gnome-screenshot installed"

# Check current Pillow version
PILLOW_VERSION=$(python3 -c "import PIL; print(PIL.__version__)" 2>/dev/null || echo "not installed")
log "Current Pillow version: $PILLOW_VERSION"

# Upgrade Pillow to latest version
log "Upgrading Pillow to latest version..."
sudo python3 -m pip install --upgrade Pillow

NEW_PILLOW_VERSION=$(python3 -c "import PIL; print(PIL.__version__)")
log "✓ Pillow upgraded to version: $NEW_PILLOW_VERSION"

# Restart the server
log "Restarting osworld-server..."
sudo systemctl restart osworld-server
sleep 5

# Verify it's running
if pgrep -f "desktop_env.server.main" > /dev/null; then
    log "✓ OSWorld server is running"
else
    error "✗ OSWorld server is not running"
    echo "Check logs: sudo journalctl -u osworld-server -n 30"
    exit 1
fi

# Test the screenshot endpoint
log "Testing screenshot endpoint..."
if curl -s -f http://localhost:5000/screenshot -o /tmp/test_screenshot.png 2>/dev/null; then
    if [ -s /tmp/test_screenshot.png ]; then
        SIZE=$(stat -c%s /tmp/test_screenshot.png 2>/dev/null || stat -f%z /tmp/test_screenshot.png 2>/dev/null)
        log "✓ Screenshot endpoint is working! (${SIZE} bytes)"
        ls -lh /tmp/test_screenshot.png
    else
        error "✗ Screenshot file is empty"
        exit 1
    fi
else
    error "✗ Screenshot endpoint still failing"
    echo "Check error logs: sudo cat /opt/osworld/logs/server-error.log | tail -20"
    exit 1
fi

echo ""
echo "=========================================="
echo "SUCCESS! Screenshots are working! 🎉"
echo "=========================================="
echo ""
echo "Test it yourself:"
echo "  curl http://localhost:5000/screenshot -o test.png"
echo ""
