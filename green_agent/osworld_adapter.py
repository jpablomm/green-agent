import os, time, base64, io, uuid, json, sys, subprocess, glob
from typing import Dict, Any, Generator
from PIL import Image, ImageDraw, ImageFont

USE_FAKE = os.environ.get("USE_FAKE_OSWORLD", "1") == "1"
MAX_STEPS = int(os.environ.get("MAX_STEPS", 120))
MAX_TIME = int(os.environ.get("MAX_TIME_SEC", 600))
W = int(os.environ.get("DESKTOP_W", 1920))
H = int(os.environ.get("DESKTOP_H", 1080))
OSWORLD_PROVIDER = os.environ.get("OSWORLD_PROVIDER", "docker")
OSWORLD_HEADLESS = os.environ.get("OSWORLD_HEADLESS", "1") == "1"
OSWORLD_OBS_TYPE = os.environ.get("OSWORLD_OBS_TYPE", "screenshot")
OSWORLD_MAX_STEPS = int(
    os.environ.get("OSWORLD_MAX_STEPS", os.environ.get("MAX_STEPS", 15))
)
OSWORLD_SLEEP_AFTER_EXEC = int(os.environ.get("OSWORLD_SLEEP_AFTER_EXECUTION", 3))
OSWORLD_RESULT_SUBDIR = os.environ.get("OSWORLD_RESULT_SUBDIR", "osworld")
OSWORLD_CLIENT_PASSWORD = os.environ.get("OSWORLD_CLIENT_PASSWORD", "password")


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


def run_osworld_like(
    task: Dict[str, Any], white_decide, artifacts_dir: str | None = None
) -> Dict[str, Any]:
    """Fake OSWorld loop: emit frames, ask white agent for actions, mark success at the end."""
    t0 = time.time()
    steps = 0
    failure = None
    frames_dir = None
    if artifacts_dir:
        frames_dir = os.path.join(artifacts_dir, "frames")
        os.makedirs(frames_dir, exist_ok=True)
    for fr in _fake_frames(task.get("hints", [])):
        obs = {
            "frame_id": fr["frame_id"],
            "image_png_b64": fr["png"],
            "ui_hint": fr.get("hint"),
            "done": False,
        }
        # Save frame artifact if requested
        if frames_dir:
            try:
                with open(
                    os.path.join(frames_dir, f"{fr['frame_id']:04d}.png"), "wb"
                ) as fh:
                    fh.write(base64.b64decode(fr["png"]))
            except Exception:
                # Artifacts are best-effort in MVP
                pass
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


def _count_screenshots(result_dir: str) -> int:
    try:
        return len(glob.glob(os.path.join(result_dir, "**", "*.png"), recursive=True))
    except Exception:
        return 0


def _parse_basic_result(result_dir: str, rc: int, t0: float) -> Dict[str, Any]:
    steps = _count_screenshots(result_dir)
    success = 1 if rc == 0 else 0
    dt = time.time() - t0
    return {
        "success": success,
        "steps": steps,
        "time_sec": round(dt, 3),
        "failure_reason": None if success else f"osworld_exit_code_{rc}",
        "artifacts": {"result_dir": result_dir},
    }


def run_osworld(
    task: Dict[str, Any], white_decide, artifacts_dir: str | None = None
) -> Dict[str, Any]:
    if USE_FAKE:
        return run_osworld_like(task, white_decide, artifacts_dir)

    # Real OSWorld path: spawn vendor/OSWorld runner with Docker provider.
    vendor_root = os.path.join("vendor", "OSWorld")
    run_py = os.path.join(vendor_root, "run.py")
    if not os.path.exists(run_py):
        raise FileNotFoundError(
            f"OSWorld runner not found at {run_py}. Add submodule and install deps."
        )

    # Prepare result directory under artifacts
    base_artifacts = artifacts_dir or os.path.join("runs", str(uuid.uuid4()))
    os.makedirs(base_artifacts, exist_ok=True)
    result_dir = os.path.join(base_artifacts, OSWORLD_RESULT_SUBDIR)
    os.makedirs(result_dir, exist_ok=True)

    log_path = os.path.join(result_dir, "osworld.log")

    cmd = [
        sys.executable,
        run_py,
        "--provider_name",
        OSWORLD_PROVIDER,
        "--observation_type",
        OSWORLD_OBS_TYPE,
        "--max_steps",
        str(OSWORLD_MAX_STEPS),
        "--sleep_after_execution",
        str(OSWORLD_SLEEP_AFTER_EXEC),
        "--result_dir",
        result_dir,
        "--client_password",
        OSWORLD_CLIENT_PASSWORD,
    ]
    if OSWORLD_HEADLESS:
        cmd.append("--headless")

    env = os.environ.copy()
    env["PYTHONPATH"] = f"{os.getcwd()}:{env.get('PYTHONPATH','')}"

    t0 = time.time()
    with open(log_path, "ab", buffering=0) as log_f:
        log_f.write(
            ("\n==== OSWorld start ====: " + time.ctime() + "\n").encode("utf-8")
        )
        log_f.write(("CMD: " + " ".join(cmd) + "\n").encode("utf-8"))
        proc = subprocess.Popen(
            cmd,
            stdout=log_f,
            stderr=subprocess.STDOUT,
            env=env,
            cwd=os.getcwd(),
        )
        rc = proc.wait()

    # NOTE: white_decide is not wired into OSWorld run.py yet; bridge to be added later.
    return _parse_basic_result(result_dir, rc, t0)
