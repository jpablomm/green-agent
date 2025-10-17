#!/bin/bash
# Inspect the Ubuntu.qcow2 image to verify it's bootable

echo "=================================="
echo "Inspecting Ubuntu.qcow2 image"
echo "=================================="

VM_PATH="$HOME/green-agent/docker_vm_data/Ubuntu.qcow2"

if [ ! -f "$VM_PATH" ]; then
    echo "ERROR: Ubuntu.qcow2 not found at $VM_PATH"
    exit 1
fi

echo ""
echo "1. Image info:"
qemu-img info "$VM_PATH"

echo ""
echo "2. Checking if image is valid:"
qemu-img check "$VM_PATH" || echo "Image check failed!"

echo ""
echo "3. Attempting to mount and inspect (requires sudo):"
echo "Creating NBD device..."

# Load nbd module if not loaded
sudo modprobe nbd max_part=8 2>/dev/null || true

# Connect to NBD
sudo qemu-nbd --connect=/dev/nbd0 "$VM_PATH" 2>/dev/null || echo "NBD connection failed (may already be connected)"

sleep 2

echo ""
echo "4. Listing partitions:"
sudo fdisk -l /dev/nbd0 2>/dev/null || echo "Cannot read partitions"

echo ""
echo "5. Trying to mount first partition:"
sudo mkdir -p /mnt/ubuntu-test 2>/dev/null || true

if sudo mount /dev/nbd0p1 /mnt/ubuntu-test 2>/dev/null; then
    echo "✅ Mounted! Checking contents..."
    echo ""
    echo "Root directory:"
    sudo ls -la /mnt/ubuntu-test/
    echo ""
    echo "Checking for boot files:"
    sudo ls -la /mnt/ubuntu-test/boot/ 2>/dev/null || echo "No /boot directory"
    echo ""
    echo "Checking for GRUB:"
    sudo ls -la /mnt/ubuntu-test/boot/grub/ 2>/dev/null || echo "No GRUB"
    echo ""
    echo "Checking for desktop_env server:"
    sudo find /mnt/ubuntu-test -name "main.py" -path "*/desktop_env/server/*" 2>/dev/null || echo "desktop_env server not found"

    sudo umount /mnt/ubuntu-test
    echo "Unmounted."
else
    echo "Cannot mount first partition, trying second..."
    if sudo mount /dev/nbd0p2 /mnt/ubuntu-test 2>/dev/null; then
        echo "✅ Mounted partition 2! Checking contents..."
        sudo ls -la /mnt/ubuntu-test/ | head -20
        sudo umount /mnt/ubuntu-test
    else
        echo "Cannot mount any partition"
    fi
fi

echo ""
echo "6. Disconnecting NBD:"
sudo qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true

echo ""
echo "=================================="
echo "Inspection complete!"
echo "=================================="
