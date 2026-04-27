#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import json
import sys
from datetime import datetime, timezone

try:
    from scripts.snapshot_project import build_snapshot
except ModuleNotFoundError:
    from snapshot_project import build_snapshot


def generate_drift_report(repo: Path | str = Path(".")) -> dict:
    repo = Path(repo).resolve()
    snapshot = build_snapshot(repo)
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo": str(repo),
        "drift": snapshot.get("detected_inconsistencies", []),
        "summary": {
            "count": len(snapshot.get("detected_inconsistencies", [])),
            "critical": sum(1 for item in snapshot.get("detected_inconsistencies", []) if item.get("severity") == "critical"),
        },
    }


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    repo = Path(argv[0]) if argv else Path(".")
    report = generate_drift_report(repo)
    out = repo / ".hermes" / "derived" / "harness-drift-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2) + "\n")
    print(str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
