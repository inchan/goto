# Finder Stage Debugging Plan

> For Hermes: execute in strict order with a self-critique and one self-improvement loop after each stage.

Goal: restore a reliable Finder path for goto by separating runtime/install-surface issues from source-level regressions, then fixing source-of-truth regressions with tests first.

Architecture:
- Treat Finder as a pipeline with explicit boundaries: install surface -> extension registration -> Finder invocation -> folder resolution -> launch dispatch -> terminal open.
- Fix only source-of-truth regressions in repo code; treat stale local installs as environment state to be corrected manually after code-level safeguards exist.

Tech Stack: Node test runner, Ruby Xcode project generator, Swift Finder Sync extension, macOS PlugInKit / pkgutil / PlistBuddy.

---

## Stage 1 — 탐색

Objective: collect current, legacy, and runtime evidence for every Finder hop.

Evidence checkpoints:
- Running process path
- ~/Applications vs /Applications bundle ids, versions, PlugIns contents
- PlugInKit listing
- pkg receipt version
- current Finder extension code path
- legacy bridge code path
- build/install/package scripts

Self-critique questions:
- Did we distinguish current source from current machine state?
- Did we identify start and end points explicitly?
- Did we avoid assuming stale installs reflect current HEAD?

Improvement loop:
- If a boundary is still ambiguous, add one targeted command or file read and update the evidence map.

## Stage 2 — 분석

Objective: split findings into runtime blockers vs source regressions.

Expected analysis outputs:
1. First runtime failing stage on this Mac
2. Current HEAD code-path differences vs legacy path
3. Source regressions that can break future builds even if runtime state is corrected

Self-critique questions:
- Are we conflating symptom with root cause?
- Is each claimed cause backed by direct file or command evidence?
- Did we separate “stale install” from “repo bug”?

Improvement loop:
- Remove any claim not backed by a file/command and restate it as a hypothesis if needed.

## Stage 3 — 설계

Objective: design the smallest safe repo changes.

Planned design scope:
- Restore Finder Sync target entitlements wiring in the Xcode project generator
- Add regression tests for generated project settings
- Add/extend install-copy smoke test so local app copies preserve embedded PlugIns
- Do not redesign Finder architecture yet unless evidence shows the direct-launch design itself is broken after install/runtime issues are fixed

Self-critique questions:
- Is the design minimal and evidence-driven?
- Does it target source-of-truth files rather than generated artifacts?
- Are we avoiding speculative architecture churn?

Improvement loop:
- Trim any change that is not directly tied to a proven failing stage.

## Stage 4 — 계획

Objective: convert the design into TDD-sized tasks.

Task list:
1. Add failing test: generated project includes Finder Sync CODE_SIGN_ENTITLEMENTS
2. Add failing test: install-app copies embedded PlugIns/GotoFinderSync.appex when present
3. Patch scripts/generate_macos_project.rb minimally
4. Regenerate project and verify pbxproj contains entitlements setting
5. Run targeted tests
6. Run broader native script tests
7. Review diffs and summarize remaining manual runtime action

Self-critique questions:
- Are tasks small and verifiable?
- Is every code change preceded by a failing test?
- Are manual environment steps separated from repo changes?

Improvement loop:
- Split any task that bundles multiple behavioral assertions.

## Stage 5 — 구현

Objective: implement only after RED tests exist.

Rules:
- No production edit before failing tests
- Patch only source-of-truth files
- Keep changes minimal

## Stage 6 — 테스트

Objective: run RED -> GREEN -> broader verification.

Commands:
- node --test product/cli/test/native-scripts.test.js
- node --test product/cli/test/install-smoke.test.js
- scripts/build-app.sh <tmpdir> as needed for manual verification

## Stage 7 — 리뷰

Objective: self-critique diff quality and behavioral coverage.

Checks:
- No unintended architecture changes
- Tests specifically cover the proven regression
- Generated project behavior matches design intent

## Stage 8 — 퀄리티

Objective: final quality gate and user-facing next-action summary.

Outputs:
- What repo bug was fixed
- What runtime/manual cleanup still remains on this Mac
- Exact manual verification steps for Finder after reinstall
