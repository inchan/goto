#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import json
import subprocess
import sys
from datetime import datetime, timezone


def _run(repo: Path, args: list[str]) -> str:
    try:
        return subprocess.check_output(args, cwd=repo, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def _run_status(repo: Path, args: list[str]) -> tuple[int, str]:
    try:
        completed = subprocess.run(args, cwd=repo, text=True, capture_output=True, check=False)
        return completed.returncode, completed.stdout.strip()
    except Exception:
        return 127, ""


def _exists_any(repo: Path, paths: list[str]) -> bool:
    return any((repo / path).exists() for path in paths)


def _glob_any(repo: Path, patterns: list[str]) -> bool:
    return any(any(repo.glob(pattern)) for pattern in patterns)


def detect_tests(repo: Path) -> bool:
    if _glob_any(repo, ["product/cli/test/*.test.js", "product/core/Tests/**/*.swift", "tests/**/*", "test/**/*"]):
        return True
    readme = repo / "README.md"
    if readme.exists() and any(token in readme.read_text(errors="ignore") for token in ["node --test", "scripts/test-native.sh", "swift test"]):
        return True
    return False


def _load_plan(repo: Path):
    path = repo / ".hermes" / "plan.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except Exception:
        return {"_invalid": True}


def build_snapshot(repo: Path | str = Path(".")) -> dict:
    repo = Path(repo).resolve()
    branch_code, branch = _run_status(repo, ["git", "branch", "--show-current"])
    status_code, status = _run_status(repo, ["git", "status", "--short", "--branch"])
    porcelain_code, porcelain = _run_status(repo, ["git", "status", "--porcelain"])
    branch = branch or "unknown"
    git_dir = repo / ".git"
    git_health = {
        "is_git_repo": git_dir.exists() and status_code == 0,
        "branch_known": branch_code == 0 and branch != "unknown",
        "status_known": status_code == 0,
        "porcelain_known": porcelain_code == 0,
    }
    dirty_paths = [line[3:] if len(line) > 3 else line for line in porcelain.splitlines() if line.strip()]
    tests = detect_tests(repo)
    plan = _load_plan(repo)
    inconsistencies: list[dict] = []
    if isinstance(plan, dict):
        plan_tests = plan.get("signals", {}).get("tests")
        if plan_tests is False and tests:
            inconsistencies.append({
                "code": "plan_tests_signal_false_but_tests_detected",
                "severity": "critical",
                "artifact": ".hermes/plan.json",
                "message": ".hermes/plan.json reports signals.tests=false, but repo tests are detected",
            })
        if plan.get("_invalid"):
            inconsistencies.append({
                "code": "plan_json_invalid",
                "severity": "critical",
                "artifact": ".hermes/plan.json",
                "message": ".hermes/plan.json is not valid JSON",
            })

    snapshot = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repo": str(repo),
        "branch": branch,
        "git_status_summary": status,
        "git_health": git_health,
        "dirty_worktree": bool(dirty_paths),
        "dirty_paths": dirty_paths,
        "signals": {
            "guidance": _exists_any(repo, ["AGENTS.md", "CLAUDE.md", ".cursorrules"]),
            "agent_cfg": (repo / ".hermes").exists(),
            "tests": tests,
            "docs": _exists_any(repo, ["README.md", "docs"]),
            "code_dirs": _exists_any(repo, ["src", "app", "lib", "product"]),
            "git": (repo / ".git").exists(),
        },
        "product_surfaces": {
            "cli": (repo / "product" / "cli").exists(),
            "macos_app": (repo / "product" / "macos" / "Goto").exists(),
            "finder_sync": (repo / "product" / "macos" / "GotoFinderSync").exists(),
        },
        "verification_commands": [
            command for command in [
                "node --test product/cli/test/*.test.js" if (repo / "product" / "cli" / "test").exists() else None,
                "scripts/test-native.sh" if (repo / "scripts" / "test-native.sh").exists() else None,
                "scripts/typecheck-native.sh" if (repo / "scripts" / "typecheck-native.sh").exists() else None,
                "scripts/verify.sh" if (repo / "scripts" / "verify.sh").exists() else None,
            ] if command
        ],
        "plan_signals": plan.get("signals", {}) if isinstance(plan, dict) else {},
        "detected_inconsistencies": inconsistencies,
    }
    return snapshot


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    repo = Path(argv[0]) if argv else Path(".")
    snapshot = build_snapshot(repo)
    out = repo / ".hermes" / "state" / "project-snapshot.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(snapshot, indent=2) + "\n")
    print(str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
