from __future__ import annotations
import argparse
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any
import uvicorn


class Observation(BaseModel):
    frame_id: int
    image_png_b64: str
    ui_hint: str | None = None
    done: bool = False


app = FastAPI(title="White Agent (baseline)")


@app.post("/reset")
def reset():
    return {"ok": True}


@app.post("/decide")
def decide(obs: Observation) -> Dict[str, Any]:
    # Dumb baseline: follow hints with a generic sequence of ops.
    # For the MVP fake runner, the action is ignored by the adapter.
    if obs.ui_hint and "Ctrl+S" in obs.ui_hint:
        return {"op": "hotkey", "args": {"keys": ["ctrl", "s"]}}
    return {"op": "click", "args": {"x": 200, "y": 950}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8090)
    args = parser.parse_args()
    uvicorn.run(app, host="0.0.0.0", port=args.port)
