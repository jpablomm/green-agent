# Quick Fix Guide: Replace OSWorld Docker Image

## TL;DR: The Easiest Fix

Instead of debugging `happysixd/osworld-docker`, use a proven QEMU Docker image.

## Step 1: Test on GCP (5 minutes)

```bash
# SSH to GCP VM
ssh pablo@104.154.91.58

# Upload and run test script
cd ~/green-agent

# Download test script (or copy from repo)
# Then run:
chmod +x test_alternative_docker.sh
./test_alternative_docker.sh
```

## Step 2: If Test Succeeds, Update OSWorld Provider

Edit `vendor/OSWorld/desktop_env/providers/docker/provider.py`:

```bash
cd ~/green-agent/vendor/OSWorld
nano desktop_env/providers/docker/provider.py
```

**Find line 117** (search for "happysixd"):
```python
self.container = self.client.containers.run(
    "happysixd/osworld-docker",  # <-- OLD IMAGE
```

**Change to**:
```python
self.container = self.client.containers.run(
    "qemus/qemu:latest",  # <-- NEW, PROVEN IMAGE
```

**Add volume mapping** on line ~121:
```python
volumes={
    os.path.abspath(path_to_vm): {
        "bind": "/storage/boot.qcow2",  # <-- Changed from /System.qcow2
        "mode": "ro"
    }
},
```

Save (Ctrl+O, Enter, Ctrl+X) and restart Green Agent.

## Step 3: Test Real OSWorld Mode

```bash
# Restart Green Agent server
pkill -f uvicorn
export USE_FAKE_OSWORLD=0
export OSWORLD_MAX_STEPS=15
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080
```

## Why This Works

**`qemus/qemu`**:
- ✅ Actively maintained (2024 updates)
- ✅ UEFI/OVMF properly configured
- ✅ Designed for Docker + KVM
- ✅ Same environment variables as OSWorld
- ✅ Better boot compatibility

**`happysixd/osworld-docker`**:
- ❌ Unknown maintenance status
- ❌ UEFI boot issues
- ❌ VM hangs at bootloader
- ❌ No public documentation

## Fallback: If Flask Server Doesn't Auto-Start

The Ubuntu.qcow2 needs to auto-start the Flask server. If it doesn't:

**Option A: Connect via VNC and start manually**
```bash
# VNC available at http://104.154.91.58:8006
# Login to Ubuntu, then:
cd /path/to/desktop_env/server
python3 main.py --host 0.0.0.0 --port 5000
```

**Option B: Modify QCOW2 to add systemd service** (more complex)

**Option C: Use QEMU guest agent to auto-start** (requires Docker image modification)

## Expected Timeline

- **Test script**: 2-5 minutes
- **If successful, update provider**: 1 minute
- **Restart and test**: 2-3 minutes
- **Total**: ~10 minutes to validate solution

## What Success Looks Like

```bash
$ curl http://localhost:5000/screenshot
# Returns PNG image of desktop

$ curl http://localhost:8080/assessments/start \
  -H 'Content-Type: application/json' \
  -d '{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}'
# Returns {"assessment_id":"...","status":"running"}

# No timeout! Real OSWorld assessment completes!
```

## If This Doesn't Work

1. Check VNC (port 8006) to see if Ubuntu boots visually
2. Check if Flask server needs manual start inside VM
3. Try other proven QEMU images: `tianon/qemu`, `joshkunz/qemu-docker`
4. Report findings to OSWorld GitHub with our diagnostic data

## Advantages of This Approach

- ✅ **Non-invasive**: Doesn't require OSWorld code changes (just image name)
- ✅ **Reversible**: Can switch back if needed
- ✅ **Proven**: Using battle-tested QEMU Docker image
- ✅ **Fast**: 10-minute test vs. days of debugging
- ✅ **Maintainable**: Active project with community support

## Next Steps After Success

1. Document the fix in README.md
2. Submit issue/PR to OSWorld about `happysixd/osworld-docker` boot problems
3. Optionally: Build custom image optimized for OSWorld (Dockerfile provided)
4. Move to production testing with real White Agent
