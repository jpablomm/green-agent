from __future__ import annotations
import os, json, uuid, time, base64
from fastapi import FastAPI, HTTPException
from typing import Dict, Any
from .models import StartAssessmentRequest, AssessmentStatus, RunMetrics
from . import storage
from .white_client import WhiteClient
from .osworld_adapter import run_osworld

app = FastAPI(title="Green Agent (OSWorld MVP)")


@app.get("/card")
def card() -> Dict[str, Any]:
    return {
        "name": "Green-OSWorld-MVP",
        "version": "0.1.0",
        "assessments": ["osworld-ubuntu-tiny"],
        "fake_osworld": os.environ.get("USE_FAKE_OSWORLD", "1"),
    }


@app.post("/reset")
def reset():
    # stateless MVP; extend with caches if needed
    return {"ok": True}


@app.post("/assessments/start")
def start_assessment(req: StartAssessmentRequest) -> Dict[str, Any]:
    assess_id = str(uuid.uuid4())
    artifacts_dir = storage.create_run(assess_id, req.task_id, req.white_agent_url)

    # Load task JSON (MVP: tasks/<task_id>.json)
    task_path = os.path.join("tasks", f"{req.task_id}.json")
    if not os.path.exists(task_path):
        raise HTTPException(404, f"Task not found: {req.task_id}")
    with open(task_path, "r") as f:
        task = json.load(f)

    # White client
    white = WhiteClient(req.white_agent_url)
    white.reset()

    t0 = time.time()
    steps = 0
    failure = None

    def white_decide(obs: Dict[str, Any]) -> Dict[str, Any]:
        nonlocal steps
        steps += 1
        return white.decide(obs)

    try:
        result = run_osworld(task, white_decide, artifacts_dir)
    except Exception as e:
        failure = f"adapter_error: {e}"
        result = {
            "success": 0,
            "steps": steps,
            "time_sec": time.time() - t0,
            "failure_reason": failure,
            "artifacts": {},
        }

    storage.update_status(
        assess_id,
        status="completed",
        success=int(result.get("success", 0)),
        steps=int(result.get("steps", 0)),
        time_sec=float(result.get("time_sec", 0.0)),
        failure_reason=result.get("failure_reason"),
    )

    return {
        "assessment_id": assess_id,
        "status": "running" if failure is None else "completed",
    }


@app.get("/assessments/{assessment_id}/status")
def status(assessment_id: str) -> AssessmentStatus:
    row = storage.fetch_run(assessment_id)
    if not row:
        raise HTTPException(404, "assessment not found")
    done = row["status"] == "completed"
    return AssessmentStatus(
        assessment_id=assessment_id,
        status=row["status"],
        progress=1.0 if done else 0.5,
        last_step=row.get("steps") or 0,
    )


@app.get("/assessments/{assessment_id}/results")
def results(assessment_id: str) -> RunMetrics:
    row = storage.fetch_run(assessment_id)
    if not row:
        raise HTTPException(404, "assessment not found")
    return RunMetrics(
        assessment_id=assessment_id,
        task_id=row["task_id"],
        white_agent=row["white_agent"],
        success=row["success"] or 0,
        steps=row["steps"] or 0,
        time_sec=row["time_sec"] or 0.0,
        failure_reason=row["failure_reason"],
        artifacts_dir=row["artifacts_dir"],
    )
