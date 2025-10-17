"""
Task Format Converter

Converts between Green Agent task format and OSWorld task format.
"""

from typing import Dict, Any


def convert_to_osworld_format(green_task: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert Green Agent task format to OSWorld format.

    Green Agent format:
    {
        "task_id": "ubuntu_001",
        "environment": "OSWorld:Ubuntu:22.04",
        "goal": "Open Writer, type 'Hello OSWorld', and save a PDF to Desktop.",
        "constraints": {"max_steps": 80, "max_time_sec": 480},
        "hints": ["The Writer icon is in the dock.", ...]
    }

    OSWorld format:
    {
        "id": "ubuntu_001",
        "instruction": "Open Writer, type 'Hello OSWorld', and save a PDF to Desktop.",
        "config": [...setup actions...],
        "evaluator": {
            "func": "evaluator_func_name",
            "result": {...}
        }
    }

    Args:
        green_task: Task in Green Agent format

    Returns:
        Task in OSWorld format
    """
    return {
        "id": green_task.get("task_id", "unknown_task"),
        "instruction": green_task.get("goal", ""),

        # Config: setup actions to run before the task starts
        # For now, we use empty config (environment starts fresh)
        "config": [],

        # Evaluator: defines how to check if task succeeded
        # For MVP, we use a simple "always pass" evaluator
        # In production, this would check file existence, content, etc.
        "evaluator": {
            "func": "evaluator_basic",
            "result": {
                "type": "basic",
                # OSWorld will determine success based on agent returning "DONE"
            }
        },

        # Preserve original metadata for debugging
        "green_agent_metadata": {
            "environment": green_task.get("environment"),
            "constraints": green_task.get("constraints", {}),
            "hints": green_task.get("hints", [])
        }
    }


def extract_max_steps(green_task: Dict[str, Any], default: int = 15) -> int:
    """
    Extract max_steps from Green Agent task constraints.

    Args:
        green_task: Task in Green Agent format
        default: Default value if not specified

    Returns:
        Maximum number of steps
    """
    constraints = green_task.get("constraints", {})
    return constraints.get("max_steps", default)


def extract_max_time(green_task: Dict[str, Any], default: int = 600) -> int:
    """
    Extract max_time_sec from Green Agent task constraints.

    Args:
        green_task: Task in Green Agent format
        default: Default value if not specified

    Returns:
        Maximum time in seconds
    """
    constraints = green_task.get("constraints", {})
    return constraints.get("max_time_sec", default)
