#!/bin/bash
# Fix missing tkinter dependency for OSWorld
set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

log "Installing missing system dependencies for OSWorld..."

# Stop the crashing service
log "Stopping osworld-server..."
sudo systemctl stop osworld-server || true

# Install tkinter and other missing system packages
log "Installing tkinter, pyatspi, and development packages..."
sudo apt-get update
sudo apt-get install -y \
    python3-tk \
    python3-dev \
    tk-dev \
    python3-pyatspi \
    at-spi2-core

log "✓ System packages installed"

# Restart the service
log "Restarting osworld-server..."
sudo systemctl restart osworld-server
sleep 5

# Verify it's running
log "Verifying services..."

if pgrep -f "desktop_env.server.main" > /dev/null; then
    log "✓ OSWorld server is running"
else
    error "✗ OSWorld server is not running"
    echo ""
    echo "Checking error logs..."
    sudo journalctl -u osworld-server -n 30 --no-pager
    echo ""
    echo "Try running manually to see the error:"
    echo "  sudo -u osworld bash -c 'cd /opt/osworld && export DISPLAY=:99 && export PYTHONPATH=/opt/osworld && python3 -m desktop_env.server.main --port 5000'"
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
