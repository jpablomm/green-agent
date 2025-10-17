#!/bin/bash
# Build and test the fixed OSWorld Docker image

echo "=================================="
echo "Building Fixed OSWorld Docker Image"
echo "=================================="

# Build the fixed image
echo "Building osworld-fixed image..."
docker build -f Dockerfile.osworld-fixed -t osworld-fixed .

if [ $? -ne 0 ]; then
    echo "ERROR: Docker build failed!"
    exit 1
fi

echo ""
echo "✅ Image built successfully!"
echo ""
echo "=================================="
echo "Testing Fixed Image"
echo "=================================="

# Stop any existing test containers
docker stop osworld-test 2>/dev/null || true
docker rm osworld-test 2>/dev/null || true

VM_PATH="$HOME/green-agent/docker_vm_data/Ubuntu.qcow2"

if [ ! -f "$VM_PATH" ]; then
    echo "ERROR: Ubuntu.qcow2 not found at $VM_PATH"
    exit 1
fi

echo "Starting container with fixed UEFI support..."
docker run -d \
  --name osworld-test \
  --device=/dev/kvm \
  --cap-add NET_ADMIN \
  -e RAM_SIZE=4G \
  -e CPU_CORES=4 \
  -e DISK_SIZE=32G \
  -v "$VM_PATH:/System.qcow2" \
  -p 5000:5000 \
  -p 8006:8006 \
  -p 9222:9222 \
  -p 8080:8080 \
  osworld-fixed:latest

echo ""
echo "Container started! Monitoring boot..."
echo ""

# Follow logs for 2 minutes
timeout 120 docker logs -f osworld-test 2>&1 || true

echo ""
echo "=================================="
echo "Testing Screenshot Endpoint"
echo "=================================="

# Test screenshot endpoint
for i in {1..5}; do
    echo "Attempt $i/5: Checking http://localhost:5000/screenshot"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/screenshot | grep -q "200"; then
        echo ""
        echo "🎉 SUCCESS! The fixed image works!"
        echo ""
        echo "Screenshot endpoint is responding!"
        echo "VNC available at: http://$(curl -s ifconfig.me):8006"
        echo ""
        echo "Next steps:"
        echo "1. Update OSWorld provider.py to use 'osworld-fixed' image"
        echo "2. Test full Green Agent workflow"
        echo "3. Consider pushing image to Docker Hub for reuse"
        exit 0
    fi
    echo "Not ready yet, waiting 30 seconds..."
    sleep 30
done

echo ""
echo "⚠️  Screenshot endpoint not responding yet."
echo "Check logs: docker logs osworld-test"
echo "Check VNC: http://$(curl -s ifconfig.me):8006"
echo "Container still running for manual inspection."
