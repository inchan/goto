import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { promises as fs } from 'node:fs';

import { createTempDir, projectRoot, runProcess, writeExecutable } from './helpers.js';

test('test-native script keeps SwiftPM and compiler caches inside the repository', async () => {
  const fakeBinDir = await createTempDir('goto-native-bin-');
  const swiftLogPath = path.join(fakeBinDir, 'swift.log');
  const swiftPath = path.join(fakeBinDir, 'swift');
  const scriptPath = path.join(projectRoot, 'scripts/test-native.sh');
  const moduleCachePath = path.join(projectRoot, 'build/ModuleCache.noindex');
  const swiftpmCachePath = path.join(projectRoot, 'build/swiftpm-cache');
  const swiftpmConfigPath = path.join(projectRoot, 'build/swiftpm-config');
  const swiftpmSecurityPath = path.join(projectRoot, 'build/swiftpm-security');
  const developerDir = path.join(fakeBinDir, 'FakeXcode.app/Contents/Developer');

  await writeExecutable(
    swiftPath,
    `#!/bin/sh
{
  printf 'DEVELOPER_DIR=%s\\n' "$DEVELOPER_DIR"
  printf 'CLANG_MODULE_CACHE_PATH=%s\\n' "$CLANG_MODULE_CACHE_PATH"
  printf 'ARGS=%s\\n' "$*"
} > "${swiftLogPath}"
exit 0
`
  );

  const result = await runProcess('bash', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      DEVELOPER_DIR: developerDir,
      GOTO_SWIFT_BIN: swiftPath,
    },
  });

  const log = await fs.readFile(swiftLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.match(log, new RegExp(`DEVELOPER_DIR=${escapeRegExp(developerDir)}`));
  assert.match(log, new RegExp(`CLANG_MODULE_CACHE_PATH=${escapeRegExp(moduleCachePath)}`));
  assert.match(log, new RegExp(`--cache-path ${escapeRegExp(swiftpmCachePath)}`));
  assert.match(log, new RegExp(`--config-path ${escapeRegExp(swiftpmConfigPath)}`));
  assert.match(log, new RegExp(`--security-path ${escapeRegExp(swiftpmSecurityPath)}`));
  assert.match(log, new RegExp(`--scratch-path ${escapeRegExp(path.join(projectRoot, 'product/core/.build'))}`));
  assert.match(log, /--manifest-cache local/);
  assert.match(log, /--disable-sandbox/);
  assert.match(log, new RegExp(`-Xswiftc -module-cache-path -Xswiftc ${escapeRegExp(moduleCachePath)}`));
  assert.match(log, new RegExp(`-Xcc -fmodules-cache-path=${escapeRegExp(moduleCachePath)}`));
});

test('typecheck-native script uses Xcode SDK resolution and repository module cache', async () => {
  const fakeBinDir = await createTempDir('goto-typecheck-bin-');
  const xcrunLogPath = path.join(fakeBinDir, 'xcrun.log');
  const swiftcLogPath = path.join(fakeBinDir, 'swiftc.log');
  const xcrunPath = path.join(fakeBinDir, 'xcrun');
  const swiftcPath = path.join(fakeBinDir, 'swiftc');
  const scriptPath = path.join(projectRoot, 'scripts/typecheck-native.sh');
  const moduleCachePath = path.join(projectRoot, 'build/ModuleCache.noindex');
  const developerDir = path.join(fakeBinDir, 'FakeXcode.app/Contents/Developer');

  await writeExecutable(
    xcrunPath,
    `#!/bin/sh
{
  printf 'DEVELOPER_DIR=%s\\n' "$DEVELOPER_DIR"
  printf 'ARGS=%s\\n' "$*"
} > "${xcrunLogPath}"
printf '%s\\n' '/tmp/fake-macos-sdk'
`
  );

  await writeExecutable(
    swiftcPath,
    `#!/bin/sh
{
  printf 'DEVELOPER_DIR=%s\\n' "$DEVELOPER_DIR"
  printf 'CLANG_MODULE_CACHE_PATH=%s\\n' "$CLANG_MODULE_CACHE_PATH"
  printf 'ARGS=%s\\n' "$*"
} > "${swiftcLogPath}"
exit 0
`
  );

  const result = await runProcess('bash', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      DEVELOPER_DIR: developerDir,
      GOTO_XCRUN_BIN: xcrunPath,
      GOTO_SWIFTC_BIN: swiftcPath,
    },
  });

  const xcrunLog = await fs.readFile(xcrunLogPath, 'utf8');
  const swiftcLog = await fs.readFile(swiftcLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.match(xcrunLog, new RegExp(`DEVELOPER_DIR=${escapeRegExp(developerDir)}`));
  assert.match(xcrunLog, /ARGS=--show-sdk-path/);
  assert.match(swiftcLog, new RegExp(`DEVELOPER_DIR=${escapeRegExp(developerDir)}`));
  assert.match(swiftcLog, new RegExp(`CLANG_MODULE_CACHE_PATH=${escapeRegExp(moduleCachePath)}`));
  assert.match(swiftcLog, /ARGS=.*-sdk \/tmp\/fake-macos-sdk/);
  assert.match(swiftcLog, new RegExp(`-module-cache-path ${escapeRegExp(moduleCachePath)}`));
});

test('verify script runs the standard local gates in order', async () => {
  const fakeBinDir = await createTempDir('goto-verify-bin-');
  const logPath = path.join(fakeBinDir, 'verify.log');
  const nodePath = path.join(fakeBinDir, 'node');
  const typecheckPath = path.join(fakeBinDir, 'typecheck-native.sh');
  const testNativePath = path.join(fakeBinDir, 'test-native.sh');
  const buildAppPath = path.join(fakeBinDir, 'build-app.sh');
  const scriptPath = path.join(projectRoot, 'scripts/verify.sh');

  await writeExecutable(nodePath, appendCommandScript(logPath, 'node'));
  await writeExecutable(typecheckPath, appendCommandScript(logPath, 'typecheck-native'));
  await writeExecutable(testNativePath, appendCommandScript(logPath, 'test-native'));
  await writeExecutable(buildAppPath, appendCommandScript(logPath, 'build-app'));

  const result = await runProcess('bash', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_NODE_BIN: nodePath,
      GOTO_NATIVE_TYPECHECK_SCRIPT: typecheckPath,
      GOTO_NATIVE_TEST_SCRIPT: testNativePath,
      GOTO_BUILD_APP_SCRIPT: buildAppPath,
    },
  });

  const calls = (await fs.readFile(logPath, 'utf8')).trim().split('\n');

  assert.equal(result.code, 0);
  assert.deepEqual(calls.map((line) => line.split(' ')[0]), [
    'node',
    'typecheck-native',
    'test-native',
  ]);
  assert.match(calls[0], /--test/);
  assert.doesNotMatch(calls.join('\n'), /^build-app/m);
});

test('verify script ci mode adds the app build gate and Finder appex check', async () => {
  const fakeBinDir = await createTempDir('goto-verify-ci-bin-');
  const logPath = path.join(fakeBinDir, 'verify.log');
  const nodePath = path.join(fakeBinDir, 'node');
  const typecheckPath = path.join(fakeBinDir, 'typecheck-native.sh');
  const testNativePath = path.join(fakeBinDir, 'test-native.sh');
  const buildAppPath = path.join(fakeBinDir, 'build-app.sh');
  const checkFinderPath = path.join(fakeBinDir, 'check-finder-appex.sh');
  const scriptPath = path.join(projectRoot, 'scripts/verify.sh');

  await writeExecutable(nodePath, appendCommandScript(logPath, 'node'));
  await writeExecutable(typecheckPath, appendCommandScript(logPath, 'typecheck-native'));
  await writeExecutable(testNativePath, appendCommandScript(logPath, 'test-native'));
  await writeExecutable(buildAppPath, appendCommandScript(logPath, 'build-app'));
  await writeExecutable(checkFinderPath, appendCommandScript(logPath, 'check-finder-appex'));

  const result = await runProcess('bash', [scriptPath, '--ci'], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_NODE_BIN: nodePath,
      GOTO_NATIVE_TYPECHECK_SCRIPT: typecheckPath,
      GOTO_NATIVE_TEST_SCRIPT: testNativePath,
      GOTO_BUILD_APP_SCRIPT: buildAppPath,
      GOTO_FINDER_APPEX_CHECK_SCRIPT: checkFinderPath,
    },
  });

  const calls = (await fs.readFile(logPath, 'utf8')).trim().split('\n');

  assert.equal(result.code, 0);
  assert.deepEqual(calls.map((line) => line.split(' ')[0]), [
    'node',
    'typecheck-native',
    'test-native',
    'build-app',
    'check-finder-appex',
  ]);
});

test('build-app script keeps Xcode build outputs inside the repository', async () => {
  const fakeBinDir = await createTempDir('goto-build-app-bin-');
  const rubyLogPath = path.join(fakeBinDir, 'ruby.log');
  const xcodebuildLogPath = path.join(fakeBinDir, 'xcodebuild.log');
  const rubyPath = path.join(fakeBinDir, 'ruby');
  const xcodebuildPath = path.join(fakeBinDir, 'xcodebuild');
  const productsPath = path.join(await createTempDir('goto-products-'), 'products');
  const scriptPath = path.join(projectRoot, 'scripts/build-app.sh');
  const moduleCachePath = path.join(projectRoot, 'build/ModuleCache.noindex');
  const derivedDataPath = path.join(projectRoot, 'build/DerivedData');
  const developerDir = path.join(fakeBinDir, 'FakeXcode.app/Contents/Developer');

  await writeExecutable(rubyPath, appendCommandScript(rubyLogPath, 'ruby'));
  await writeExecutable(
    xcodebuildPath,
    `#!/bin/sh
{
  printf 'DEVELOPER_DIR=%s\\n' "$DEVELOPER_DIR"
  printf 'CLANG_MODULE_CACHE_PATH=%s\\n' "$CLANG_MODULE_CACHE_PATH"
  printf 'ARGS=%s\\n' "$*"
} > '${xcodebuildLogPath}'
exit 0
`
  );

  const result = await runProcess('bash', [scriptPath, productsPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      DEVELOPER_DIR: developerDir,
      GOTO_RUBY_BIN: rubyPath,
      GOTO_XCODEBUILD_BIN: xcodebuildPath,
    },
  });

  const rubyLog = await fs.readFile(rubyLogPath, 'utf8');
  const xcodebuildLog = await fs.readFile(xcodebuildLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.match(result.stdout.trim(), new RegExp(`${escapeRegExp(productsPath)}/Release/Goto\\.app$`));
  assert.match(rubyLog, /generate_macos_project\.rb/);
  assert.match(xcodebuildLog, new RegExp(`CLANG_MODULE_CACHE_PATH=${escapeRegExp(moduleCachePath)}`));
  assert.match(xcodebuildLog, /-scheme Goto/);
  assert.match(xcodebuildLog, new RegExp(`-derivedDataPath ${escapeRegExp(derivedDataPath)}`));
  assert.match(xcodebuildLog, new RegExp(`SYMROOT=${escapeRegExp(productsPath)}`));
});

test('generate_macos_project wires Finder Sync entitlements into the generated project', async () => {
  const scriptPath = path.join(projectRoot, 'scripts', 'generate_macos_project.rb');
  const projectPath = path.join(projectRoot, 'product', 'macos', 'Goto.xcodeproj');
  const projectFilePath = path.join(projectPath, 'project.pbxproj');
  const originalProject = await fs.readFile(projectFilePath, 'utf8').catch((error) => {
    if (error.code === 'ENOENT') {
      return null;
    }

    throw error;
  });
  const inspectScript = `
require 'json'
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV[0])
result = {}
project.targets.each do |target|
  result[target.name] = target.build_configurations.to_h do |config|
    [config.name, config.build_settings['CODE_SIGN_ENTITLEMENTS']]
  end
end
puts JSON.generate(result)
`;

  try {
    const result = await runProcess('ruby', [scriptPath], {
      cwd: projectRoot,
      env: process.env,
    });
    assert.equal(result.code, 0);

    const inspection = await runProcess('ruby', ['-e', inspectScript, projectPath], {
      cwd: projectRoot,
      env: process.env,
    });
    assert.equal(inspection.code, 0);

    const parsed = JSON.parse(inspection.stdout);
    assert.equal(parsed.GotoFinderSync.Debug, 'GotoFinderSync/GotoFinderSync.entitlements');
    assert.equal(parsed.GotoFinderSync.Release, 'GotoFinderSync/GotoFinderSync.entitlements');
    assert.equal(parsed.Goto.Debug ?? null, null);
    assert.equal(parsed.Goto.Release ?? null, null);
  } finally {
    if (originalProject === null) {
      await fs.rm(projectPath, { recursive: true, force: true });
    } else {
      await fs.writeFile(projectFilePath, originalProject);
    }
  }
});

test('package-smoke script builds a package and verifies the expected payload', async () => {
  const fakeBinDir = await createTempDir('goto-package-smoke-bin-');
  const pkgPath = path.join(fakeBinDir, 'goto.pkg');
  const logPath = path.join(fakeBinDir, 'package-smoke.log');
  const buildPkgPath = path.join(fakeBinDir, 'build-pkg.sh');
  const pkgutilPath = path.join(fakeBinDir, 'pkgutil');
  const shasumPath = path.join(fakeBinDir, 'shasum');
  const scriptPath = path.join(projectRoot, 'scripts/package-smoke.sh');

  await fs.writeFile(pkgPath, 'fake-pkg');
  await writeExecutable(
    buildPkgPath,
    `#!/bin/sh
printf '%s\\n' 'build-pkg' >> '${logPath}'
printf '%s\\n' '${pkgPath}'
`
  );
  await writeExecutable(
    pkgutilPath,
    `#!/bin/sh
printf '%s %s\\n' 'pkgutil' "$*" >> '${logPath}'
cat <<'PAYLOAD'
Applications/Goto.app
Applications/Goto.app/Contents/PlugIns/GotoFinderSync.appex
usr/local/lib/goto/bin/goto.js
usr/local/lib/goto/src/cli.js
usr/local/lib/goto/shell/goto.zsh
usr/local/lib/goto/shell/goto.bash
usr/local/lib/goto/scripts/install-shell.sh
usr/local/lib/goto/scripts/uninstall.sh
usr/local/bin/goto
usr/local/bin/goto-install-shell
usr/local/bin/goto-uninstall
PAYLOAD
`
  );
  await writeExecutable(
    shasumPath,
    `#!/bin/sh
printf '%s %s\\n' 'shasum' "$*" >> '${logPath}'
printf '%s  %s\\n' 'abc123' "$3"
`
  );

  const result = await runProcess('bash', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_BUILD_PKG_SCRIPT: buildPkgPath,
      GOTO_PKGUTIL_BIN: pkgutilPath,
      GOTO_SHASUM_BIN: shasumPath,
    },
  });

  const log = await fs.readFile(logPath, 'utf8');

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Package smoke passed:/);
  assert.match(result.stdout, /SHA-256: abc123/);
  assert.match(log, /^build-pkg$/m);
  assert.match(log, new RegExp(`pkgutil --payload-files ${escapeRegExp(pkgPath)}`));
  assert.match(log, new RegExp(`shasum -a 256 ${escapeRegExp(pkgPath)}`));
});

test('package-smoke script fails when an expected payload file is missing', async () => {
  const fakeBinDir = await createTempDir('goto-package-smoke-missing-bin-');
  const pkgPath = path.join(fakeBinDir, 'goto.pkg');
  const pkgutilPath = path.join(fakeBinDir, 'pkgutil');
  const shasumPath = path.join(fakeBinDir, 'shasum');
  const scriptPath = path.join(projectRoot, 'scripts/package-smoke.sh');

  await fs.writeFile(pkgPath, 'fake-pkg');
  await writeExecutable(
    pkgutilPath,
    `#!/bin/sh
cat <<'PAYLOAD'
Applications/Goto.app
PAYLOAD
`
  );
  await writeExecutable(shasumPath, `#!/bin/sh\nprintf '%s  %s\\n' 'abc123' "$3"\n`);

  const result = await runProcess('bash', [scriptPath, pkgPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_PKGUTIL_BIN: pkgutilPath,
      GOTO_SHASUM_BIN: shasumPath,
    },
  });

  assert.equal(result.code, 1);
  assert.match(result.stderr, /missing payload path:/);
});

test('check-finder-appex script validates built appex entitlements', async () => {
  const fakeBinDir = await createTempDir('goto-check-finder-bin-');
  const appRoot = path.join(await createTempDir('goto-check-finder-app-'), 'Goto.app');
  const appexRoot = path.join(appRoot, 'Contents', 'PlugIns', 'GotoFinderSync.appex');
  const scriptPath = path.join(projectRoot, 'scripts/check-finder-appex.sh');
  const codesignPath = path.join(fakeBinDir, 'codesign');

  await fs.mkdir(appexRoot, { recursive: true });
  await writeExecutable(
    codesignPath,
    `#!/bin/sh
cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.files.user-selected.read-only</key><true/>
</dict></plist>
PLIST
`
  );

  const result = await runProcess('bash', [scriptPath, appRoot], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_CODESIGN_BIN: codesignPath,
    },
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Finder appex check passed:/);
});

function appendCommandScript(logPath, name) {
  return `#!/bin/sh
printf '%s %s\\n' '${name}' "$*" >> '${logPath}'
exit 0
`;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
