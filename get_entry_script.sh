#!/bin/bash
# Extract the entry.sh script from happysixd/osworld-docker

echo "=================================="
echo "Extracting /run/entry.sh from happysixd/osworld-docker"
echo "=================================="

# Method 1: Try to cat the file directly
echo "Method 1: Direct cat..."
docker run --rm --entrypoint cat happysixd/osworld-docker /run/entry.sh 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Method 1 failed. Trying Method 2..."

    # Method 2: Use sh to read it
    echo "Method 2: Using sh..."
    docker run --rm --entrypoint sh happysixd/osworld-docker -c "cat /run/entry.sh" 2>/dev/null
fi

if [ $? -ne 0 ]; then
    echo "Method 2 failed. Trying Method 3..."

    # Method 3: List /run directory first
    echo "Method 3: Listing /run directory..."
    docker run --rm --entrypoint sh happysixd/osworld-docker -c "ls -la /run"

    echo ""
    echo "Method 3b: Finding all .sh files in /run..."
    docker run --rm --entrypoint sh happysixd/osworld-docker -c "find /run -name '*.sh' 2>/dev/null"

    echo ""
    echo "Method 3c: Trying to read found scripts..."
    docker run --rm --entrypoint sh happysixd/osworld-docker -c "find /run -name '*.sh' -exec cat {} \; 2>/dev/null"
fi

echo ""
echo "=================================="
echo "Also checking /etc/runit for service scripts..."
echo "=================================="
docker run --rm --entrypoint sh happysixd/osworld-docker -c "find /etc/runit -type f 2>/dev/null | head -20"

echo ""
echo "Listing /etc/runit contents..."
docker run --rm --entrypoint sh happysixd/osworld-docker -c "ls -laR /etc/runit 2>/dev/null"
