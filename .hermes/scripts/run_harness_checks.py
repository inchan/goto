#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import fnmatch
import json
import subprocess
import sys
from datetime import datetime, timezone

try:
    from scripts.check_harness_ready import classify_action, evaluate_readiness
    from scripts.generate_harness_drift_report import generate_drift_report
    from scripts.snapshot_project import build_snapshot
    from scripts.validate_harness import validate_harness
except ModuleNotFoundError:
    from check_harness_ready import classify_action, evaluate_readiness
    from generate_harness_drift_report import generate_drift_report
    from snapshot_project import build_snapshot
    from validate_harness import validate_harness


def _status_from_exit(exit_code: int) -> str:
    if exit_code == 0:
        return "pass"
    if exit_code == 10:
        return "blocked"
    return "fail"


def _operating_state(observe_status: str, execute_status: str) -> str:
    if observe_status == "pass" and execute_status == "pass":
        return "execute_ready"
    if observe_status == "pass" and execute_status == "blocked":
        return "stable_observe_only"
    if observe_status == "blocked":
        return "observe_blocked"
    return "harness_unstable"


def _safe_next_action(execute_status: str, preflight: dict) -> str:
    if execute_status != "pass":
        return "observe_or_review_only"
    if preflight.get("requires_manual_gate") or not preflight.get("allowed_in_execute"):
        return "manual_gate_required"
    return "execute_allowed_by_harness"


def _lane_report(validation, lane: str | None) -> dict:
    if lane is None:
        lane_id = "operations"
    else:
        lane_id = lane.strip()
    lanes = {item.get("id"): item for item in validation.operating_lanes if isinstance(item, dict)}
    if not lane_id:
        return {
            "status": "invalid",
            "id": lane,
            "name": None,
            "workflow": None,
            "allowed_paths": [],
            "forbidden_paths": [],
            "issues": [{
                "code": "empty_operating_lane",
                "severity": "critical",
                "message": "Operating lane must be a non-empty lane id",
            }],
        }
    selected = lanes.get(lane_id)
    if selected:
        return {
            "status": "selected",
            "id": lane_id,
            "name": selected.get("name"),
            "workflow": selected.get("workflow"),
            "allowed_paths": selected.get("allowed_paths", []),
            "forbidden_paths": selected.get("forbidden_paths", []),
            "issues": [],
        }
    return {
        "status": "invalid",
        "id": lane_id,
        "name": None,
        "workflow": None,
        "allowed_paths": [],
        "forbidden_paths": [],
        "issues": [{
            "code": "unknown_operating_lane",
            "severity": "critical",
            "message": f"Unknown operating lane {lane_id!r}; allowed lanes are {sorted(lanes)}",
        }],
    }


def _changed_files(repo: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return []
    if result.returncode != 0:
        return []
    files: list[str] = []
    for line in result.stdout.splitlines():
        if not line:
            continue
        path = line[3:]
        if " -> " in path:
            old_path, new_path = path.split(" -> ", 1)
            files.append(old_path)
            files.append(new_path)
        else:
            files.append(path)
    return sorted(set(files))


def _matches_path(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)


def _boundary_report(repo: Path, lane_selection: dict) -> dict:
    changed = _changed_files(repo)
    allowed = lane_selection.get("allowed_paths") or []
    forbidden = lane_selection.get("forbidden_paths") or []
    issues = []
    if lane_selection.get("status") != "selected":
        return {
            "status": "not_evaluated",
            "changed_files": changed,
            "allowed_paths": allowed,
            "forbidden_paths": forbidden,
            "issues": [],
        }
    for path in changed:
        if _matches_path(path, forbidden):
            issues.append({
                "code": "lane_path_forbidden",
                "severity": "critical",
                "path": path,
                "message": f"{path} is forbidden for lane {lane_selection.get('id')}",
            })
        elif allowed and not _matches_path(path, allowed):
            issues.append({
                "code": "lane_path_not_allowed",
                "severity": "critical",
                "path": path,
                "message": f"{path} is outside allowed paths for lane {lane_selection.get('id')}",
            })
    return {
        "status": "blocked" if issues else "pass",
        "changed_files": changed,
        "allowed_paths": allowed,
        "forbidden_paths": forbidden,
        "issues": issues,
    }


def run_harness_checks(repo: Path | str = Path("."), action_description: str | None = None, lane: str | None = None) -> dict:
    repo = Path(repo).resolve()
    validation = validate_harness(repo / ".hermes")
    snapshot = build_snapshot(repo)
    drift = generate_drift_report(repo)
    observe = evaluate_readiness(repo, mode="observe")
    execute = evaluate_readiness(repo, mode="execute")
    preflight = classify_action(action_description or "observe harness status")
    lane_selection = _lane_report(validation, lane)
    lane_selection["boundary"] = _boundary_report(repo, lane_selection)

    validate_status = "pass" if validation.ok else "fail"
    drift_status = "pass" if drift.get("summary", {}).get("critical", 0) == 0 else "fail"
    observe_status = _status_from_exit(observe.exit_code)
    execute_status = _status_from_exit(execute.exit_code)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo": str(repo),
        "steps": {
            "validate_harness": {
                "status": validate_status,
                "validated_examples": validation.validated_examples,
                "errors": validation.errors,
            },
            "snapshot_project": {
                "status": "pass",
                "branch": snapshot.get("branch"),
                "signals": snapshot.get("signals", {}),
                "product_surfaces": snapshot.get("product_surfaces", {}),
            },
            "drift_report": {
                "status": drift_status,
                "summary": drift.get("summary", {}),
                "drift": drift.get("drift", []),
            },
        },
        "readiness": {
            "observe": {
                "status": observe_status,
                "exit_code": observe.exit_code,
                "issues": observe.issues,
            },
            "execute": {
                "status": execute_status,
                "exit_code": execute.exit_code,
                "issues": execute.issues,
            },
        },
        "lane": lane_selection,
        "preflight": preflight,
        "summary": {
            "operating_state": _operating_state(observe_status, execute_status),
            "safe_next_action": _safe_next_action(execute_status, preflight),
            "lane": lane_selection.get("id"),
        },
    }


def aggregate_exit_code(report: dict, require: str = "observe") -> int:
    if require not in {"observe", "execute"}:
        return 20
    if report.get("lane", {}).get("status") == "invalid":
        return 20
    if report.get("lane", {}).get("boundary", {}).get("status") == "blocked":
        return 10
    if report["steps"]["validate_harness"]["status"] == "fail":
        return 20
    if report["steps"]["drift_report"]["status"] == "fail":
        return 10
    observe = report["readiness"]["observe"]
    execute = report["readiness"]["execute"]
    if observe["status"] != "pass":
        return observe["exit_code"] or 10
    if require == "execute" and execute["status"] != "pass":
        return execute["exit_code"] or 10
    if require == "execute":
        preflight = report.get("preflight", {})
        if preflight.get("requires_manual_gate") or not preflight.get("allowed_in_execute"):
            return 10
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    require = "observe"
    action_description = None
    lane = None
    paths = []
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--require-observe":
            require = "observe"
        elif arg == "--require-execute":
            require = "execute"
        elif arg == "--action":
            if index + 1 >= len(argv):
                print("ERROR --action requires a description", file=sys.stderr)
                return 20
            action_description = argv[index + 1]
            index += 1
        elif arg == "--lane":
            if index + 1 >= len(argv):
                print("ERROR --lane requires an operating lane id", file=sys.stderr)
                return 20
            lane = argv[index + 1]
            index += 1
        else:
            paths.append(arg)
        index += 1
    repo = Path(paths[0]) if paths else Path(".")
    report = run_harness_checks(repo, action_description=action_description, lane=lane)
    out = repo / ".hermes" / "derived" / "harness-check-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(str(out))
    print(f"operating_state={report['summary']['operating_state']}")
    print(f"lane={report['summary']['lane']} status={report['lane']['status']}")
    observe = report["readiness"]["observe"]
    execute = report["readiness"]["execute"]
    print(f"observe={observe['status']} exit_code={observe['exit_code']}")
    print(f"execute={execute['status']} exit_code={execute['exit_code']}")
    print(f"require={require}")
    return aggregate_exit_code(report, require=require)


if __name__ == "__main__":
    raise SystemExit(main())
