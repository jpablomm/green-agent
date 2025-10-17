#!/bin/bash
# Inspect happysixd/osworld-docker to understand how it starts QEMU

echo "=================================="
echo "Inspecting happysixd/osworld-docker image"
echo "=================================="

# Pull the image
echo "Pulling happysixd/osworld-docker..."
docker pull happysixd/osworld-docker

echo ""
echo "1. Inspecting image metadata..."
docker inspect happysixd/osworld-docker | head -100

echo ""
echo "2. Finding entrypoint/startup script..."
docker inspect happysixd/osworld-docker | grep -A 5 -i "entrypoint\|cmd"

echo ""
echo "3. Listing files in the image..."
docker run --rm --entrypoint ls happysixd/osworld-docker -la /

echo ""
echo "4. Looking for startup scripts..."
docker run --rm --entrypoint sh happysixd/osworld-docker -c "find / -maxdepth 3 -name '*start*' -o -name '*entrypoint*' -o -name '*run*' 2>/dev/null | head -20"

echo ""
echo "5. Checking for QEMU startup in common locations..."
docker run --rm --entrypoint sh happysixd/osworld-docker -c "cat /entrypoint.sh 2>/dev/null || cat /start.sh 2>/dev/null || cat /run.sh 2>/dev/null || cat /usr/local/bin/start 2>/dev/null || echo 'No startup script found in common locations'"

echo ""
echo "6. Checking OVMF firmware..."
docker run --rm --entrypoint sh happysixd/osworld-docker -c "find /usr -name '*OVMF*' 2>/dev/null | head -10"

echo ""
echo "=================================="
echo "Inspection complete!"
echo "=================================="
