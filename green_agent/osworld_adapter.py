import os, time, base64, io, uuid, json
from typing import Dict, Any, Generator
from PIL import Image, ImageDraw, ImageFont

USE_FAKE = os.environ.get("USE_FAKE_OSWORLD", "1") == "1"
MAX_STEPS = int(os.environ.get("MAX_STEPS", 120))
MAX_TIME = int(os.environ.get("MAX_TIME_SEC", 600))
W = int(os.environ.get("DESKTOP_W", 1920))
H = int(os.environ.get("DESKTOP_H", 1080))


# --- Fake runner simulates an OS desktop and task progression ---
def _png_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def _fake_frames(hints: list[str]) -> Generator[Dict[str, Any], None, None]:
    steps = min(10, MAX_STEPS)
    for i in range(1, steps + 1):
        img = Image.new("RGB", (W, H), (240, 242, 245))
        drw = ImageDraw.Draw(img)
        drw.rectangle([(40, H - 120), (300, H - 40)], outline=(30, 30, 30), width=3)
        drw.text((60, H - 110), "Writer", fill=(10, 10, 10))
        drw.text((40, 40), f"Step {i}", fill=(0, 0, 0))
        hint = hints[min(i - 1, len(hints) - 1)] if hints else None
        yield {"frame_id": i, "png": _png_b64(img), "hint": hint, "done": i == steps}


def run_osworld_like(task: Dict[str, Any], white_decide) -> Dict[str, Any]:
    """Fake OSWorld loop: emit frames, ask white agent for actions, mark success at the end."""
    t0 = time.time()
    steps = 0
    failure = None
    for fr in _fake_frames(task.get("hints", [])):
        obs = {
            "frame_id": fr["frame_id"],
            "image_png_b64": fr["png"],
            "ui_hint": fr.get("hint"),
            "done": False,
        }
        try:
            _ = white_decide(obs)  # we ignore the action in fake mode
        except Exception as e:
            failure = f"white_decide_error: {e}"
            break
        steps += 1
    done = failure is None
    dt = time.time() - t0
    return {
        "success": 1 if done else 0,
        "steps": steps,
        "time_sec": round(dt, 3),
        "failure_reason": failure,
        "artifacts": {},
    }


# --- Real OSWorld adapter (skeleton) ---
# When USE_FAKE_OSWORLD=0, implement spawning the OSWorld runner here.
# Outline:
# - write a temporary agent stub that forwards obs->white_agent and returns actions
# - call vendor/OSWorld runner script with task list, output dir
# - parse outputs to the same dict structure as above


def run_osworld(task: Dict[str, Any], white_decide) -> Dict[str, Any]:
    if USE_FAKE:
        return run_osworld_like(task, white_decide)
    # Placeholder for future real adapter
    raise NotImplementedError(
        "Real OSWorld integration not wired in this MVP. Set USE_FAKE_OSWORLD=1."
    )
