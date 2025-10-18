#!/bin/bash
# Fix missing Python dependencies for native OSWorld

set -euo pipefail

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
    exit 1
}

log "Installing OSWorld Python dependencies..."

# Check if we're root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

# Install system dependencies for Python-Xlib
log "Installing system dependencies..."
apt-get install -y -qq \
    python3-xlib \
    libx11-dev \
    libxtst-dev \
    > /dev/null

# Install Python packages needed by OSWorld
log "Installing Python packages..."

# Core dependencies
pip3 install -q \
    python-xlib \
    flask \
    pillow \
    opencv-python-headless \
    requests \
    numpy \
    pyautogui \
    selenium \
    playwright

# Install playwright browsers
log "Installing Playwright browsers..."
playwright install chromium --with-deps > /dev/null 2>&1 || true

# If OSWorld has a requirements.txt, install it
if [ -f /opt/osworld/desktop_env/requirements.txt ]; then
    log "Installing from OSWorld requirements.txt..."
    pip3 install -q -r /opt/osworld/desktop_env/requirements.txt || true
fi

# Alternative: Check if vendor/OSWorld has requirements
if [ -f /home/pablo/green-agent/vendor/OSWorld/requirements.txt ]; then
    log "Installing from vendor requirements.txt..."
    pip3 install -q -r /home/pablo/green-agent/vendor/OSWorld/requirements.txt || true
fi

log "✓ Dependencies installed"

# Restart the service
log "Restarting osworld-server..."
systemctl restart osworld-server

# Wait for it to start
sleep 5

# Check status
if systemctl is-active --quiet osworld-server; then
    log "✓ osworld-server is running!"

    # Test the endpoint
    log "Testing screenshot endpoint..."
    for i in {1..10}; do
        if curl -s -f http://localhost:5000/screenshot > /dev/null 2>&1; then
            log "✓ Screenshot endpoint is responding!"
            log ""
            log "=========================================="
            log "SUCCESS! Native OSWorld is working!"
            log "=========================================="
            log ""
            log "Test it:"
            log "  curl http://localhost:5000/screenshot -o test.png"
            log "  sudo /opt/osworld/test_native.sh"
            exit 0
        fi
        log "Waiting for server... ($i/10)"
        sleep 2
    done

    log "Server is running but endpoint not responding yet"
    log "Check logs: sudo journalctl -u osworld-server -f"
else
    error "osworld-server failed to start. Check logs: sudo journalctl -u osworld-server -n 50"
fi
