#!/bin/bash
# Extract the QEMU configuration scripts from happysixd/osworld-docker

echo "=================================="
echo "Extracting QEMU configuration scripts"
echo "=================================="

for script in reset.sh install.sh disk.sh display.sh network.sh boot.sh proc.sh config.sh; do
    echo ""
    echo "========== /run/$script =========="
    docker run --rm --entrypoint cat happysixd/osworld-docker /run/$script 2>/dev/null || echo "Could not read $script"
done

echo ""
echo "=================================="
echo "Complete! Now we know how happysixd configures QEMU"
echo "=================================="
