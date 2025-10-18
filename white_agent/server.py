from __future__ import annotations
import argparse
import logging
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Dict, Any, Optional
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class Observation(BaseModel):
    frame_id: int
    image_png_b64: str
    instruction: str = ""
    ui_hint: Optional[str] = None
    done: bool = False


app = FastAPI(title="White Agent (Native OSWorld)")

# State tracking
task_state = {
    "step": 0,
    "last_action": None,
    "task_done": False
}


@app.post("/reset")
def reset():
    """Reset agent state"""
    global task_state
    task_state = {
        "step": 0,
        "last_action": None,
        "task_done": False
    }
    logger.info("White Agent reset")
    return {"ok": True}


@app.post("/decide")
def decide(obs: Observation) -> Dict[str, Any]:
    """
    Decide next action based on observation.

    Returns action in native OSWorld format:
    - action_type: "execute", "click", "type", "DONE"
    - command: for execute actions
    - x, y: for click actions
    - text: for type actions
    """
    global task_state

    step = obs.frame_id
    instruction = obs.instruction.lower()
    task_state["step"] = step

    logger.info(f"Step {step}: Deciding action for instruction: {instruction[:50]}")

    # Simple task-based logic

    # 1. Screenshot-only tasks
    if "screenshot" in instruction or "capture" in instruction:
        logger.info(f"Step {step}: Screenshot task - finishing after observation")
        if step >= 1:
            return {"action_type": "DONE"}
        return {"action_type": "execute", "command": "echo 'Screenshot captured'"}

    # 2. Chrome tasks
    if "chrome" in instruction or "google" in instruction:
        if step == 1:
            logger.info(f"Step {step}: Opening Chrome")
            return {
                "action_type": "execute",
                "command": "google-chrome --no-sandbox --user-data-dir=/tmp/chrome-test --new-window https://google.com"
            }
        elif step == 2:
            logger.info(f"Step {step}: Waiting for Chrome to load")
            return {"action_type": "execute", "command": "sleep 2"}
        elif step >= 3:
            logger.info(f"Step {step}: Chrome task complete")
            return {"action_type": "DONE"}

    # 3. File/document tasks
    if "file" in instruction or "document" in instruction:
        if step == 1:
            logger.info(f"Step {step}: Opening file manager")
            return {"action_type": "execute", "command": "pcmanfm &"}
        elif step >= 3:
            return {"action_type": "DONE"}

    # 4. Text editor tasks
    if "text" in instruction or "edit" in instruction or "write" in instruction:
        if step == 1:
            logger.info(f"Step {step}: Opening text editor")
            return {"action_type": "execute", "command": "gedit &"}
        elif step == 2:
            logger.info(f"Step {step}: Typing text")
            return {"action_type": "type", "text": "Hello from White Agent"}
        elif step >= 3:
            return {"action_type": "DONE"}

    # Default: observe for a few steps then finish
    if step >= 5:
        logger.info(f"Step {step}: Max steps reached, finishing")
        return {"action_type": "DONE"}

    # Wait and observe
    logger.info(f"Step {step}: Observing...")
    return {"action_type": "execute", "command": "sleep 1"}


@app.get("/health")
def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "agent": "white-agent",
        "version": "0.2.0",
        "current_step": task_state["step"]
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="White Agent for OSWorld")
    parser.add_argument("--port", type=int, default=9000, help="Port to run on")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host to bind to")
    args = parser.parse_args()

    logger.info(f"Starting White Agent on {args.host}:{args.port}")
    uvicorn.run(app, host=args.host, port=args.port)
