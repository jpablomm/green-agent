import os, sqlite3, json, pathlib, time
from typing import Optional, Dict, Any

DB_PATH = os.environ.get("RUNS_DB", "runs.db")
RUNS_DIR = os.environ.get("RUNS_DIR", "runs")
pathlib.Path(RUNS_DIR).mkdir(parents=True, exist_ok=True)

SCHEMA = {
    "runs": (
        "CREATE TABLE IF NOT EXISTS runs ("
        "assessment_id TEXT PRIMARY KEY,"
        "task_id TEXT,"
        "white_agent TEXT,"
        "status TEXT,"
        "success INTEGER,"
        "steps INTEGER,"
        "time_sec REAL,"
        "failure_reason TEXT,"
        "artifacts_dir TEXT,"
        "created_at REAL)"
    ),
    "actions": (
        "CREATE TABLE IF NOT EXISTS actions ("
        "assessment_id TEXT,"
        "step INTEGER,"
        "op TEXT,"
        "args TEXT,"
        "ok INTEGER,"
        "ts REAL)"
    ),
}


def _conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# init
with _conn() as c:
    for ddl in SCHEMA.values():
        c.execute(ddl)


def create_run(assessment_id: str, task_id: str, white_agent: str) -> str:
    artifacts = os.path.join(RUNS_DIR, assessment_id)
    os.makedirs(artifacts, exist_ok=True)
    with _conn() as c:
        c.execute(
            "INSERT OR REPLACE INTO runs(assessment_id, task_id, white_agent, status, success, steps, time_sec, failure_reason, artifacts_dir, created_at)"
            " VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                assessment_id,
                task_id,
                white_agent,
                "running",
                None,
                None,
                None,
                None,
                artifacts,
                time.time(),
            ),
        )
    return artifacts


def update_status(assessment_id: str, status: str, **fields):
    sets = ["status = ?"]
    vals = [status]
    for k, v in fields.items():
        sets.append(f"{k} = ?")
        vals.append(v)
    vals.append(assessment_id)
    with _conn() as c:
        c.execute(f"UPDATE runs SET {', '.join(sets)} WHERE assessment_id = ?", vals)


def record_action(
    assessment_id: str, step: int, op: str, args: Dict[str, Any], ok: int
):
    with _conn() as c:
        c.execute(
            "INSERT INTO actions(assessment_id, step, op, args, ok, ts) VALUES(?,?,?,?,?,?)",
            (assessment_id, step, op, json.dumps(args), ok, time.time()),
        )


def fetch_run(assessment_id: str) -> Optional[Dict[str, Any]]:
    with _conn() as c:
        row = c.execute(
            "SELECT * FROM runs WHERE assessment_id = ?", (assessment_id,)
        ).fetchone()
        return dict(row) if row else None
