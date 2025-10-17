# Green Agent × OSWorld — Production Integration

A complete, production-ready integration between **Green Agent orchestration** and **OSWorld's realistic desktop environments** for automated agent evaluation. Successfully deployed on Google Cloud Platform with full Docker support.

---

## 🎯 Project Status

**✅ DEPLOYED ON GCP** — Fake mode validated, real mode testing in progress

- ✅ **Full OSWorld Integration**: Complete library-mode integration with WhiteAgentBridge
- ✅ **GCP Deployment**: Running on `n1-standard-4` VM with Docker support
- ✅ **Fake Mode**: Tested and working on GCP (10 steps, 1.4s, 100% success)
- ⚠️ **Real OSWorld Mode**: Integration complete, Docker permission troubleshooting in progress
- ✅ **Comprehensive Documentation**: 1,500+ lines of guides and status reports

**Test Results** (Fake Mode on GCP):
```json
{
  "success": 1,
  "steps": 10,
  "time_sec": 1.396,
  "failure_reason": null
}
```

**Real Mode Status**:
- ✅ OSWorld evaluation data downloaded (11.4GB, one-time)
- ⚠️ Docker permission configuration in progress
- See troubleshooting section below for details

---

## 📖 Documentation

- **[GCP_DEPLOYMENT.md](GCP_DEPLOYMENT.md)** — Complete GCP deployment guide (350 lines)
- **[INTEGRATION_STATUS.md](INTEGRATION_STATUS.md)** — Full status report and architecture
- **[OSWORLD_INTEGRATION.md](OSWORLD_INTEGRATION.md)** — Installation and testing guide (430 lines)
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** — Implementation details (399 lines)
- **[NEXT_STEPS.md](NEXT_STEPS.md)** — Recommended next actions

---

## 🎯 Project Overview

This project demonstrates a **production-ready agent evaluation system**:

- A **Green Agent** (orchestrator) manages tasks, environments, and metrics
- A **White Agent** (participant) interacts with desktop environments via HTTP API
- **OSWorld** provides realistic Ubuntu desktop environments via Docker
- **WhiteAgentBridge** translates between OSWorld and White Agent protocols

Think of it as an automated testing system where the Green Agent is the _evaluator_ and the White Agent is the _candidate_ being assessed in real desktop environments.

---

## 🚀 Quick Start

### Option 1: GCP Deployment (Recommended)

```bash
# 1. Create GCP VM
gcloud compute instances create green-agent-vm \
  --zone=us-central1-a \
  --machine-type=n1-standard-4 \
  --image-family=ubuntu-2204-lts \
  --boot-disk-size=50GB

# 2. SSH and setup
gcloud compute ssh green-agent-vm --zone=us-central1-a
git clone https://github.com/jpablomm/green-agent.git
cd green-agent
git submodule update --init --recursive

# 3. Install dependencies
python3.11 -m venv .venv
source .venv/bin/activate
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.local/bin/env
uv pip install -r requirements.txt
cd vendor/OSWorld && uv pip install -r requirements.txt && cd ../..

# 4. Configure Docker permissions (for real mode)
sudo usermod -aG docker $USER
newgrp docker

# 5. Start Green Agent
# Fake mode (no Docker needed):
export USE_FAKE_OSWORLD=1
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080

# OR Real mode (with Docker):
export USE_FAKE_OSWORLD=0
export OSWORLD_MAX_STEPS=15
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080
```

**Important for real mode**: Ensure the server is restarted AFTER Docker group membership is applied.

See **[GCP_DEPLOYMENT.md](GCP_DEPLOYMENT.md)** for detailed instructions.

### Option 2: Local Setup

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/jpablomm/green-agent.git
cd green_agent

# Setup environment
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd vendor/OSWorld && pip install -r requirements.txt && cd ../..

# Start services
# Terminal 1: White Agent (mock)
python white_agent/server.py --port 8090

# Terminal 2: Green Agent
export USE_FAKE_OSWORLD=1
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080
```

### Testing

```bash
# Test fake mode (no Docker required)
curl -X POST http://localhost:8080/assessments/start \
  -H 'Content-Type: application/json' \
  -d '{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}'

# Check results
curl http://localhost:8080/assessments/<ID>/results
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────┐
│ User Request → Green Agent (FastAPI)            │
│ POST /assessments/start                         │
│   - task_id: "ubuntu_001"                       │
│   - white_agent_url: "http://localhost:8090"    │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│ osworld_adapter.py                              │
│ ├─ Fake Mode: Synthetic screenshots (10 steps) │
│ └─ Real Mode: OSWorld library integration       │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│ OSWorld (vendor/OSWorld)                        │
│ ├─ DesktopEnv: Docker container (Ubuntu)        │
│ ├─ WhiteAgentBridge: HTTP → White Agent         │
│ └─ lib_run_single: Assessment execution loop    │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│ White Agent (FastAPI on port 8090)              │
│ POST /decide                                     │
│   - Receives: screenshot (base64), ui_hint      │
│   - Returns: {"op": "click", "args": {...}}     │
└─────────────────────────────────────────────────┘
```

---

## 🔧 Real OSWorld Mode

The integration is complete. Docker permission setup required on first run:

### Enable Real Mode

```bash
# 1. Ensure Docker permissions are configured (see Troubleshooting)
sudo usermod -aG docker $USER
newgrp docker  # Or logout/login

# 2. Restart server with real mode enabled
export USE_FAKE_OSWORLD=0
export OSWORLD_MAX_STEPS=15
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080
```

### Requirements

- **Docker**: For Ubuntu desktop containers
- **11.4GB disk space**: OSWorld evaluation data (downloads on first run, ~2-3 minutes)
- **4+ GB RAM**: For running containers
- **Linux recommended**: macOS has psutil permission issues (fixed with graceful fallback)
- **Docker group membership**: User must be in `docker` group

### What Happens (First Run)

1. **Initial download**: OSWorld downloads 11.4GB evaluation data (~2-3 minutes)
2. **Container creation**: OSWorld creates a Docker container with Ubuntu desktop
3. **WhiteAgentBridge**: Forwards observations to your White Agent via HTTP
4. **Action execution**: White Agent returns actions (click, type, hotkey, etc.)
5. **Desktop interaction**: Actions are executed in the real desktop environment
6. **Artifact capture**: Screenshots and metrics are captured

**Note**: The first real mode test will take longer due to the one-time data download. Subsequent runs use cached data.

See **[OSWORLD_INTEGRATION.md](OSWORLD_INTEGRATION.md)** for details.

---

## 📦 Key Components

### Created Files

| File | Lines | Purpose |
|------|-------|---------|
| `vendor/OSWorld/mm_agents/white_agent_bridge.py` | 280 | OSWorld ↔ White Agent bridge |
| `green_agent/task_converter.py` | 74 | Task format conversion |
| `GCP_DEPLOYMENT.md` | 350 | Cloud deployment guide |
| `INTEGRATION_STATUS.md` | 273 | Complete status report |
| `OSWORLD_INTEGRATION.md` | 430 | Installation & testing guide |

### Modified Files

| File | Changes |
|------|---------|
| `green_agent/osworld_adapter.py` | ~150 lines: Library mode, absolute paths, error logging |
| `green_agent/white_client.py` | 10 lines: Fake mode support |
| `vendor/OSWorld/.../provider.py` | 18 lines: macOS psutil permission fix |

---

## 🧰 Tech Stack

- **FastAPI** — Green & White agent REST APIs
- **OSWorld** — Realistic desktop environment simulation
- **Docker** — Ubuntu desktop containers
- **SQLite** — Lightweight run tracking
- **Python 3.11** — Core runtime
- **uv** — Fast package installer
- **httpx** — HTTP client for agent communication
- **Pillow + PyAutoGUI** — Fake mode rendering

---

## 📊 Outputs & Metrics

Each assessment records:

```json
{
  "assessment_id": "uuid",
  "task_id": "ubuntu_001",
  "white_agent": "http://localhost:8090",
  "success": 1,
  "steps": 10,
  "time_sec": 1.396,
  "failure_reason": null,
  "artifacts_dir": "runs/uuid/"
}
```

Artifacts include:
- Screenshots from each step
- OSWorld execution logs
- Action history
- Environment metadata

---

## 🧭 Next Steps

### Immediate
- [x] Deploy to GCP (completed)
- [x] Test fake OSWorld mode on GCP (completed, working)
- [ ] Complete Docker permission setup for real mode
- [ ] Test real OSWorld mode on GCP with Docker
- [ ] Deploy actual White Agent implementation
- [ ] Run end-to-end assessment with real actions

### Short-term
- [ ] Fix security issues from audit (SQL injection, SSRF, path traversal)
- [ ] Add monitoring (Prometheus, Grafana)
- [ ] Implement parallel assessment execution
- [ ] Add VNC streaming for live observation

### Medium-term
- [ ] Build WebUI for real-time progress tracking
- [ ] Add CI/CD pipeline for automated testing
- [ ] Implement multi-agent comparison mode
- [ ] Create leaderboard system

See **[NEXT_STEPS.md](NEXT_STEPS.md)** for detailed roadmap.

---

## 🔒 Security Notes

From the initial audit, these issues were identified but **not yet fixed** (deferred until integration validated):

- SQL injection in storage.py
- Path traversal in file operations
- SSRF in white_client.py
- Missing input validation

**Recommendation**: Fix these before exposing to untrusted users.

---

## 🛠️ Troubleshooting

### Real OSWorld Mode Issues

**Docker permission denied (Linux/GCP)**:

If you see `DockerException: Error while fetching server API version: ('Connection aborted.', PermissionError(13, 'Permission denied'))`:

```bash
# 1. Add user to docker group
sudo usermod -aG docker $USER

# 2. Apply group membership (choose one):
newgrp docker  # Option A: Apply in current shell
# OR
exit && ssh back in  # Option B: Logout and login

# 3. Verify Docker access
docker ps  # Should work without sudo

# 4. IMPORTANT: Restart the uvicorn server
# Kill existing server (Ctrl+C or pkill)
pkill -f uvicorn
# Restart with real mode
export USE_FAKE_OSWORLD=0
export OSWORLD_MAX_STEPS=15
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080
```

**Key point**: The uvicorn process must be restarted AFTER the Docker group membership is applied. Simply running `newgrp docker` in a different terminal won't affect an already-running server.

**First run takes long**:
- OSWorld downloads 11.4GB evaluation data on first real mode run (~2-3 minutes)
- Progress bar will show download status
- Subsequent runs use cached data and start immediately

### macOS Issues

**psutil AccessDenied**:
- Fixed with graceful fallback in Docker provider
- Or grant "Full Disk Access" to Terminal in System Settings

**Docker Performance**:
- Docker Desktop on ARM is slower than Linux
- Recommend GCP deployment for production

### Linux Issues

**Missing Python headers**:
```bash
sudo apt-get install python3.11-dev build-essential
```

### General

**Port conflicts**:
```bash
# Check what's using port 8080
lsof -i :8080
# Kill if needed
kill -9 $(lsof -t -i:8080)
```

**Stale containers**:
```bash
docker ps -a  # List all containers
docker rm $(docker ps -a -q)  # Remove all
```

**Server unresponsive during first run**:
- Normal during 11.4GB data download
- Wait for download to complete (~2-3 minutes)
- Server will become responsive after download

See **[OSWORLD_INTEGRATION.md](OSWORLD_INTEGRATION.md#troubleshooting)** for more solutions.

---

## 👩‍🏫 Educational Value

This project demonstrates:

- **Agent-to-Agent (A2A) Communication**: REST API-based orchestration
- **Benchmark Integration**: How to connect research benchmarks to custom systems
- **Docker Environment Management**: Container lifecycle for reproducible testing
- **Production Deployment**: GCP, systemd, monitoring, cost optimization
- **Error Handling**: Graceful degradation, comprehensive logging
- **Library vs Subprocess**: Using OSWorld as a library rather than CLI wrapper

Perfect for:
- CS294 coursework on agent evaluation
- Research on multimodal agent reasoning
- Building custom agent benchmarking systems
- Understanding production ML systems architecture

---

## 💰 Cost Estimates (GCP)

| Configuration | Monthly Cost |
|---------------|--------------|
| n1-standard-4 (on-demand) | ~$120 |
| + 50GB disk | ~$8 |
| + Network egress | ~$12 |
| **Total (on-demand)** | **~$140** |
| **Total (preemptible)** | **~$40** |

See **[GCP_DEPLOYMENT.md#cost-optimization](GCP_DEPLOYMENT.md#cost-optimization)** for savings strategies.

---

## 🤝 Contributing

This is an educational prototype. To contribute:

1. Fork the repository
2. Create a feature branch
3. Test locally with fake mode
4. Test on GCP with real mode (if applicable)
5. Update documentation
6. Submit pull request

---

## 📝 License

© 2025 AgentBeats Project — Open educational prototype

---

## 🔗 Links

- **OSWorld**: https://github.com/xlang-ai/OSWorld
- **AgentBeats**: (Coming soon)
- **Issue Tracker**: https://github.com/jpablomm/green-agent/issues
- **GCP Console**: https://console.cloud.google.com/compute

---

## 🎉 Acknowledgments

- UC Berkeley OSWorld team for the benchmark
- AgentBeats project for the orchestration model
- CS294 course staff and students

Built with ❤️ for agent evaluation research.
