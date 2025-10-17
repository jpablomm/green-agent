#!/bin/bash
# Test happysixd/osworld-docker with LEGACY BIOS mode instead of broken UEFI

echo "=================================="
echo "Testing happysixd with LEGACY BIOS mode"
echo "=================================="

# Stop existing container
docker stop osworld-test 2>/dev/null || true
docker rm osworld-test 2>/dev/null || true

# Path to Ubuntu QCOW2
VM_PATH="$HOME/green-agent/docker_vm_data/Ubuntu.qcow2"

if [ ! -f "$VM_PATH" ]; then
    echo "ERROR: Ubuntu.qcow2 not found at $VM_PATH"
    exit 1
fi

echo "Found VM image: $VM_PATH ($(du -h "$VM_PATH" | cut -f1))"

# Run with LEGACY BIOS mode (not UEFI)
echo "Starting container with BOOT_MODE=legacy..."
docker run -d \
  --name osworld-test \
  --device=/dev/kvm \
  --cap-add NET_ADMIN \
  -e BOOT_MODE=legacy \
  -e RAM_SIZE=4G \
  -e CPU_CORES=4 \
  -e DISK_SIZE=32G \
  -v "$VM_PATH:/System.qcow2" \
  -p 5000:5000 \
  -p 8006:8006 \
  -p 9222:9222 \
  -p 8080:8080 \
  happysixd/osworld-docker:latest

echo ""
echo "Container started! Monitoring boot with LEGACY BIOS..."
echo "This should bypass the UEFI bug and boot successfully!"
echo ""

# Follow logs for 2 minutes
timeout 120 docker logs -f osworld-test 2>&1 || true

echo ""
echo "=================================="
echo "Testing screenshot endpoint..."
echo "=================================="

# Test screenshot endpoint
for i in {1..5}; do
    echo "Attempt $i/5: Checking http://localhost:5000/screenshot"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/screenshot | grep -q "200"; then
        echo ""
        echo "✅ SUCCESS! Screenshot endpoint responding with LEGACY BIOS!"
        echo ""
        echo "The fix works! Update OSWorld provider to use BOOT_MODE=legacy"
        echo "Or we can build a fixed Docker image with proper UEFI support."
        exit 0
    fi
    echo "Not ready yet, waiting 30 seconds..."
    sleep 30
done

echo ""
echo "⚠️  Screenshot endpoint not responding yet."
echo ""
echo "Check container logs: docker logs osworld-test"
echo "Check VNC: http://$(curl -s ifconfig.me):8006"
echo "Stop container: docker stop osworld-test"
