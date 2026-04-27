import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.repo = Path(__file__).resolve().parents[2]

    def _temp_repo_with_bad_plan(self):
        temp = tempfile.TemporaryDirectory()
        repo = Path(temp.name)
        (repo / ".hermes").mkdir()
        (repo / ".hermes" / "plan.json").write_text(json.dumps({"signals": {"tests": False}}))
        (repo / "README.md").write_text("Run tests with `node --test product/cli/test/*.test.js`.\n")
        return temp, repo

    def _temp_repo_with_valid_harness(self, git: bool = False, branch: str | None = None):
        temp = tempfile.TemporaryDirectory()
        repo = Path(temp.name)
        shutil.copytree(
            self.repo / ".hermes",
            repo / ".hermes",
            ignore=shutil.ignore_patterns("derived", "state", "__pycache__", "*.pyc"),
        )
        (repo / "README.md").write_text("Temporary harness fixture.\n")
        if git:
            subprocess.run(["git", "init"], cwd=repo, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "config", "user.email", "harness@example.invalid"], cwd=repo, check=True)
            subprocess.run(["git", "config", "user.name", "Harness Test"], cwd=repo, check=True)
            if branch:
                subprocess.run(["git", "checkout", "-b", branch], cwd=repo, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "add", "."], cwd=repo, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["git", "commit", "-m", "seed harness fixture"], cwd=repo, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return temp, repo

    def test_validate_harness_accepts_committed_schema_examples(self):
        from scripts.validate_harness import validate_harness

        result = validate_harness(self.repo / ".hermes")

        self.assertEqual([], result.errors)
        self.assertGreaterEqual(result.validated_examples, 4)

    def test_validate_harness_requires_separate_operating_lanes(self):
        from scripts.validate_harness import validate_harness

        result = validate_harness(self.repo / ".hermes")

        self.assertEqual([], result.errors)
        lanes = result.operating_lanes
        self.assertEqual(
            {"self_improvement", "project_drift", "operations"},
            {lane["id"] for lane in lanes},
        )
        expected_workflows = {
            "self_improvement": "workflows/self-improvement.md",
            "project_drift": "workflows/project-drift.md",
            "operations": "workflows/operations.md",
        }
        for lane in lanes:
            self.assertEqual(expected_workflows[lane["id"]], lane["workflow"])
            workflow_path = self.repo / ".hermes" / lane["workflow"]
            self.assertTrue(workflow_path.exists(), lane["workflow"])

    def test_snapshot_detects_tests_in_live_repo(self):
        from scripts.snapshot_project import build_snapshot

        snapshot = build_snapshot(self.repo)

        self.assertTrue(snapshot["signals"]["tests"])

    def test_snapshot_detects_plan_drift_in_fixture(self):
        from scripts.snapshot_project import build_snapshot

        temp, repo = self._temp_repo_with_bad_plan()
        with temp:
            snapshot = build_snapshot(repo)

        drift_codes = {item["code"] for item in snapshot["detected_inconsistencies"]}
        self.assertIn("plan_tests_signal_false_but_tests_detected", drift_codes)

    def test_harness_ready_blocks_execution_on_main_branch(self):
        from scripts.check_harness_ready import evaluate_readiness

        temp, repo = self._temp_repo_with_valid_harness(git=True, branch="main")
        with temp:
            result = evaluate_readiness(repo, mode="execute")

        self.assertIn(result.exit_code, {10, 20})
        codes = {item["code"] for item in result.issues}
        self.assertIn("branch_main_blocks_execution", codes)

    def test_harness_ready_allows_observe_when_harness_valid(self):
        from scripts.check_harness_ready import evaluate_readiness

        result = evaluate_readiness(self.repo, mode="observe")

        self.assertEqual(0, result.exit_code)
        self.assertNotIn("harness_invalid", {item["code"] for item in result.issues})

    def test_drift_report_names_plan_json_tests_signal_in_fixture(self):
        from scripts.generate_harness_drift_report import generate_drift_report

        temp, repo = self._temp_repo_with_bad_plan()
        with temp:
            report = generate_drift_report(repo)

        codes = {item["code"] for item in report["drift"]}
        self.assertIn("plan_tests_signal_false_but_tests_detected", codes)
        self.assertTrue(any(".hermes/plan.json" in item["artifact"] for item in report["drift"]))

    def test_readiness_status_paths_are_mode_specific(self):
        from scripts.check_harness_ready import readiness_status_path

        self.assertEqual(
            self.repo / ".hermes" / "derived" / "readiness-observe.json",
            readiness_status_path(self.repo, "observe"),
        )
        self.assertEqual(
            self.repo / ".hermes" / "derived" / "readiness-execute.json",
            readiness_status_path(self.repo, "execute"),
        )

    def test_aggregate_checks_report_observe_pass_and_execute_blocked_on_main(self):
        from scripts.run_harness_checks import aggregate_exit_code, run_harness_checks

        temp, repo = self._temp_repo_with_valid_harness(git=True, branch="main")
        with temp:
            report = run_harness_checks(repo)

        self.assertEqual("pass", report["steps"]["validate_harness"]["status"])
        self.assertEqual("pass", report["steps"]["drift_report"]["status"])
        self.assertEqual("pass", report["readiness"]["observe"]["status"])
        self.assertEqual("blocked", report["readiness"]["execute"]["status"])
        self.assertIn(
            "branch_main_blocks_execution",
            {issue["code"] for issue in report["readiness"]["execute"]["issues"]},
        )
        self.assertEqual("stable_observe_only", report["summary"]["operating_state"])
        self.assertEqual(0, aggregate_exit_code(report, require="observe"))
        self.assertEqual(10, aggregate_exit_code(report, require="execute"))

    def test_unknown_readiness_mode_is_blocked(self):
        from scripts.check_harness_ready import evaluate_readiness

        result = evaluate_readiness(self.repo, mode="exectue")

        self.assertEqual(20, result.exit_code)
        self.assertIn("unknown_readiness_mode", {issue["code"] for issue in result.issues})

    def test_execute_blocks_when_git_context_is_unknown(self):
        from scripts.check_harness_ready import evaluate_readiness

        temp, repo = self._temp_repo_with_valid_harness(git=False)
        with temp:
            result = evaluate_readiness(repo, mode="execute")

        self.assertEqual(10, result.exit_code)
        self.assertIn("git_context_unknown_blocks_execution", {issue["code"] for issue in result.issues})

    def test_execute_blocks_dirty_worktree_on_allowed_branch(self):
        from scripts.check_harness_ready import evaluate_readiness

        temp, repo = self._temp_repo_with_valid_harness(git=True, branch="hermes/test")
        with temp:
            (repo / "product-change.txt").write_text("untracked product change\n")
            result = evaluate_readiness(repo, mode="execute")

        self.assertEqual(10, result.exit_code)
        self.assertIn("dirty_worktree_blocks_execution", {issue["code"] for issue in result.issues})

    def test_preflight_classifies_read_only_as_allowed(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("read README.md and inspect product/cli/src/index.js")

        self.assertEqual("read_only", result["classification"])
        self.assertTrue(result["allowed_in_observe"])
        self.assertFalse(result["requires_manual_gate"])

    def test_preflight_classifies_project_local_harness_updates_as_repo_write(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("update project-local .hermes harness artifacts")

        self.assertEqual("repo_write", result["classification"])
        self.assertFalse(result["allowed_in_observe"])
        self.assertTrue(result["allowed_in_execute"])
        self.assertFalse(result["requires_manual_gate"])
        self.assertIn("project-local .hermes", result["matched_terms"])

    def test_preflight_prefers_repo_write_for_modify_scripts_even_when_check_term_present(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("modify scripts/verify.sh to run .hermes harness checks")

        self.assertEqual("repo_write", result["classification"])
        self.assertFalse(result["allowed_in_observe"])
        self.assertTrue(result["allowed_in_execute"])
        self.assertIn("modify scripts/", result["matched_terms"])

    def test_preflight_classifies_lane_separation_as_repo_write(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("separate self-improvement project drift and operations lanes")

        self.assertEqual("repo_write", result["classification"])
        self.assertFalse(result["allowed_in_observe"])
        self.assertTrue(result["allowed_in_execute"])
        self.assertIn("separate self-improvement", result["matched_terms"])

    def test_preflight_blocks_user_or_system_side_effects(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("run pluginkit and pkill Finder after installing Goto.app to /Applications")

        self.assertEqual("user_or_system_side_effect", result["classification"])
        self.assertFalse(result["allowed_in_execute"])
        self.assertTrue(result["requires_manual_gate"])
        self.assertIn("pluginkit", result["matched_terms"])

    def test_preflight_classifies_cron_creation_as_side_effect(self):
        from scripts.check_harness_ready import classify_action

        result = classify_action("create a recurring cron job to run observer every hour")

        self.assertEqual("scheduler_side_effect", result["classification"])
        self.assertFalse(result["allowed_in_execute"])
        self.assertTrue(result["requires_manual_gate"])

    def test_aggregate_report_includes_default_preflight_policy(self):
        from scripts.run_harness_checks import run_harness_checks

        report = run_harness_checks(self.repo)

        self.assertEqual("read_only", report["preflight"]["classification"])
        self.assertTrue(report["preflight"]["allowed_in_observe"])

    def test_aggregate_report_records_selected_operating_lane(self):
        from scripts.run_harness_checks import run_harness_checks

        report = run_harness_checks(self.repo, lane="project_drift")

        self.assertEqual("project_drift", report["lane"]["id"])
        self.assertEqual("workflows/project-drift.md", report["lane"]["workflow"])
        self.assertEqual("project_drift", report["summary"]["lane"])

    def test_invalid_lane_blocks_aggregate_report(self):
        from scripts.run_harness_checks import aggregate_exit_code, run_harness_checks

        report = run_harness_checks(self.repo, lane="mixed")

        self.assertEqual("invalid", report["lane"]["status"])
        self.assertEqual("unknown_operating_lane", report["lane"]["issues"][0]["code"])
        self.assertEqual(20, aggregate_exit_code(report, require="observe"))

    def test_empty_explicit_lane_blocks_aggregate_report(self):
        from scripts.run_harness_checks import aggregate_exit_code, run_harness_checks

        report = run_harness_checks(self.repo, lane="")

        self.assertEqual("invalid", report["lane"]["status"])
        self.assertEqual("empty_operating_lane", report["lane"]["issues"][0]["code"])
        self.assertEqual(20, aggregate_exit_code(report, require="observe"))

    def test_aggregate_report_classifies_requested_action(self):
        from scripts.run_harness_checks import run_harness_checks

        report = run_harness_checks(self.repo, action_description="create cron job for observer")

        self.assertEqual("scheduler_side_effect", report["preflight"]["classification"])
        self.assertTrue(report["preflight"]["requires_manual_gate"])

    def test_execute_requirement_blocks_manual_gate_action_even_on_clean_allowed_branch(self):
        from scripts.run_harness_checks import aggregate_exit_code, run_harness_checks

        temp, repo = self._temp_repo_with_valid_harness(git=True, branch="hermes/test")
        with temp:
            report = run_harness_checks(repo, action_description="install Goto.app to /Applications")

        self.assertEqual("pass", report["readiness"]["execute"]["status"])
        self.assertEqual("user_or_system_side_effect", report["preflight"]["classification"])
        self.assertTrue(report["preflight"]["requires_manual_gate"])
        self.assertEqual("manual_gate_required", report["summary"]["safe_next_action"])
        self.assertEqual(10, aggregate_exit_code(report, require="execute"))


if __name__ == "__main__":
    unittest.main()
