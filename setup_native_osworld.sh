#!/bin/bash
# Proof of Concept: Run OSWorld natively on GCE VM (no Docker, no QEMU)
# This validates the cloud-first architecture approach

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# ============================================================================
# STEP 1: Install Desktop Environment Components
# ============================================================================

install_desktop_components() {
    log "Installing minimal desktop components..."

    export DEBIAN_FRONTEND=noninteractive

    # Update package lists
    apt-get update -qq

    # Install X11 and virtual display
    log "Installing X11 and Xvfb..."
    apt-get install -y -qq \
        xvfb \
        x11-xserver-utils \
        x11-utils \
        xfonts-base \
        xfonts-75dpi \
        xfonts-100dpi \
        dbus-x11 \
        > /dev/null

    # Install lightweight window manager
    log "Installing Openbox window manager..."
    apt-get install -y -qq \
        openbox \
        > /dev/null

    # Install VNC server (optional, for debugging)
    log "Installing x11vnc (optional, for debugging)..."
    apt-get install -y -qq \
        x11vnc \
        > /dev/null

    log "✓ Desktop components installed"
}

# ============================================================================
# STEP 2: Install Google Chrome
# ============================================================================

install_chrome() {
    log "Installing Google Chrome..."

    # Download Chrome
    if [ ! -f /tmp/google-chrome-stable_current_amd64.deb ]; then
        log "Downloading Chrome..."
        wget -q -O /tmp/google-chrome-stable_current_amd64.deb \
            https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    fi

    # Install Chrome and dependencies
    apt-get install -y -qq /tmp/google-chrome-stable_current_amd64.deb || true
    apt-get install -f -y -qq > /dev/null

    # Verify Chrome is installed
    if command -v google-chrome &> /dev/null; then
        log "✓ Chrome installed: $(google-chrome --version)"
    else
        error "Chrome installation failed"
    fi
}

# ============================================================================
# STEP 3: Install Additional Applications (for OSWorld tasks)
# ============================================================================

install_applications() {
    log "Installing additional applications..."

    # Firefox (backup browser)
    log "Installing Firefox..."
    apt-get install -y -qq firefox > /dev/null

    # LibreOffice (for document tasks)
    log "Installing LibreOffice..."
    apt-get install -y -qq \
        libreoffice \
        libreoffice-calc \
        libreoffice-writer \
        > /dev/null

    # GIMP (for image tasks)
    log "Installing GIMP..."
    apt-get install -y -qq gimp > /dev/null

    # Text editors
    log "Installing text editors..."
    apt-get install -y -qq \
        gedit \
        nano \
        vim \
        > /dev/null

    # File manager
    log "Installing file manager..."
    apt-get install -y -qq pcmanfm > /dev/null

    log "✓ Applications installed"
}

# ============================================================================
# STEP 4: Install Python and OSWorld Dependencies
# ============================================================================

install_python_deps() {
    log "Installing Python dependencies..."

    # Python 3.10+
    apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        python3-tk \
        python3-dev \
        python3-pyatspi \
        > /dev/null

    # Development libraries
    apt-get install -y -qq \
        tk-dev \
        at-spi2-core \
        > /dev/null

    # System dependencies for OSWorld
    apt-get install -y -qq \
        git \
        curl \
        wget \
        unzip \
        > /dev/null

    log "✓ Python dependencies installed"
}

# ============================================================================
# STEP 5: Set Up OSWorld Server
# ============================================================================

setup_osworld() {
    log "Setting up OSWorld server..."

    OSWORLD_DIR="/opt/osworld"
    OSWORLD_USER="osworld"

    # Create osworld user
    if ! id "$OSWORLD_USER" &>/dev/null; then
        log "Creating osworld user..."
        useradd -r -m -s /bin/bash -d "$OSWORLD_DIR" "$OSWORLD_USER"
    fi

    # Create directory structure
    mkdir -p "$OSWORLD_DIR"/{server,artifacts,logs}

    # Copy OSWorld server code from vendor directory
    if [ -d "/home/pablo/green-agent/vendor/OSWorld" ]; then
        log "Copying OSWorld code..."
        cp -r /home/pablo/green-agent/vendor/OSWorld/* "$OSWORLD_DIR/"
    else
        warn "OSWorld vendor directory not found, will need to install manually"
    fi

    # Install Python dependencies for OSWorld
    if [ -f "$OSWORLD_DIR/desktop_env/requirements.txt" ]; then
        log "Installing OSWorld Python dependencies..."
        python3 -m pip install -q -r "$OSWORLD_DIR/desktop_env/requirements.txt"
    fi

    # Set permissions
    chown -R "$OSWORLD_USER:$OSWORLD_USER" "$OSWORLD_DIR"

    log "✓ OSWorld setup complete"
}

# ============================================================================
# STEP 6: Create Systemd Services
# ============================================================================

create_systemd_services() {
    log "Creating systemd services..."

    # Service for Xvfb (virtual display)
    cat > /etc/systemd/system/xvfb.service <<'EOF'
[Unit]
Description=Virtual Framebuffer for OSWorld
After=network.target

[Service]
Type=simple
User=osworld
Environment=DISPLAY=:99
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Service for Openbox window manager
    cat > /etc/systemd/system/openbox.service <<'EOF'
[Unit]
Description=Openbox Window Manager for OSWorld
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=osworld
Environment=DISPLAY=:99
ExecStart=/usr/bin/openbox
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Service for OSWorld server
    cat > /etc/systemd/system/osworld-server.service <<'EOF'
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
ExecStart=/usr/bin/python3 -m desktop_env.server.main --port 5000
Restart=always
RestartSec=10
StandardOutput=append:/opt/osworld/logs/server.log
StandardError=append:/opt/osworld/logs/server-error.log

[Install]
WantedBy=multi-user.target
EOF

    # Optional: VNC service for debugging
    cat > /etc/systemd/system/x11vnc.service <<'EOF'
[Unit]
Description=x11vnc VNC Server for OSWorld (debugging)
After=xvfb.service
Requires=xvfb.service

[Service]
Type=simple
User=osworld
Environment=DISPLAY=:99
ExecStart=/usr/bin/x11vnc -display :99 -forever -shared -rfbport 5900 -nopw
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload

    log "✓ Systemd services created"
}

# ============================================================================
# STEP 7: Configure Environment
# ============================================================================

configure_environment() {
    log "Configuring environment..."

    # Add DISPLAY to osworld user profile
    cat >> /opt/osworld/.bashrc <<'EOF'

# OSWorld environment
export DISPLAY=:99
export OSWORLD_HOME=/opt/osworld
export PYTHONPATH=/opt/osworld
EOF

    # Create startup script for manual testing
    cat > /opt/osworld/start_manual.sh <<'EOF'
#!/bin/bash
# Manual startup script for testing

export DISPLAY=:99

echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!
sleep 2

echo "Starting Openbox..."
openbox &
sleep 1

echo "Starting OSWorld server..."
cd /opt/osworld
python3 -m desktop_env.server.main --port 5000 &
SERVER_PID=$!

echo ""
echo "✓ All services started"
echo "  Xvfb PID: $XVFB_PID"
echo "  Openbox PID: $(pgrep openbox)"
echo "  Server PID: $SERVER_PID"
echo ""
echo "Test with: curl http://localhost:5000/screenshot"
echo "Stop with: pkill -f 'Xvfb|openbox|desktop_env.server'"
EOF

    chmod +x /opt/osworld/start_manual.sh
    chown osworld:osworld /opt/osworld/start_manual.sh

    log "✓ Environment configured"
}

# ============================================================================
# STEP 8: Start Services
# ============================================================================

start_services() {
    log "Starting services..."

    # Enable services to start on boot
    systemctl enable xvfb.service
    systemctl enable openbox.service
    systemctl enable osworld-server.service
    # systemctl enable x11vnc.service  # Optional

    # Start services
    log "Starting Xvfb..."
    systemctl start xvfb.service
    sleep 2

    log "Starting Openbox..."
    systemctl start openbox.service
    sleep 1

    log "Starting OSWorld server..."
    systemctl start osworld-server.service
    sleep 3

    log "✓ Services started"
}

# ============================================================================
# STEP 9: Verify Installation
# ============================================================================

verify_installation() {
    log "Verifying installation..."

    # Check if Xvfb is running
    if pgrep -x Xvfb > /dev/null; then
        log "✓ Xvfb is running"
    else
        error "✗ Xvfb is not running"
    fi

    # Check if Openbox is running
    if pgrep -x openbox > /dev/null; then
        log "✓ Openbox is running"
    else
        warn "✗ Openbox is not running (may not be critical)"
    fi

    # Check if OSWorld server is running
    sleep 5  # Give server time to start

    if pgrep -f "desktop_env.server.main" > /dev/null; then
        log "✓ OSWorld server process is running"
    else
        error "✗ OSWorld server is not running"
    fi

    # Test screenshot endpoint
    log "Testing screenshot endpoint..."
    for i in {1..10}; do
        if curl -s -f http://localhost:5000/screenshot > /dev/null 2>&1; then
            log "✓ Screenshot endpoint is responding!"
            return 0
        fi
        log "Waiting for server to be ready... ($i/10)"
        sleep 3
    done

    warn "Screenshot endpoint is not responding yet"
    log "Check logs: journalctl -u osworld-server -n 50"
}

# ============================================================================
# STEP 10: Create Test Script
# ============================================================================

create_test_script() {
    log "Creating test script..."

    cat > /opt/osworld/test_native.sh <<'EOF'
#!/bin/bash
# Test script for native OSWorld installation

echo "========================================"
echo "Testing Native OSWorld Installation"
echo "========================================"
echo ""

# Check processes
echo "1. Checking processes..."
echo "   Xvfb: $(pgrep -x Xvfb > /dev/null && echo '✓ Running' || echo '✗ Not running')"
echo "   Openbox: $(pgrep -x openbox > /dev/null && echo '✓ Running' || echo '✗ Not running')"
echo "   OSWorld: $(pgrep -f 'desktop_env.server.main' > /dev/null && echo '✓ Running' || echo '✗ Not running')"
echo ""

# Check display
echo "2. Checking display..."
export DISPLAY=:99
if xdpyinfo > /dev/null 2>&1; then
    echo "   ✓ Display :99 is available"
    echo "   Resolution: $(xdpyinfo | grep dimensions | awk '{print $2}')"
else
    echo "   ✗ Display :99 is not available"
fi
echo ""

# Test Chrome
echo "3. Testing Chrome..."
if command -v google-chrome &> /dev/null; then
    echo "   ✓ Chrome is installed: $(google-chrome --version)"

    # Try to launch Chrome in background
    timeout 5 google-chrome --headless --disable-gpu --screenshot=/tmp/test_chrome.png https://www.google.com 2>/dev/null && \
        echo "   ✓ Chrome can take screenshots" || \
        echo "   ? Chrome screenshot test timed out (may be normal)"
else
    echo "   ✗ Chrome is not installed"
fi
echo ""

# Test OSWorld server
echo "4. Testing OSWorld server..."
if curl -s -f http://localhost:5000/health > /dev/null 2>&1; then
    echo "   ✓ Health endpoint: OK"
else
    echo "   ? Health endpoint: Not responding (may not exist)"
fi

if curl -s -f http://localhost:5000/screenshot > /dev/null 2>&1; then
    echo "   ✓ Screenshot endpoint: OK"

    # Save a test screenshot
    curl -s http://localhost:5000/screenshot -o /tmp/test_screenshot.png
    if [ -f /tmp/test_screenshot.png ]; then
        size=$(stat -f%z /tmp/test_screenshot.png 2>/dev/null || stat -c%s /tmp/test_screenshot.png)
        echo "   ✓ Screenshot saved: /tmp/test_screenshot.png (${size} bytes)"
    fi
else
    echo "   ✗ Screenshot endpoint: Not responding"
fi
echo ""

# System resources
echo "5. System resources..."
echo "   Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "   CPU cores: $(nproc)"
echo "   Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

echo "========================================"
echo "Test complete!"
echo "========================================"
echo ""
echo "Service logs:"
echo "  sudo journalctl -u xvfb -n 20"
echo "  sudo journalctl -u openbox -n 20"
echo "  sudo journalctl -u osworld-server -n 20"
echo ""
echo "Manual start:"
echo "  sudo -u osworld /opt/osworld/start_manual.sh"
EOF

    chmod +x /opt/osworld/test_native.sh
    chown osworld:osworld /opt/osworld/test_native.sh

    log "✓ Test script created: /opt/osworld/test_native.sh"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log "========================================"
    log "Native OSWorld Setup - Proof of Concept"
    log "========================================"
    log ""
    log "This will install:"
    log "  - Xvfb (virtual display)"
    log "  - Openbox (window manager)"
    log "  - Google Chrome"
    log "  - LibreOffice, GIMP, etc."
    log "  - OSWorld server (native)"
    log ""

    check_root

    # Installation steps
    install_desktop_components
    install_chrome
    install_applications
    install_python_deps
    setup_osworld
    create_systemd_services
    configure_environment
    start_services
    create_test_script
    verify_installation

    log ""
    log "========================================"
    log "Installation Complete!"
    log "========================================"
    log ""
    log "✓ OSWorld is running natively on this VM"
    log "✓ No Docker, no QEMU, no nested virtualization"
    log ""
    log "Test the installation:"
    log "  sudo /opt/osworld/test_native.sh"
    log ""
    log "View logs:"
    log "  sudo journalctl -u osworld-server -f"
    log ""
    log "Test screenshot endpoint:"
    log "  curl http://localhost:5000/screenshot -o test.png"
    log ""
    log "Service management:"
    log "  sudo systemctl status osworld-server"
    log "  sudo systemctl restart osworld-server"
    log ""
    log "Optional: Start VNC for visual debugging:"
    log "  sudo systemctl start x11vnc"
    log "  # Then connect to port 5900"
    log ""
}

main "$@"
