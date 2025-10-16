# AgentBeats × OSWorld — Green Agent MVP

A minimal, educational benchmark integration showing how to connect **AgentBeats’ Green Agent orchestration model** with **OSWorld’s realistic desktop environments**. Designed for students and researchers who want to explore automated agent evaluation in a controlled, reproducible way.

---

## 🎯 Project Overview

This MVP demonstrates the full flow of an **agent evaluation system**:

- A **Green Agent** (the orchestrator) sets up tasks, resets environments, communicates with the White Agent, and records metrics.
- A **White Agent** (the participant) interacts with the environment step-by-step, sending actions based on visual and textual observations.
- A **(Fake) OSWorld Adapter** simulates a real desktop environment, producing screenshots and hints, and can later be replaced with the **real OSWorld benchmark**.

You can think of it as a “test bench” where the Green Agent is the _teacher_ and the White Agent is the _student_ being tested inside a simplified OS-like world.

---

## 🧩 Why This Project Exists

Large agent benchmarks like **OSWorld**, **BrowserGym**, and **TauBench** require complex environments, multi-step orchestration, and standardized evaluation. This MVP shows how to build a minimal orchestration layer that:

- Standardizes how to run an assessment.
- Resets and reuses environments safely.
- Records metrics and logs.
- Can later scale to full OSWorld tasks or multi-agent tests in AgentBeats.

By abstracting OSWorld behind a **plug-in adapter**, you can later connect real benchmarks without rewriting orchestration logic.

---

## 🚀 Quick Start

### Local setup

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# start white agent (participant)
python white_agent/server.py --port 8090

# start green agent (orchestrator)
uvicorn green_agent.app:app --host 0.0.0.0 --port 8080 --reload
```

Then, in another terminal:

```bash
curl -X POST http://localhost:8080/assessments/start \
  -H 'content-type: application/json' \
  -d '{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}'
```

To see progress and results:

```bash
curl http://localhost:8080/assessments/<ASSESS_ID>/status
curl http://localhost:8080/assessments/<ASSESS_ID>/results
```

Artifacts and logs are stored in `runs/` and `runs.db`.

---

## 🧠 How It Works

1. The **Green Agent** receives an `/assessments/start` request.
2. It loads a task definition (goal, constraints, hints).
3. It resets and starts communication with the **White Agent**.
4. The **Fake OSWorld Runner** streams visual frames (screenshots) and text hints.
5. The **White Agent** decides which action to take (click, type, hotkey, etc.).
6. The Green Agent records all steps and metrics.
7. Once done, results are logged and retrievable via REST.

---

## 🔧 Switching to Real OSWorld

This MVP ships with a **fake OSWorld simulation** so you can run everything without a GUI or Docker setup.

To integrate the real benchmark:

```bash
git submodule add https://github.com/xlang-ai/OSWorld vendor/OSWorld
pip install -r vendor/OSWorld/requirements.txt
export USE_FAKE_OSWORLD=0
```

Then, implement the runner call in `green_agent/osworld_adapter.py` to spawn OSWorld’s CLI (`run.py`) and parse its outputs.

---

## 🧰 Tech Stack

- **FastAPI** — Green & White agent APIs
- **SQLite** — lightweight run tracking
- **Pillow + PyAutoGUI** — fake desktop rendering
- **HTTPX** — inter-agent communication
- **Docker Compose** — optional local container setup

---

## 📊 Outputs & Metrics

Each assessment logs:

- `success` (0/1)
- `steps` taken
- `time_sec`
- `failure_reason`
- optional screenshots & artifacts

All metrics are saved in `runs.db` and can be visualized later (e.g., with SQLite-utils or Looker Studio when extended).

---

## 🧩 Architecture Summary

```
┌─────────────────────────────┐
│ Green Agent (FastAPI)       │
│ ├─ Loads task spec           │
│ ├─ Talks to White Agent      │
│ ├─ Runs OSWorld Adapter      │
│ ├─ Logs steps & metrics      │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│ White Agent (FastAPI)       │
│ ├─ Receives observations     │
│ ├─ Returns next action       │
└─────────────────────────────┘
          │
          ▼
┌─────────────────────────────┐
│ OSWorld Adapter             │
│ ├─ Fake: renders static GUI │
│ ├─ Real: calls OSWorld repo │
└─────────────────────────────┘
```

---

## 🧭 Next Steps

- Integrate **real OSWorld** runner (replace fake adapter).
- Add **parallel runs** or **multi-agent assessments**.
- Log **screenshots + GIFs** for visualization.
- Export metrics to **BigQuery** or a leaderboard.

---

## 👩‍🏫 Educational Value

This MVP is meant for **hands-on learning** about agent benchmarking:

- Understand A2A-style orchestration.
- Explore state-reset, reproducibility, and evaluation design.
- Build intuition for how realistic benchmarks like OSWorld or BrowserGym operate.

Use this as a foundation for research, demos, or coursework on agent reliability and multimodal reasoning.

---

© 2025 AgentBeats Project — open educational prototype.
