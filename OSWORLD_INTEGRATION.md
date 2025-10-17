# OSWorld Integration Guide

This document explains how to install dependencies and test the White Agent integration with OSWorld.

---

## Prerequisites

- Python 3.11 (recommended for macOS ARM, required for some dependencies)
- Docker Desktop (for OSWorld desktop environment provider)
- Virtual environment activated

---

## Phase 5: Installing OSWorld Dependencies

### Option A: Using pip

```bash
# Navigate to OSWorld vendor directory
cd vendor/OSWorld

# Install dependencies
pip install -r requirements.txt
```

### Option B: Using uv (faster, recommended)

```bash
# Navigate to OSWorld vendor directory
cd vendor/OSWorld

# Install with uv
uv pip install -r requirements.txt
```

### macOS ARM (Apple Silicon) Specific Instructions

If you encounter errors on macOS ARM64:

1. **Use Python 3.11** (not 3.13):
```bash
# With uv
uv python install 3.11
uv venv -p 3.11 .venv
source .venv/bin/activate
```

2. **Apply constraints for torch**:
```bash
uv pip install -r vendor/OSWorld/requirements.txt -c constraints-macos-arm.txt
```

3. **Allow pre-releases if needed**:
```bash
uv pip install --prerelease=allow -r vendor/OSWorld/requirements.txt
```

4. **For borb wheel extraction errors**:
```bash
uv cache clean
uv pip install --no-binary borb borb==3.0.2
uv pip install --prerelease=allow -r vendor/OSWorld/requirements.txt --no-deps
```

### Expected Installation Time

- **First time**: 15-30 minutes (downloads ML models, compiles packages)
- **Subsequent installs**: 5-10 minutes (uses cache)

### Verifying Installation

```bash
# Test OSWorld imports
cd /path/to/green_agent
python3 -c "
import sys
sys.path.insert(0, 'vendor/OSWorld')
from desktop_env.desktop_env import DesktopEnv
import lib_run_single
from mm_agents.white_agent_bridge import WhiteAgentBridge
print('✅ All imports successful!')
"
```

---

## Phase 6: Testing the Integration

### Test 1: Fake Mode (Sanity Check)

Ensure fake mode still works after changes:

```bash
# Terminal 1: Start White Agent
python white_agent/server.py --port 8090

# Terminal 2: Start Green Agent (fake mode)
export USE_FAKE_OSWORLD=1
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080

# Terminal 3: Trigger assessment
curl -X POST http://localhost:8080/assessments/start \
  -H 'Content-Type: application/json' \
  -d '{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}'

# Get result
curl http://localhost:8080/assessments/<assessment_id>/results
```

**Expected Output:**
- success: 1
- steps: 10
- time_sec: < 5 seconds
- 10 PNG frames in `runs/<assessment_id>/frames/`

### Test 2: Real OSWorld Mode (Full Integration)

**Prerequisites:**
- Docker Desktop running
- OSWorld dependencies installed
- At least 4GB RAM available

```bash
# Terminal 1: Start White Agent
python white_agent/server.py --port 8090

# Terminal 2: Start Green Agent (real mode)
export USE_FAKE_OSWORLD=0
export OSWORLD_PROVIDER=docker
export OSWORLD_HEADLESS=1
export OSWORLD_MAX_STEPS=10
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080

# Terminal 3: Trigger assessment
curl -X POST http://localhost:8080/assessments/start \
  -H 'Content-Type: application/json' \
  -d '{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}'

# Monitor logs
tail -f runs/<assessment_id>/osworld/osworld.log

# Get result (will take several minutes)
curl http://localhost:8080/assessments/<assessment_id>/results
```

**Expected Behavior:**
1. OSWorld creates Docker container with Ubuntu desktop
2. Green Agent sends screenshots to White Agent
3. White Agent returns actions (click, type, etc.)
4. OSWorld executes actions in desktop environment
5. Assessment completes after max_steps or DONE action
6. Results saved with screenshots and trajectory log

**First Run Notes:**
- Docker will download Ubuntu desktop image (~2GB)
- First assessment may take 5-10 minutes
- Subsequent runs are faster

### Test 3: Verify White Agent Communication

Check that White Agent is receiving correct observations:

```bash
# Add logging to white_agent/server.py
# In the decide() function, add:
import logging
logging.basicConfig(level=logging.INFO)

@app.post("/decide")
def decide(obs: Observation) -> Dict[str, Any]:
    logging.info(f"Received observation: frame_id={obs.frame_id}, hint={obs.ui_hint}")
    # ... rest of function

# Then run assessment and check logs
```

### Test 4: Action Conversion Verification

Create a test file to verify action conversion:

```python
# test_action_conversion.py
import sys
sys.path.insert(0, 'vendor/OSWorld')

from mm_agents.white_agent_bridge import WhiteAgentBridge

bridge = WhiteAgentBridge("http://localhost:8090")

# Test various actions
test_cases = [
    ({"op": "click", "args": {"x": 100, "y": 200}}, "pyautogui.click(100, 200)"),
    ({"op": "hotkey", "args": {"keys": ["ctrl", "s"]}}, "pyautogui.hotkey('ctrl', 's')"),
    ({"op": "type", "args": {"text": "Hello"}}, 'pyautogui.typewrite("""Hello""", interval=0.01)'),
    ({"op": "done"}, "DONE"),
]

for action_in, expected_out in test_cases:
    result = bridge._convert_action(action_in)[0]
    assert expected_out in result, f"Failed: {action_in} -> {result}"
    print(f"✓ {action_in['op']} converts correctly")

print("✅ All action conversions passed!")
```

Run:
```bash
python test_action_conversion.py
```

---

## Troubleshooting

### Error: "OSWorld dependencies not installed"

**Cause:** OSWorld modules not in Python path

**Solution:**
```bash
cd vendor/OSWorld
pip install -r requirements.txt
```

### Error: "white_agent_url is required for real OSWorld mode"

**Cause:** Missing white_agent_url parameter

**Solution:** Ensure the POST request includes white_agent_url:
```json
{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}
```

### Error: "Docker provider not available"

**Cause:** Docker not running or not accessible

**Solutions:**
1. Start Docker Desktop
2. Verify Docker is running: `docker ps`
3. Check Docker permissions: `docker run hello-world`

### Error: "Connection refused to White Agent"

**Cause:** White Agent not running or wrong port

**Solutions:**
1. Start White Agent: `python white_agent/server.py --port 8090`
2. Verify it's running: `curl http://localhost:8090/card`
3. Check firewall isn't blocking port 8090

### Performance: Assessment takes too long

**Solutions:**
1. Reduce max_steps: `export OSWORLD_MAX_STEPS=5`
2. Use headless mode: `export OSWORLD_HEADLESS=1`
3. Ensure Docker has enough resources (4GB+ RAM)

### macOS Specific: "No module named 'wrapt_timeout_decorator'"

**Solution:**
```bash
pip install wrapt_timeout_decorator
```

### macOS Specific: "Torch wheels not found"

**Solution:**
```bash
uv pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1
uv pip install -r vendor/OSWorld/requirements.txt --no-deps
```

---

## Validation Checklist

Use this checklist to verify the integration is working:

- [ ] Fake mode assessment completes successfully
- [ ] Real OSWorld mode starts without errors
- [ ] White Agent receives observations (check logs)
- [ ] White Agent actions are converted correctly
- [ ] OSWorld executes actions in desktop
- [ ] Screenshots are captured and saved
- [ ] Metrics are recorded in database
- [ ] Artifacts directory contains logs and screenshots

---

## Performance Benchmarks

Expected performance on different systems:

| System | Fake Mode | Real OSWorld (10 steps) |
|--------|-----------|------------------------|
| macOS M1 (8GB) | 2-3 sec | 3-5 min |
| macOS M1 (16GB) | 2-3 sec | 2-3 min |
| Linux x86 (16GB) | 2-3 sec | 2-4 min |
| Linux x86 (32GB) | 2-3 sec | 1-2 min |

*Note: First run includes Docker image download (~2GB) which adds 5-10 minutes*

---

## Next Steps

Once the integration is validated:

1. **Expand White Agent Logic:** Improve decision-making beyond baseline
2. **Add More Tasks:** Create additional task definitions in `tasks/`
3. **Implement Real Evaluators:** Replace placeholder evaluator with actual checks
4. **Optimize Performance:** Parallel assessments, caching, etc.
5. **Add Monitoring:** Metrics, dashboards, alerts
6. **Scale Up:** Multiple providers (AWS, GCP, Azure)

---

## Support

If you encounter issues not covered here:

1. Check OSWorld logs: `runs/<assessment_id>/osworld/osworld.log`
2. Check Green Agent logs
3. Enable debug logging: `export LOG_LEVEL=DEBUG`
4. Review the audit report for known issues

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│ Green Agent (FastAPI)                                   │
│ ├─ POST /assessments/start                              │
│ │  ├─ Loads task from tasks/<task_id>.json             │
│ │  ├─ Creates assessment_id and artifacts directory     │
│ │  └─ Calls run_osworld(task, ..., white_agent_url)   │
│ └─ osworld_adapter.py                                   │
│    ├─ Fake Mode: Generates synthetic screenshots        │
│    └─ Real Mode: Uses OSWorld library ──────────────┐   │
└─────────────────────────────────────────────────────│───┘
                                                      │
                                                      ▼
┌─────────────────────────────────────────────────────────┐
│ OSWorld Library (vendor/OSWorld)                        │
│ ├─ DesktopEnv: Manages Docker container with Ubuntu     │
│ ├─ WhiteAgentBridge: Forwards observations to HTTP API  │
│ └─ lib_run_single: Runs evaluation loop                │
│    └─ For each step:                                    │
│       1. Get screenshot from environment ───────────┐   │
│       2. Send to White Agent Bridge                 │   │
│       3. Receive action                            │   │
│       4. Execute in environment                    │   │
│       5. Check if done                             │   │
└────────────────────────────────────────────────────│───┘
                                                      │
                                                      ▼
┌─────────────────────────────────────────────────────────┐
│ White Agent Bridge (mm_agents/white_agent_bridge.py)    │
│ ├─ predict(instruction, obs):                           │
│ │  ├─ Converts obs["screenshot"] to base64             │
│ │  ├─ POST to white_agent_url/decide                   │
│ │  └─ Converts action to pyautogui format              │
│ └─ reset(): POST to white_agent_url/reset             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼ HTTP
┌─────────────────────────────────────────────────────────┐
│ White Agent (FastAPI on port 8090)                      │
│ ├─ POST /reset: Prepare for new assessment              │
│ └─ POST /decide:                                        │
│    ├─ Receives: frame_id, image_png_b64, ui_hint       │
│    └─ Returns: {"op": "click", "args": {"x": 200, ...}}│
└─────────────────────────────────────────────────────────┘
```

---

**Last Updated:** 2025-10-16
**Version:** 1.0.0
