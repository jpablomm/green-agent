# Alternative Docker Solution: Using `qemus/qemu` Instead of `happysixd/osworld-docker`

## Problem
The `happysixd/osworld-docker` image has UEFI boot issues causing the Ubuntu VM to hang at bootloader stage.

## Solution
Replace it with a proven, well-maintained QEMU Docker image: **`qemux/qemu`**

## Why This Works

The OSWorld Docker provider only cares about:
1. A running Docker container
2. That exposes port 5000 (screenshot service)
3. That can run QEMU/KVM with the Ubuntu.qcow2 image

**We don't need OSWorld's specific Docker image - we just need ANY Docker container that can run QEMU properly!**

## Implementation Plan

### Option 1: Modify OSWorld Provider (Easiest)

Edit `vendor/OSWorld/desktop_env/providers/docker/provider.py` line 117:

```python
# Change from:
self.container = self.client.containers.run(
    "happysixd/osworld-docker",
    ...
)

# To:
self.container = self.client.containers.run(
    "qemux/qemu",  # Well-maintained QEMU image
    environment={
        **self.environment,
        # Add QEMU-specific vars:
        "BOOT": "/System.qcow2",  # Path to qcow2
        "RAM_SIZE": self.environment.get("RAM_SIZE", "4G"),
        "CPU_CORES": self.environment.get("CPU_CORES", "4"),
        "DISK_SIZE": self.environment.get("DISK_SIZE", "32G"),
    },
    ...
)
```

### Option 2: Test Manually First (Recommended)

Before modifying OSWorld, test if `qemux/qemu` works:

```bash
# On GCP VM
docker run -d \
  --name osworld-test \
  --device=/dev/kvm \
  -e RAM_SIZE=4G \
  -e CPU_CORES=4 \
  -e BOOT=/vm/Ubuntu.qcow2 \
  -v ~/green-agent/docker_vm_data/Ubuntu.qcow2:/vm/Ubuntu.qcow2:ro \
  -p 5000:5000 \
  -p 8006:8006 \
  -p 9222:9222 \
  -p 8080:8080 \
  qemux/qemu

# Check if it boots
docker logs -f osworld-test

# Test screenshot endpoint
curl http://localhost:5000/screenshot
```

### Option 3: Build Custom Minimal Image (If needed)

If `qemux/qemu` needs tweaks, create a simple Dockerfile:

```dockerfile
FROM qemux/qemu:latest

# Install any additional tools if needed
RUN apt-get update && apt-get install -y \
    ovmf \
    && rm -rf /var/lib/apt/lists/*

# Copy custom QEMU startup script if needed
COPY start-vm.sh /start-vm.sh
RUN chmod +x /start-vm.sh

ENTRYPOINT ["/start-vm.sh"]
```

## Advantages

✅ **Well-maintained**: `qemux/qemu` is actively developed
✅ **UEFI support**: Built-in OVMF firmware
✅ **KVM optimized**: Designed for nested virtualization
✅ **Documentation**: Extensive examples and docs
✅ **Community**: Large user base = more support

## What Needs to Work

The Ubuntu.qcow2 VM must:
1. Boot successfully (UEFI should work with qemus/qemu)
2. Auto-start the Flask server on port 5000
3. The Flask server is in `/desktop_env/server/main.py` inside the VM

## Potential Issue: Flask Auto-Start

The Ubuntu.qcow2 needs to automatically start the Flask server when it boots. This might be configured via:
- systemd service
- /etc/rc.local
- Desktop autostart

**If the VM doesn't auto-start the server**, we can:
1. Mount a startup script into the VM
2. Or modify the QCOW2 to add a systemd service
3. Or use QEMU guest agent to start it after boot

## Next Steps

1. **Test `qemux/qemu` manually** (Option 2 above)
2. If it boots better than `happysixd/osworld-docker`, proceed with Option 1
3. Document findings and update OSWorld provider

## Alternative Images to Consider

If `qemux/qemu` doesn't work:
- `tianon/qemu` - Docker official library
- `docker/setup-qemu-action` - GitHub Actions QEMU
- Build custom from `ubuntu:22.04` + QEMU + OVMF

## References

- qemux/qemu: https://github.com/qemus/qemu
- OSWorld Docker provider: `vendor/OSWorld/desktop_env/providers/docker/provider.py`
- Ubuntu OVMF guide: https://wiki.ubuntu.com/UEFI/OVMF
