#!/bin/bash
# Test Alternative Docker Image for OSWorld
# Run this on your GCP VM to test if qemus/qemu works better

set -e

echo "=================================="
echo "Testing qemus/qemu as OSWorld Docker alternative"
echo "=================================="

# Stop any existing OSWorld containers
echo "Cleaning up existing containers..."
docker stop osworld-test 2>/dev/null || true
docker rm osworld-test 2>/dev/null || true

# Pull the alternative image
echo "Pulling qemus/qemu image..."
docker pull qemus/qemu:latest

# Path to Ubuntu QCOW2
VM_PATH="$HOME/green-agent/docker_vm_data/Ubuntu.qcow2"

if [ ! -f "$VM_PATH" ]; then
    echo "ERROR: Ubuntu.qcow2 not found at $VM_PATH"
    exit 1
fi

echo "Found VM image: $VM_PATH ($(du -h "$VM_PATH" | cut -f1))"

# Run the container with same settings as OSWorld
echo "Starting QEMU container..."
docker run -d \
  --name osworld-test \
  --device=/dev/kvm \
  -e RAM_SIZE=4G \
  -e CPU_CORES=4 \
  -e DISK_SIZE=32G \
  -v "$VM_PATH:/storage/boot.qcow2:ro" \
  -p 5000:5000 \
  -p 8006:8006 \
  -p 9222:9222 \
  -p 8080:8080 \
  qemus/qemu:latest

echo ""
echo "Container started! Container ID: $(docker ps -q -f name=osworld-test)"
echo ""
echo "Monitoring boot process (press Ctrl+C to stop watching logs)..."
echo "Look for:"
echo "  - QEMU startup messages"
echo "  - Ubuntu boot messages"
echo "  - Flask server startup on port 5000"
echo ""
echo "=================================="
echo ""

# Follow logs for 2 minutes then check status
timeout 120 docker logs -f osworld-test 2>&1 || true

echo ""
echo "=================================="
echo "Testing screenshot endpoint..."
echo "=================================="

# Test screenshot endpoint
for i in {1..5}; do
    echo "Attempt $i/5: Checking http://localhost:5000/screenshot"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/screenshot | grep -q "200"; then
        echo "✅ SUCCESS! Screenshot endpoint is responding!"
        echo ""
        echo "This alternative Docker image WORKS!"
        echo "You can now modify OSWorld provider.py to use 'qemus/qemu' instead of 'happysixd/osworld-docker'"
        exit 0
    fi
    echo "Not ready yet, waiting 30 seconds..."
    sleep 30
done

echo ""
echo "⚠️  Screenshot endpoint not responding yet."
echo "This could mean:"
echo "  1. VM is still booting (wait longer)"
echo "  2. Flask server inside VM needs manual start"
echo "  3. Port mapping issue"
echo ""
echo "Check container logs with: docker logs osworld-test"
echo "Check VNC on port 8006: http://$(curl -s ifconfig.me):8006"
echo "Stop container with: docker stop osworld-test"
echo ""
echo "Container is still running. Check it manually."
