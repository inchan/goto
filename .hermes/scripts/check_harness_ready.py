#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import json
import re
import sys

try:
    from scripts.snapshot_project import build_snapshot
    from scripts.validate_harness import validate_harness
except ModuleNotFoundError:
    from snapshot_project import build_snapshot
    from validate_harness import validate_harness


@dataclass
class ReadinessResult:
    exit_code: int
    mode: str
    issues: list[dict]

    @property
    def allowed(self) -> bool:
        return self.exit_code == 0


ALLOWED_MODES = {"observe", "plan", "verify", "review", "execute"}
ALLOWED_EXECUTE_BRANCH_PREFIXES = ("hermes/", "feature/", "chore/", "fix/")

ACTION_RULES = [
    ("user_or_system_side_effect", ["~/.goto", "shell rc", "~/applications", "/applications", "launchctl", "pluginkit", "pkill finder", "sudo", "finder sync", "install-app", "goto.app"]),
    ("scheduler_side_effect", ["cronjob", "cron job", "scheduled job", "recurring cron", "every hour", "every day"]),
    ("repo_write", ["modify product/", "edit product/", "write product/", "change product/", "patch product/", "modify scripts/", "edit scripts/", "write scripts/", "change scripts/", "patch scripts/", "implement feature", "fix bug", "write .hermes", "edit .hermes", "modify .hermes", "update .hermes", "patch .hermes", "project-local .hermes", "harness artifacts", "add harness"]),
]
READ_ONLY_ACTION_TERMS = ["read", "inspect", "review", "observe", "list", "search", "check", "summarize"]


def _normalise_action(text: str) -> str:
    return re.sub(r"\s+", " ", text.casefold()).strip()


def _matched_terms(text: str, terms: list[str]) -> list[str]:
    return [term for term in terms if term in text]


def classify_action(description: str | None) -> dict:
    raw = description or "observe harness status"
    text = _normalise_action(raw)

    for classification, terms in ACTION_RULES:
        matches = _matched_terms(text, terms)
        if matches:
            manual_gate = classification in {"user_or_system_side_effect", "scheduler_side_effect"}
            return {
                "description": raw,
                "classification": classification,
                "matched_terms": matches,
                "requires_manual_gate": manual_gate,
                "allowed_in_observe": False,
                "allowed_in_execute": not manual_gate,
                "reason": "matched deterministic action gate rule",
            }

    read_matches = _matched_terms(text, READ_ONLY_ACTION_TERMS)
    if read_matches:
        return {
            "description": raw,
            "classification": "read_only",
            "matched_terms": read_matches,
            "requires_manual_gate": False,
            "allowed_in_observe": True,
            "allowed_in_execute": True,
            "reason": "read-only action terms detected",
        }

    return {
        "description": raw,
        "classification": "unknown_action",
        "matched_terms": [],
        "requires_manual_gate": True,
        "allowed_in_observe": False,
        "allowed_in_execute": False,
        "reason": "no deterministic action gate rule matched; fail closed",
    }


def readiness_status_path(repo: Path | str, mode: str) -> Path:
    repo = Path(repo).resolve()
    safe_mode = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "-" for ch in mode)
    return repo / ".hermes" / "derived" / f"readiness-{safe_mode}.json"


def evaluate_readiness(repo: Path | str = Path("."), mode: str = "execute") -> ReadinessResult:
    repo = Path(repo).resolve()
    issues: list[dict] = []

    if mode not in ALLOWED_MODES:
        return ReadinessResult(
            exit_code=20,
            mode=mode,
            issues=[{
                "code": "unknown_readiness_mode",
                "severity": "critical",
                "message": f"Unknown readiness mode {mode!r}; allowed modes are {sorted(ALLOWED_MODES)}",
            }],
        )

    validation = validate_harness(repo / ".hermes")
    snapshot = build_snapshot(repo)

    if validation.errors:
        issues.append({
            "code": "harness_invalid",
            "severity": "critical",
            "message": "; ".join(validation.errors[:3]),
        })

    critical_drift = [item for item in snapshot.get("detected_inconsistencies", []) if item.get("severity") == "critical"]
    if critical_drift:
        issues.append({
            "code": "critical_harness_drift",
            "severity": "critical",
            "message": f"{len(critical_drift)} critical drift item(s) detected",
        })

    if mode == "execute":
        git_health = snapshot.get("git_health", {})
        branch = snapshot.get("branch")
        if not git_health.get("is_git_repo") or not git_health.get("branch_known"):
            issues.append({
                "code": "git_context_unknown_blocks_execution",
                "severity": "blocker",
                "message": "Execution mode requires a known git repository and branch",
            })
        elif branch == "main":
            issues.append({
                "code": "branch_main_blocks_execution",
                "severity": "blocker",
                "message": "Execution mode is blocked on main branch",
            })
        elif not str(branch).startswith(ALLOWED_EXECUTE_BRANCH_PREFIXES):
            issues.append({
                "code": "branch_not_allowlisted_blocks_execution",
                "severity": "blocker",
                "message": f"Execution mode requires branch prefix {ALLOWED_EXECUTE_BRANCH_PREFIXES}; got {branch!r}",
            })
        if snapshot.get("dirty_worktree"):
            issues.append({
                "code": "dirty_worktree_blocks_execution",
                "severity": "blocker",
                "message": "Execution mode requires a clean working tree before autonomous changes",
            })

    if any(item.get("code") == "harness_invalid" for item in issues):
        exit_code = 20
    elif mode == "execute" and issues:
        exit_code = 10
    elif mode in {"observe", "plan", "verify", "review"} and any(item.get("severity") == "critical" for item in issues):
        exit_code = 10
    else:
        exit_code = 0

    return ReadinessResult(exit_code=exit_code, mode=mode, issues=issues)


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    mode = "execute"
    repo = Path(".")
    if argv:
        mode = argv[0]
    if len(argv) > 1:
        repo = Path(argv[1])
    result = evaluate_readiness(repo, mode=mode)
    out = readiness_status_path(repo, result.mode)
    out.parent.mkdir(parents=True, exist_ok=True)
    status_payload = {"mode": result.mode, "exit_code": result.exit_code, "issues": result.issues}
    out.write_text(json.dumps(status_payload, indent=2) + "\n")
    legacy_out = repo / ".hermes" / "derived" / "current-status.json"
    legacy_out.write_text(json.dumps(status_payload, indent=2) + "\n")
    if result.exit_code == 0:
        print(f"PASS mode={result.mode}")
    else:
        print(f"BLOCKED mode={result.mode} exit_code={result.exit_code}")
        for issue in result.issues:
            print(f"{issue['severity']} {issue['code']}: {issue['message']}")
    return result.exit_code


if __name__ == "__main__":
    raise SystemExit(main())
