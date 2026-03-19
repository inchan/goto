# Testing Patterns

**Analysis Date:** 2026-03-20

## Test Framework

**Runner:**
- JavaScript runner: Node built-in test runner via `node --test`.
  - Config: `package.json`
- Swift runner: Swift Package Manager XCTest via `swift test`.
  - Config: `native/Package.swift`
- macOS integration verification is script-driven rather than XCTest-driven: `scripts/test-finder-action.sh`, `scripts/test-finder-toolbar-host.sh`.

**Assertion Library:**
- JavaScript: `node:assert/strict` in `test/cli-contract.test.js`, `test/command-mutations.test.js`, `test/registry.test.js`.
- Swift: `XCTest` in `native/Tests/GotoNativeCoreTests/*.swift` and `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`.

**Run Commands:**
```bash
npm test                              # Runs `node --test` from `package.json`
node --test                           # Runs all JavaScript tests under `test/`
./scripts/test-native.sh              # Runs `swift test --package-path native`
./scripts/typecheck-native.sh         # Typechecks `native/Sources/GotoNativeCore/*.swift`
./scripts/test-finder-action.sh       # Verifies the Automator Finder workflow path handoff
./scripts/test-finder-toolbar-host.sh # Installs and probes the Finder Sync toolbar host
```

## Test File Organization

**Location:**
- JavaScript tests live in a dedicated top-level `test/` directory: `test/cli-contract.test.js`, `test/command-mutations.test.js`, `test/install-smoke.test.js`, `test/registry.test.js`.
- Shared JavaScript test helpers live alongside tests in `test/helpers.js`.
- Swift package tests live under `native/Tests/` and are split by target: `native/Tests/GotoNativeCoreTests/` and `native/Tests/GotoMenuBarTests/`.
- Tests for the generated Xcode host in `macos/` are **Not detected**; verification for that surface is handled by shell scripts in `scripts/`.

**Naming:**
- JavaScript tests use `*.test.js`.
- Swift tests use `*Tests.swift`, and test classes mirror the production type name: `TerminalLauncherTests.swift`, `FinderSelectionTests.swift`, `MenuBarViewModelTests.swift`.

**Structure:**
```text
test/
├── helpers.js
├── cli-contract.test.js
├── command-mutations.test.js
├── install-smoke.test.js
└── registry.test.js

native/Tests/
├── GotoNativeCoreTests/
│   ├── FinderErrorPresenterTests.swift
│   ├── FinderSelectionTests.swift
│   ├── RegistryStoreTests.swift
│   ├── TerminalLaunchCommandTests.swift
│   ├── TerminalLaunchRequestTests.swift
│   ├── TerminalLauncherTests.swift
│   └── TerminalScriptBuilderTests.swift
└── GotoMenuBarTests/
    └── MenuBarViewModelTests.swift
```

## Test Structure

**Suite Organization:**
```typescript
import test from 'node:test';
import assert from 'node:assert/strict';

test('goto -a uses the current directory when no path is provided', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const result = await runCli(['-a'], { cwd: projectDir, env: { ...process.env, HOME: homeDir } });

  const entries = await readRegistry(homeDir);
  assert.equal(result.code, 0);
  assert.match(result.stdout, /Added:/);
  assert.equal(result.stderr, '');
  assert.deepEqual(entries, [await fs.realpath(projectDir)]);
});
```

**Patterns:**
- JavaScript tests are flat `test(...)` blocks with inline arrange/act/assert flow: `test/cli-contract.test.js`, `test/command-mutations.test.js`.
- Output contract assertions always check `code`, `stdout`, and `stderr` together to preserve CLI behavior: `test/cli-contract.test.js`, `test/command-mutations.test.js`, `test/install-smoke.test.js`.
- Filesystem-heavy tests use real temporary directories instead of mocks: `test/helpers.js`, `test/registry.test.js`.
- Swift tests group related assertions in `final class ...Tests: XCTestCase` suites with one behavior per method: `native/Tests/GotoNativeCoreTests/RegistryStoreTests.swift`, `native/Tests/GotoNativeCoreTests/TerminalLaunchCommandTests.swift`.
- Swift UI-facing behavior is exercised at the view-model level rather than through UI automation: `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`.

## Mocking

**Framework:** Dedicated mocking framework is **Not detected**.

**Patterns:**
```typescript
await writeExecutable(
  fakeNodePath,
  `#!/bin/sh
if [ "$1" = "${cliPath}" ] && [ "$#" -eq 1 ]; then
  printf '%s\n' "${targetDir}"
  exit 0
fi
exec "${process.execPath}" "$@"
`
);
```

```swift
private final class StubAppleScriptExecutor: AppleScriptExecuting {
    private let result: AppleScriptExecutionResult
    private(set) var scripts: [String] = []

    init(result: AppleScriptExecutionResult) {
        self.result = result
    }

    func execute(script: String) throws -> AppleScriptExecutionResult {
        scripts.append(script)
        return result
    }
}
```

**What to Mock:**
- External process boundaries and shell behavior are replaced with spawned fake executables in `test/install-smoke.test.js` through `writeExecutable()` from `test/helpers.js`.
- Swift tests stub protocols instead of real Terminal / AppleScript integrations: `StubAppleScriptExecutor` and `StubDirectoryOpener` in `native/Tests/GotoNativeCoreTests/TerminalLauncherTests.swift`, `StubTerminalLauncher` in `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`.
- Dependency injection seams in production code are the intended mock points: `TerminalLaunching`, `AppleScriptExecuting`, `DirectoryOpening`, and `ProjectListing` in `native/Sources/GotoNativeCore/TerminalLauncher.swift` and `native/Sources/GotoNativeCore/RegistryStore.swift`.

**What NOT to Mock:**
- Registry persistence and path normalization are tested against real temp directories and real files: `test/registry.test.js`, `test/command-mutations.test.js`.
- Finder selection validation uses real `URL` and `FileManager` behavior instead of fakes: `native/Tests/GotoNativeCoreTests/FinderSelectionTests.swift`.
- CLI stream contracts are exercised through actual child-process invocation in `test/helpers.js` and `test/cli-contract.test.js`.

## Fixtures and Factories

**Test Data:**
```typescript
export async function createTempDir(prefix = 'goto-test-') {
  return fs.mkdtemp(path.join(os.tmpdir(), prefix));
}

export function runCli(args, options = {}) {
  return runProcess(process.execPath, [cliPath, ...args], options);
}
```

```swift
private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}
```

**Location:**
- Shared JavaScript fixtures and process helpers live in `test/helpers.js`.
- JavaScript tests create per-test temp homes, registries, rc files, and fake binaries inline: `test/cli-contract.test.js`, `test/install-smoke.test.js`.
- Swift tests define private per-file helpers and stubs inside each test file: `native/Tests/GotoNativeCoreTests/RegistryStoreTests.swift`, `native/Tests/GotoNativeCoreTests/TerminalLaunchCommandTests.swift`.

## Coverage

**Requirements:** Coverage thresholds are **Not enforced**. No `c8`, `nyc`, coverage script, or CI coverage config was detected in `package.json` or the repo root.

**View Coverage:**
```bash
Not detected
```

## Test Types

**Unit Tests:**
- JavaScript unit/contract tests cover argument parsing effects, registry persistence, output channel behavior, and shell wrapper control flow: `test/cli-contract.test.js`, `test/command-mutations.test.js`, `test/registry.test.js`, `test/install-smoke.test.js`.
- Swift unit tests cover pure or dependency-injected native logic: registry parsing, Finder selection validation, AppleScript building, command parsing, launcher failure mapping, and menu bar status rules in `native/Tests/GotoNativeCoreTests/*.swift` and `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`.

**Integration Tests:**
- JavaScript smoke tests spawn real `bash`, `zsh`, and `node` processes to verify wrapper/installer behavior end to end: `test/install-smoke.test.js`.
- Finder workflow verification uses real Automator, `pbs`, Unicode paths, and the repository launcher in dry-run mode: `scripts/test-finder-action.sh` with `scripts/render-finder-workflow.sh` and `scripts/run-native-launch.sh`.
- Finder toolbar verification installs `GotoHost.app`, checks `pluginkit` registration, opens a custom URL, and confirms Terminal launch: `scripts/test-finder-toolbar-host.sh` with `scripts/install-finder-toolbar-host.sh`.

**E2E Tests:**
- Dedicated browser or UI automation framework is **Not used**.
- Live macOS surface verification is handled by repository-local shell scripts rather than a formal E2E harness: `scripts/test-finder-action.sh`, `scripts/test-finder-toolbar-host.sh`.

## Common Patterns

**Async Testing:**
```typescript
const result = await runCli(['--help'], {
  env: {
    ...process.env,
    HOME: homeDir,
  },
});

assert.equal(result.code, 0);
assert.match(result.stdout, /Usage:/);
```

**Error Testing:**
```typescript
const result = await runCli(['--wat'], {
  env: {
    ...process.env,
    HOME: homeDir,
  },
});

assert.equal(result.code, 2);
assert.equal(result.stdout, '');
assert.match(result.stderr, /unknown argument/);
```

```swift
XCTAssertThrowsError(try launcher.launch(request)) { error in
    XCTAssertEqual(error as? TerminalLaunchError, .terminalUnavailable)
}
```

**Shell/Native Verification Strategy:**
- JavaScript tests protect the CLI and sourced shell contract before native surfaces are involved: `test/cli-contract.test.js`, `test/install-smoke.test.js`.
- Native correctness is split between fast Swift package tests (`scripts/test-native.sh`) and direct source type checking (`scripts/typecheck-native.sh`).
- macOS extension/host validation is pushed into dedicated shell scripts because those flows require system tools (`automator`, `pluginkit`, `open`, `xcodebuild`) and installed app bundles: `scripts/test-finder-action.sh`, `scripts/test-finder-toolbar-host.sh`, `scripts/build-finder-toolbar-host.sh`.

---

*Testing analysis: 2026-03-20*
