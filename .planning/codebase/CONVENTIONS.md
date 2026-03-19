# Coding Conventions

**Analysis Date:** 2026-03-20

## Naming Patterns

**Files:**
- JavaScript source files in `src/` use lowercase noun/verb filenames with `.js` suffix: `src/cli.js`, `src/select.js`, `src/registry.js`.
- Command handlers live under `src/commands/` and use action names: `src/commands/add.js`, `src/commands/remove.js`.
- Shell integration files are named by shell target: `shell/goto.bash`, `shell/goto.zsh`.
- Node test files use `*.test.js` under `test/`: `test/cli-contract.test.js`, `test/install-smoke.test.js`.
- Swift production files use UpperCamelCase type-based filenames: `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `macos/GotoHost/MenuBarViewModel.swift`.
- Swift XCTest files end with `Tests.swift` and match the subject type: `native/Tests/GotoNativeCoreTests/RegistryStoreTests.swift`, `native/Tests/GotoMenuBarTests/MenuBarViewModelTests.swift`.

**Functions:**
- JavaScript functions use lower camelCase: `parseArgs` in `src/cli.js`, `resolveExistingDirectory` in `src/paths.js`, `formatBulkAddResult` in `src/commands/add.js`.
- Bash and zsh functions use snake_case with a `_goto_` prefix for wrapper internals: `_goto_repo_root` and `_goto_invoke` in `shell/goto.bash`, `shell/goto.zsh`.
- Swift methods use lower camelCase and test methods use `test...` names: `loadProjects()` in `native/Sources/GotoNativeCore/RegistryStore.swift`, `testLaunchMapsGeneralFailures()` in `native/Tests/GotoNativeCoreTests/TerminalLauncherTests.swift`.

**Variables:**
- JavaScript variables use lower camelCase for locals and options objects: `selectedIndex` in `src/select.js`, `rootPath` in `src/registry.js`, `homeDir` in `test/cli-contract.test.js`.
- Shell script locals use lowercase snake_case and exported-style script constants use uppercase: `developer_dir` and `products_path` in `scripts/build-finder-toolbar-host.sh`, `SCRIPT_DIR` and `REPO_ROOT` in most `scripts/*.sh`.
- Swift stored properties and locals use lower camelCase: `statusMessage` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift`, `registryURL` in `native/Sources/GotoNativeCore/RegistryStore.swift`.

**Types:**
- JavaScript classes and constant maps use UpperCamelCase / ALL_CAPS respectively: `CliError` and `EXIT_CODES` in `src/output.js`.
- Swift enums, structs, protocols, and classes use UpperCamelCase: `FinderSelectionError`, `TerminalLaunchRequest`, `ProjectListing`, `MenuBarViewModel`.

## Code Style

**Formatting:**
- Repository-wide formatter config is **Not detected**. No `.prettierrc`, `eslint.config.*`, `.editorconfig`, `.swiftformat`, or `.swiftlint.yml` files were found at the repo root.
- JavaScript in `src/`, `bin/`, and `test/` uses ES modules, single quotes, semicolons, and 2-space indentation: `src/cli.js`, `test/helpers.js`.
- JavaScript favors trailing commas in multiline literals and argument lists: `src/cli.js`, `test/install-smoke.test.js`.
- Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`: `scripts/install-shell.sh`, `scripts/test-native.sh`, `scripts/test-finder-toolbar-host.sh`.
- Shell scripts consistently use `printf` instead of `echo` for user-facing output: `scripts/install-shell.sh`, `scripts/test-finder-action.sh`, `shell/goto.bash`.
- Swift uses 4-space indentation, trailing commas in multiline collections, and explicit access control for shared native types: `native/Package.swift`, `native/Sources/GotoNativeCore/RegistryStore.swift`, `native/Sources/GotoNativeCore/TerminalLauncher.swift`.

**Linting:**
- Standalone lint tooling is **Not detected**.
- Native warning policy is enforced through Xcode build settings in `macos/Goto.xcodeproj/project.pbxproj`, which enables compiler warnings such as unused variables, return-type checks, and unguarded availability.
- Native source-only type checking is provided by `scripts/typecheck-native.sh`, which runs `swiftc -typecheck` over `native/Sources/GotoNativeCore/*.swift`.

## Import Organization

**Order:**
1. Platform or builtin imports first (`node:*` modules in `src/cli.js`, `Foundation` / `SwiftUI` in Swift files).
2. Blank line separator.
3. Relative internal imports or internal module imports (`./commands/add.js` in `src/cli.js`, `import GotoNativeCore` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift`).

**Path Aliases:**
- Path aliases are **Not detected**.
- JavaScript uses relative imports such as `../src/cli.js` in `bin/goto.js` and `./helpers.js` in `test/cli-contract.test.js`.
- Swift package targets use module imports defined by `native/Package.swift`: `import GotoNativeCore` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift`.

## Error Handling

**Patterns:**
- User-facing CLI validation errors are raised as `CliError` instances in `src/cli.js` and `src/paths.js`, then converted to stderr output and exit codes in `main()` inside `src/cli.js`.
- Command handlers return structured `{ exitCode, stdout }` objects instead of writing directly to the terminal: `src/commands/add.js`, `src/commands/remove.js`.
- Selector failures return structured result objects with `stderr` instead of throwing for expected user conditions: `runSelect()` in `src/select.js`.
- Registry read helpers swallow only missing-file cases and rethrow everything else: `readRegistry()` in `src/registry.js`, `readRegistry()` in `test/helpers.js`.
- Shell scripts fail fast with `set -euo pipefail`, emit messages to stderr with `printf ... >&2`, and rely on exit status for control flow: `scripts/install-shell.sh`, `shell/goto.bash`, `shell/goto.zsh`.
- Swift code models operational failures with typed errors and presenter layers: `FinderSelectionError` in `native/Sources/GotoNativeCore/FinderSelection.swift`, `TerminalLaunchError` in `native/Sources/GotoNativeCore/TerminalLaunchError.swift`, `FinderErrorPresenter` in `native/Sources/GotoNativeCore/FinderErrorPresenter.swift`.
- Swift entrypoints map typed errors into user-facing strings and exit codes instead of exposing raw errors directly: `native/Sources/GotoNativeCore/TerminalLaunchCommand.swift`, `native/Sources/GotoMenuBar/MenuBarViewModel.swift`.

## Logging

**Framework:** Not detected as a dedicated logging framework.

**Patterns:**
- JavaScript CLI output is centralized through `printHelp`, `printVersion`, `printInfo`, and `printError` in `src/output.js`.
- Runtime source files under `src/` do not use `console.log` or `console.error`; output flows through passed streams such as `stdout` and `stderr` in `src/cli.js` and `src/select.js`.
- Shell scripts log operational status with `printf` to stdout and errors with `printf ... >&2`: `scripts/install-shell.sh`, `scripts/test-finder-action.sh`.
- Swift UI/status feedback is surfaced through model state such as `statusMessage` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift` and `macos/GotoHost/MenuBarViewModel.swift`.

## Comments

**When to Comment:**
- Comments are sparse and used mainly for operational intent or tool-specific exceptions.
- Examples include shell sourcing guidance in `shell/goto.bash` and `shell/goto.zsh`, the MRU persistence note in `src/select.js`, and the ShellCheck suppression in `scripts/render-finder-workflow.sh`.
- Most modules rely on descriptive function/type names instead of inline commentary: `src/registry.js`, `native/Sources/GotoNativeCore/RegistryStore.swift`.

**JSDoc/TSDoc:**
- JSDoc/TSDoc is **Not detected** in `src/`, `test/`, `native/Sources/`, or `macos/`.

## Function Design

**Size:** Small-to-medium helpers are the default. Large files still decompose work into focused helpers, e.g. `parseArgs()` and `main()` in `src/cli.js`, `render()` / `openUiTty()` / `closeUiTty()` in `src/select.js`, and `mapLaunchFailure()` / `openWithoutAppleEvents()` in `native/Sources/GotoNativeCore/TerminalLauncher.swift`.

**Parameters:**
- JavaScript favors options objects with defaults for environment-dependent behavior: `main(argv, { cwd, env, stdout, stderr })` in `src/cli.js`, `runProcess(command, args, { cwd, env })` in `test/helpers.js`.
- Shell functions accept positional parameters and derive environment from `HOME`, `SHELL`, `ZDOTDIR`, and `DEVELOPER_DIR`: `scripts/install-shell.sh`, `scripts/test-native.sh`.
- Swift constructors commonly use dependency injection defaults to keep production wiring simple and tests overrideable: `TerminalLauncher.init(...)` in `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `MenuBarViewModel.init(...)` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift`.

**Return Values:**
- JavaScript command functions return structured result objects rather than calling `process.exit()` inside helpers: `src/commands/add.js`, `src/commands/remove.js`, `src/select.js`.
- Test helpers also return structured process results with `code`, `stdout`, and `stderr`: `runProcess()` in `test/helpers.js`.
- Swift command and launcher layers return explicit result structs for process-like flows: `AppleScriptExecutionResult` in `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `TerminalLaunchCommandResult` in `native/Sources/GotoNativeCore/TerminalLaunchCommand.swift`.

## Module Design

**Exports:**
- JavaScript uses named exports exclusively; default exports are **Not detected**: `src/output.js`, `src/registry.js`, `test/helpers.js`.
- Modules group related helpers with one public surface per file: path utilities in `src/paths.js`, registry persistence in `src/registry.js`, command translation in `src/commands/add.js`.
- Swift source files generally define one primary type plus nearby support types or protocols in the same file: `native/Sources/GotoNativeCore/TerminalLauncher.swift`, `native/Sources/GotoNativeCore/FinderErrorPresenter.swift`.

**Barrel Files:**
- Barrel files are **Not detected** in `src/`, `test/`, `native/Sources/`, or `macos/`.
- Importers reference concrete files or package targets directly, e.g. `../src/cli.js` in `bin/goto.js` and `GotoNativeCore` in `native/Sources/GotoMenuBar/MenuBarViewModel.swift`.

---

*Convention analysis: 2026-03-20*
