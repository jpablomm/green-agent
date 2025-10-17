# Final Solution: The Ubuntu.qcow2 Requires UEFI Boot

## Root Cause Analysis

After extensive investigation, here's what we found:

### The Problem Chain:
1. ✅ Ubuntu.qcow2 downloads successfully (23GB)
2. ✅ KVM acceleration works
3. ❌ **UEFI mode has a bug** in `happysixd/osworld-docker` (`boot.sh` lines 33-36)
4. ❌ **Legacy BIOS mode fails** because Ubuntu.qcow2 has **no MBR bootloader**
5. ❌ Ubuntu.qcow2 is **UEFI-only** (GPT partition table, EFI boot partition)

### The UEFI Bug:
```bash
# In /run/boot.sh:
ROM="edk2-x86_64-code.fd"
VARS="edk2-x86_64-code.fd"    # BUG: Same file for both!

BOOT_OPTS+=" -pflash $DEST.rom"  # Only adds ROM, missing VARS!
```

Proper UEFI requires **TWO** pflash devices:
- `-pflash CODE.fd` (read-only firmware)
- `-pflash VARS.fd` (read-write NVRAM for boot config)

Without VARS, UEFI firmware can't persist boot settings → hangs!

## Solutions (In Order of Preference)

### ✅ Solution 1: Patch OSWorld Provider (RECOMMENDED)

Modify OSWorld to add the missing UEFI VARS pflash:

```python
# In vendor/OSWorld/desktop_env/providers/docker/provider.py

self.environment = {
    "DISK_SIZE": "32G",
    "RAM_SIZE": "4G",
    "CPU_CORES": "4",
    # Add proper UEFI configuration
    "BOOT_MODE": "uefi"  # Ensure UEFI mode
}

# After container starts, exec a command to fix UEFI:
self.container.exec_run(
    "sh -c 'sed -i \"s/BOOT_OPTS+=\\\" -pflash/BOOT_OPTS+=\\\" -drive if=pflash,format=raw,readonly=on,file=/g\" /run/boot.sh'"
)
```

**Better**: Create a fixed Docker image.

### ✅ Solution 2: Build Fixed Docker Image (BEST)

Create our own Docker image with the UEFI bug fixed:

**Dockerfile:**
```dockerfile
FROM happysixd/osworld-docker:latest

# Fix the UEFI boot bug
RUN sed -i 's/VARS="edk2-x86_64-code.fd"/VARS="OVMF_VARS_4M.fd"/' /run/boot.sh && \
    sed -i '/BOOT_OPTS+=" -pflash \$DEST.rom"/a\    BOOT_OPTS+=" -drive if=pflash,format=raw,file=\$DEST.vars"' /run/boot.sh

# Verify the fix
RUN grep -A 2 "BOOT_OPTS" /run/boot.sh
```

Then:
```bash
docker build -t osworld-fixed .
docker push <your-registry>/osworld-fixed

# Update provider.py:
self.client.containers.run("osworld-fixed", ...)
```

### ✅ Solution 3: Use VMware Provider

Switch to VMware provider which OSWorld officially supports and is more stable:

```python
# In osworld_adapter.py
env = DesktopEnv(
    provider_name="vmware",  # Instead of "docker"
    path_to_vm="/path/to/vm.vmx",
    # ...
)
```

Requires VMware Workstation/Fusion installation.

### ❌ Solution 4: Try to Make Legacy BIOS Work

**Not recommended** - Would require:
1. Installing GRUB in MBR mode inside the qcow2
2. Reconfiguring the Ubuntu installation
3. This defeats the purpose of using the pre-built OSWorld image

## Recommended Next Steps

### Immediate (Test Tonight):

**Option A: Quick Fix - Manually Patch Container**
```bash
# Start container
docker run -d --name osworld-test \
  --device=/dev/kvm --cap-add NET_ADMIN \
  -e RAM_SIZE=4G -e CPU_CORES=4 -e DISK_SIZE=32G \
  -v ~/green-agent/docker_vm_data/Ubuntu.qcow2:/System.qcow2 \
  -p 5000:5000 -p 8006:8006 \
  happysixd/osworld-docker:latest

# Fix UEFI bug before it starts QEMU
docker exec osworld-test sh -c 'pkill -f qemu; sleep 1'
docker exec osworld-test sh -c 'sed -i "s/VARS=\"edk2-x86_64-code.fd\"/VARS=\"OVMF_VARS_4M.fd\"/" /run/boot.sh'
docker exec osworld-test sh -c '/run/entry.sh &'
```

**Option B: Build Fixed Image (15 minutes)**
1. Create Dockerfile above
2. Build: `docker build -t osworld-fixed .`
3. Test: Run with `osworld-fixed` instead of `happysixd/osworld-docker`
4. Update OSWorld provider.py to use fixed image

### Short-term (This Week):

1. If fix works, build and push fixed Docker image
2. Update `vendor/OSWorld/desktop_env/providers/docker/provider.py`
3. Test end-to-end real OSWorld mode
4. Document the fix and submit PR to OSWorld repo

### Long-term (Future):

1. Report bug to OSWorld maintainers
2. Consider VMware provider for production
3. Contribute fix back to OSWorld project

## Why This Took So Long

1. **UEFI bug is subtle**: The code LOOKS correct but uses wrong files
2. **No error messages**: QEMU just hangs, no helpful logs
3. **Legacy mode seemed promising**: Got past UEFI but hit different issue
4. **VNC not accessible**: Couldn't see actual boot screen

## Lessons Learned

1. ✅ Always check VNC/console output first
2. ✅ Inspect Docker images thoroughly (which we did!)
3. ✅ Test both UEFI and Legacy modes
4. ✅ Verify images are actually bootable
5. ✅ Don't assume third-party Docker images are bug-free

## Files Created During Investigation

- `inspect_happysixd.sh` - Extract Docker image scripts ✅
- `get_entry_script.sh` - Get startup script ✅
- `get_qemu_scripts.sh` - Get all QEMU config scripts ✅
- `test_legacy_boot.sh` - Test Legacy BIOS mode ✅
- `inspect_ubuntu_image.sh` - Mount and inspect qcow2 ✅
- `ALTERNATIVE_DOCKER_SOLUTION.md` - Alternative approaches ✅
- `QUICK_FIX_GUIDE.md` - Step-by-step guide ✅

All investigation work is documented and reusable! 🎉
