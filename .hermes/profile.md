---
project: goto
profile: goto
workspace_root: /Users/inchan/workspace
score: 90
roles:
  - research
  - planner
  - implementer
  - verifier
  - reviewer
---

# goto Hermes project profile

Purpose:
- Keep project-specific context local to this repository.
- Choose the next useful improvement without needing a fresh design discussion every time.
- Use role-based subagents for research, planning, implementation, verification, and review.

Default operating rules:
- Start with evidence from the repo, not assumptions.
- Pick the smallest high-leverage goal first.
- Keep work in one explicit operating lane at a time: self-improvement, project drift, or operations.
- Prefer reversible changes and mechanical verification.
- Record exclusions or failures instead of dropping them.

Recommended roles:
- research
- planner
- implementer
- verifier
- reviewer
