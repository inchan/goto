# Operator Cron Template

Status: disabled until harness readiness passes and user explicitly approves activation.

Rules:
- Use an absolute workdir.
- Do not create new cron jobs.
- Execute at most one approved safe action per run.
- Stop on main branch, critical drift, manual gate, approval-required action, or dirty unrelated tree.
