# Creating the OSWorld Golden Image

This guide walks through creating a golden GCE image from the working `green-agent-vm`.

---

## Step 1: Prepare the VM for Imaging

**Run this ON THE VM** (via SSH):

```bash
cd ~/green-agent
git pull origin main
bash prepare_for_imaging.sh
```

This will:
- ✅ Clean temporary files
- ✅ Clean package cache
- ✅ Clean logs
- ✅ Verify services are running
- ✅ Test OSWorld API

**Expected output:**
```
==========================================
VM is ready for imaging!
==========================================
```

---

## Step 2: Create the Golden Image

**Run this ON YOUR LOCAL MACHINE** (not on the VM):

```bash
# Create the golden image
gcloud compute images create osworld-golden-v1 \
  --source-disk=green-agent-vm \
  --source-disk-zone=us-central1-a \
  --family=osworld \
  --description="Native OSWorld - Chrome 141, Ubuntu 22.04, fully tested" \
  --labels=version=v1,type=osworld,status=production
```

**This will take 5-10 minutes.**

**Expected output:**
```
Created [https://www.googleapis.com/compute/v1/projects/YOUR-PROJECT/global/images/osworld-golden-v1].
NAME                PROJECT       FAMILY   DEPRECATED  STATUS
osworld-golden-v1   YOUR-PROJECT  osworld              READY
```

---

## Step 3: Verify the Image

```bash
# Check image details
gcloud compute images describe osworld-golden-v1

# Should show:
# - creationTimestamp
# - diskSizeGb: 50
# - family: osworld
# - status: READY
```

---

## Step 4: Test the Golden Image

Create a new VM from the golden image:

```bash
# Create test VM
gcloud compute instances create osworld-test-2 \
  --image=osworld-golden-v1 \
  --machine-type=n1-standard-4 \
  --zone=us-central1-a \
  --boot-disk-size=50GB \
  --tags=osworld-vm

# Wait 30-60 seconds for it to boot
echo "Waiting for VM to boot..."
sleep 45
```

---

## Step 5: Verify the New VM Works

Test the new VM:

```bash
# Test 1: Platform endpoint
gcloud compute ssh osworld-test-2 --zone=us-central1-a \
  --command="curl -s http://localhost:5000/platform"
# Expected: Linux

# Test 2: Screenshot
gcloud compute ssh osworld-test-2 --zone=us-central1-a \
  --command="curl -s http://localhost:5000/screenshot -o /tmp/test.png && ls -lh /tmp/test.png"
# Expected: 6.1K /tmp/test.png

# Test 3: Chrome launch
gcloud compute ssh osworld-test-2 --zone=us-central1-a \
  --command='curl -s -X POST http://localhost:5000/execute -H "Content-Type: application/json" -d "{\"command\": [\"google-chrome\", \"--version\"]}" | grep -o "Google Chrome [0-9.]*"'
# Expected: Google Chrome 141.0.7390.107

# Test 4: Full test suite
gcloud compute ssh osworld-test-2 --zone=us-central1-a \
  --command="cd ~/green-agent && bash test_osworld_simple.sh"
# Expected: All tests passing
```

**If all tests pass:** 🎉 **Golden image is working perfectly!**

---

## Step 6: Clean Up Test VM

After verifying it works, delete the test VM:

```bash
gcloud compute instances delete osworld-test-2 --zone=us-central1-a --quiet
```

---

## Using the Golden Image

### Create a New VM

```bash
gcloud compute instances create my-osworld-vm \
  --image=osworld-golden-v1 \
  --machine-type=n1-standard-4 \
  --zone=us-central1-a
```

**Boot time:** ~30 seconds (vs 20 minutes with setup script!)

### Create Multiple VMs

```bash
# Create 5 VMs in parallel
for i in {1..5}; do
  gcloud compute instances create osworld-vm-$i \
    --image=osworld-golden-v1 \
    --machine-type=n1-standard-4 \
    --zone=us-central1-a \
    --async
done
```

### Use in Terraform

```hcl
resource "google_compute_instance" "osworld" {
  name         = "osworld-${var.instance_id}"
  machine_type = "n1-standard-4"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "osworld-golden-v1"
      size  = 50
    }
  }

  network_interface {
    network = "default"
  }

  tags = ["osworld-vm"]
}
```

---

## Golden Image Specifications

### What's Included

- **OS:** Ubuntu 22.04 LTS
- **Display:** Xvfb (virtual display :99, 1920x1080x24)
- **Window Manager:** Openbox
- **OSWorld Server:** Flask REST API on port 5000
- **Chrome:** 141.0.7390.107
- **Firefox:** Latest
- **LibreOffice:** Calc, Writer
- **Other Apps:** GIMP, gedit, nano, vim, pcmanfm

### Auto-Start Services

All services start automatically on boot:
- `xvfb.service` - Virtual display
- `openbox.service` - Window manager
- `osworld-server.service` - REST API

### Disk Size

- **50GB** total
- ~35GB used
- ~15GB free

### Network

- Port 5000: OSWorld REST API (internal only)
- Standard GCE networking

---

## Image Management

### List All Images

```bash
gcloud compute images list --filter="family=osworld"
```

### Create New Version

When you make improvements to `green-agent-vm`:

```bash
# Create v2
gcloud compute images create osworld-golden-v2 \
  --source-disk=green-agent-vm \
  --source-disk-zone=us-central1-a \
  --family=osworld \
  --description="Native OSWorld v2 - Chrome 142, bug fixes"
```

**Note:** The `family=osworld` tag means new VMs will automatically use the latest version.

### Delete Old Images

```bash
# Delete v1 when v2 is stable
gcloud compute images delete osworld-golden-v1 --quiet
```

### Share Image (Optional)

To share with other projects:

```bash
# Make image public (use with caution!)
gcloud compute images add-iam-policy-binding osworld-golden-v1 \
  --member='allAuthenticatedUsers' \
  --role='roles/compute.imageUser'

# Or share with specific project
gcloud compute images add-iam-policy-binding osworld-golden-v1 \
  --member='serviceAccount:SERVICE_ACCOUNT@PROJECT.iam.gserviceaccount.com' \
  --role='roles/compute.imageUser'
```

---

## Cost

### Storage Cost

- **$0.05/GB/month** for custom images
- 50GB image = **$2.50/month**

### Optimization

After creating multiple versions, you can delete old images to save costs.

---

## Troubleshooting

### Image Creation Fails

```bash
# Check disk status
gcloud compute disks describe green-agent-vm --zone=us-central1-a

# Ensure VM is running (imaging works better with running VMs)
gcloud compute instances list --filter="name=green-agent-vm"
```

### New VM Doesn't Work

```bash
# Check serial console output
gcloud compute instances get-serial-port-output osworld-test-2 --zone=us-central1-a

# SSH and check services
gcloud compute ssh osworld-test-2 --zone=us-central1-a
sudo systemctl status xvfb openbox osworld-server
```

### Services Not Starting

SSH into the new VM and restart:

```bash
sudo systemctl restart xvfb
sleep 2
sudo systemctl restart openbox
sleep 2
sudo systemctl restart osworld-server
sleep 3
curl http://localhost:5000/platform
```

---

## Best Practices

1. **Test Before Production**
   - Always create a test VM and verify it works
   - Run the full test suite
   - Test with actual OSWorld tasks

2. **Version Your Images**
   - Use descriptive names: `osworld-golden-v1`, `osworld-golden-v2`
   - Document changes in the description
   - Keep at least one previous version as backup

3. **Regular Updates**
   - Update Chrome/Firefox monthly
   - Update system packages for security
   - Rebuild image after significant changes

4. **Monitor Costs**
   - Delete unused images
   - Use lifecycle policies to auto-delete old images
   - Consider image storage costs ($2.50/month per image)

5. **Security**
   - Don't include secrets in images
   - Rotate SSH keys on first boot
   - Keep images in same project (don't share publicly)

---

## Next Steps

After creating the golden image:

1. ✅ **Test thoroughly** - Verify new VMs work perfectly
2. 🔨 **Build orchestrator** - Cloud Run service to manage VMs
3. 🔗 **Integrate with Green Agent** - Add OSWorld client
4. 📊 **Add monitoring** - Track VM health and costs
5. ⚡ **Optimize** - Preemptible VMs, auto-scaling, etc.

---

## Success Criteria

✅ Golden image created successfully
✅ New VMs boot in ~30 seconds
✅ All OSWorld endpoints work immediately
✅ Chrome launches and renders correctly
✅ No manual setup required

**If all criteria met:** You're ready for production! 🚀
