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
    task: Dict[str, Any],
    white_decide,
    artifacts_dir: str | None = None,
    white_agent_url: str | None = None
) -> Dict[str, Any]:
    """
    Run OSWorld assessment with White Agent.

    Args:
        task: Task dictionary (Green Agent format)
        white_decide: Callback function (unused in real mode, kept for compatibility)
        artifacts_dir: Directory to save artifacts
        white_agent_url: URL of White Agent HTTP API (required for real mode)

    Returns:
        Dictionary with assessment results
    """
    if USE_FAKE:
        return run_osworld_like(task, white_decide, artifacts_dir)

    # Real OSWorld path: use OSWorld as a library
    # Use absolute path relative to this file's location
    green_agent_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(green_agent_dir)
    vendor_root = os.path.join(project_root, "vendor", "OSWorld")

    # Add vendor to path for imports
    if vendor_root not in sys.path:
        sys.path.insert(0, vendor_root)

    # Import OSWorld modules (with error handling)
    try:
        from desktop_env.desktop_env import DesktopEnv
        import lib_run_single
        from mm_agents.white_agent_bridge import WhiteAgentBridge
        from green_agent.task_converter import convert_to_osworld_format, extract_max_steps
    except ImportError as e:
        return {
            "success": 0,
            "steps": 0,
            "time_sec": 0.0,
            "failure_reason": f"OSWorld dependencies not installed: {e}. "
                            "Run: pip install -r vendor/OSWorld/requirements.txt",
            "artifacts": {}
        }

    if not white_agent_url:
        return {
            "success": 0,
            "steps": 0,
            "time_sec": 0.0,
            "failure_reason": "white_agent_url is required for real OSWorld mode",
            "artifacts": {}
        }

    # Prepare result directory
    base_artifacts = artifacts_dir or os.path.join("runs", str(uuid.uuid4()))
    os.makedirs(base_artifacts, exist_ok=True)
    result_dir = os.path.join(base_artifacts, OSWORLD_RESULT_SUBDIR)
    os.makedirs(result_dir, exist_ok=True)

    log_path = os.path.join(result_dir, "osworld.log")
    t0 = time.time()

    try:
        # Convert task format
        osworld_task = convert_to_osworld_format(task)
        max_steps = extract_max_steps(task, OSWORLD_MAX_STEPS)

        # Create White Agent bridge
        agent = WhiteAgentBridge(
            white_agent_url=white_agent_url,
            action_space="pyautogui",
            platform="ubuntu"
        )

        # Create OSWorld environment
        env = DesktopEnv(
            provider_name=OSWORLD_PROVIDER,
            path_to_vm=None,
            action_space="pyautogui",
            screen_size=(W, H),
            headless=OSWORLD_HEADLESS,
            os_type="Ubuntu",
            require_a11y_tree=(OSWORLD_OBS_TYPE in ["a11y_tree", "screenshot_a11y_tree"])
        )

        # Create args namespace (OSWorld expects this)
        class Args:
            sleep_after_execution = OSWORLD_SLEEP_AFTER_EXEC

        args = Args()

        # Run single assessment
        scores = []

        # Log to file
        with open(log_path, "w") as log_f:
            log_f.write(f"==== OSWorld start ====: {time.ctime()}\n")
            log_f.write(f"Task: {osworld_task['id']}\n")
            log_f.write(f"Instruction: {osworld_task['instruction']}\n")
            log_f.write(f"White Agent URL: {white_agent_url}\n")
            log_f.write(f"Max steps: {max_steps}\n")
            log_f.write(f"Provider: {OSWORLD_PROVIDER}\n\n")

        lib_run_single.run_single_example(
            agent=agent,
            env=env,
            example=osworld_task,
            max_steps=max_steps,
            instruction=osworld_task["instruction"],
            args=args,
            example_result_dir=result_dir,
            scores=scores
        )

        # Clean up environment
        env.close()

        # Parse results
        dt = time.time() - t0
        steps = _count_screenshots(result_dir)
        success = int(scores[0]) if scores else 0

        return {
            "success": success,
            "steps": steps,
            "time_sec": round(dt, 3),
            "failure_reason": None if success else "task_failed",
            "artifacts": {"result_dir": result_dir}
        }

    except Exception as e:
        dt = time.time() - t0
        error_msg = f"OSWorld execution error: {type(e).__name__}: {str(e)}"

        # Get full traceback
        import traceback
        full_traceback = traceback.format_exc()

        # Log error with full traceback
        try:
            with open(log_path, "a") as log_f:
                log_f.write(f"\n==== ERROR ====\n{error_msg}\n\n")
                log_f.write(f"Full traceback:\n{full_traceback}\n")
        except Exception:
            pass

        return {
            "success": 0,
            "steps": _count_screenshots(result_dir),
            "time_sec": round(dt, 3),
            "failure_reason": error_msg,
            "artifacts": {"result_dir": result_dir}
        }
