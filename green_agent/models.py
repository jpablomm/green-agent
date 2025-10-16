from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional


class TaskBrief(BaseModel):
    task_id: str
    environment: str
    goal: str
    tools: List[Dict[str, Any]] = Field(default_factory=list)
    constraints: Dict[str, Any] = Field(default_factory=dict)
    observation_schema: Dict[str, Any] = Field(default_factory=dict)
    action_schema: Dict[str, Any] = Field(default_factory=dict)


class StartAssessmentRequest(BaseModel):
    task_id: str
    white_agent_url: str


class Observation(BaseModel):
    frame_id: int
    image_png_b64: str
    ui_hint: Optional[str] = None
    done: bool = False


class Action(BaseModel):
    op: str
    args: Dict[str, Any] = Field(default_factory=dict)


class AssessmentStatus(BaseModel):
    assessment_id: str
    status: str
    progress: float = 0.0
    last_step: int = 0


class RunMetrics(BaseModel):
    assessment_id: str
    task_id: str
    white_agent: str
    success: int
    steps: int
    time_sec: float
    failure_reason: Optional[str] = None
    artifacts_dir: str
