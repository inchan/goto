#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import json
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


def run_harness_checks(repo: Path | str = Path("."), action_description: str | None = None) -> dict:
    repo = Path(repo).resolve()
    validation = validate_harness(repo / ".hermes")
    snapshot = build_snapshot(repo)
    drift = generate_drift_report(repo)
    observe = evaluate_readiness(repo, mode="observe")
    execute = evaluate_readiness(repo, mode="execute")
    preflight = classify_action(action_description or "observe harness status")

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
        "preflight": preflight,
        "summary": {
            "operating_state": _operating_state(observe_status, execute_status),
            "safe_next_action": _safe_next_action(execute_status, preflight),
        },
    }


def aggregate_exit_code(report: dict, require: str = "observe") -> int:
    if require not in {"observe", "execute"}:
        return 20
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
        else:
            paths.append(arg)
        index += 1
    repo = Path(paths[0]) if paths else Path(".")
    report = run_harness_checks(repo, action_description=action_description)
    out = repo / ".hermes" / "derived" / "harness-check-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(str(out))
    print(f"operating_state={report['summary']['operating_state']}")
    observe = report["readiness"]["observe"]
    execute = report["readiness"]["execute"]
    print(f"observe={observe['status']} exit_code={observe['exit_code']}")
    print(f"execute={execute['status']} exit_code={execute['exit_code']}")
    print(f"require={require}")
    return aggregate_exit_code(report, require=require)


if __name__ == "__main__":
    raise SystemExit(main())
