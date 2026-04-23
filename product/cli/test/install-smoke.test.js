import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';

import { promises as fs } from 'node:fs';

import { cliPath, cliRoot, createTempDir, projectRoot, runProcess, writeExecutable } from './helpers.js';

test('the direct executable path works from the repository', async () => {
  const homeDir = await createTempDir();
  const result = await runProcess(cliPath, ['--help'], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Usage:/);
  assert.equal(result.stderr, '');
});

test('install-shell script writes the zsh source block exactly once', async () => {
  const homeDir = await createTempDir();
  const zdotDir = await createTempDir();
  const rcFile = path.join(zdotDir, '.zshrc');
  const scriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const env = {
    ...process.env,
    HOME: homeDir,
    ZDOTDIR: zdotDir,
    SHELL: '/bin/zsh',
  };

  const firstRun = await runProcess('bash', [scriptPath, '--shell', 'zsh'], { cwd: projectRoot, env });
  const secondRun = await runProcess('bash', [scriptPath, '--shell', 'zsh'], { cwd: projectRoot, env });
  const contents = await fs.readFile(rcFile, 'utf8');
  const matches = contents.match(/source ".*goto\.zsh"/g) || [];

  assert.equal(firstRun.code, 0);
  assert.equal(secondRun.code, 0);
  assert.equal(matches.length, 1);
  assert.match(contents, /# >>> goto >>>/);
  assert.match(contents, /goto\.zsh/);
});

test('install-shell script writes the bash source block exactly once', async () => {
  const homeDir = await createTempDir();
  const rcFile = path.join(homeDir, '.bashrc');
  const scriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const env = {
    ...process.env,
    HOME: homeDir,
    SHELL: '/bin/bash',
  };

  const firstRun = await runProcess('bash', [scriptPath, '--shell', 'bash'], { cwd: projectRoot, env });
  const secondRun = await runProcess('bash', [scriptPath, '--shell', 'bash'], { cwd: projectRoot, env });
  const contents = await fs.readFile(rcFile, 'utf8');
  const matches = contents.match(/source ".*goto\.bash"/g) || [];

  assert.equal(firstRun.code, 0);
  assert.equal(secondRun.code, 0);
  assert.equal(matches.length, 1);
  assert.match(contents, /# >>> goto >>>/);
  assert.match(contents, /goto\.bash/);
});

test('install-shell script replaces a stale managed block when the shell source path moves', async () => {
  const homeDir = await createTempDir();
  const zdotDir = await createTempDir();
  const rcFile = path.join(zdotDir, '.zshrc');
  const scriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const staleSource = path.join(projectRoot, 'shell', 'goto.zsh');

  await fs.writeFile(
    rcFile,
    `export PATH="$PATH:/tmp"\n# >>> goto >>>\nsource "${staleSource}"\n# <<< goto <<<\n`
  );

  const result = await runProcess('bash', [scriptPath, '--shell', 'zsh'], {
    cwd: projectRoot,
    env: {
      ...process.env,
      HOME: homeDir,
      ZDOTDIR: zdotDir,
      SHELL: '/bin/zsh',
    },
  });

  const contents = await fs.readFile(rcFile, 'utf8');
  const matches = contents.match(/# >>> goto >>>/g) || [];

  assert.equal(result.code, 0);
  assert.equal(matches.length, 1);
  assert.match(contents, /export PATH/);
  assert.doesNotMatch(contents, new RegExp(staleSource.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.match(contents, new RegExp(`${cliRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.zsh`));
});

test('install-shell script can target an installed payload root explicitly', async () => {
  const homeDir = await createTempDir();
  const zdotDir = await createTempDir();
  const stagedRoot = await createTempDir('goto-staged-root-');
  const rcFile = path.join(zdotDir, '.zshrc');
  const scriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const stagedShellPath = path.join(stagedRoot, 'shell');

  await fs.mkdir(stagedShellPath, { recursive: true });
  await fs.writeFile(path.join(stagedShellPath, 'goto.zsh'), '# staged goto zsh\n');

  const result = await runProcess('bash', [scriptPath, '--shell', 'zsh'], {
    cwd: projectRoot,
    env: {
      ...process.env,
      HOME: homeDir,
      ZDOTDIR: zdotDir,
      SHELL: '/bin/zsh',
      GOTO_INSTALL_SHELL_SOURCE_ROOT: stagedRoot,
    },
  });

  const contents = await fs.readFile(rcFile, 'utf8');

  assert.equal(result.code, 0);
  assert.match(contents, new RegExp(`${path.join(stagedRoot, 'shell', 'goto.zsh').replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
});

test('pkg postinstall runs shell integration for the logged-in user and opens Goto.app', async () => {
  const homeDir = await createTempDir('goto-postinstall-home-');
  const fakeBinDir = await createTempDir('goto-postinstall-bin-');
  const scriptPath = path.join(projectRoot, 'scripts/pkg-postinstall.sh');
  const installScriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const rcFile = path.join(homeDir, '.zshrc');
  const statPath = path.join(fakeBinDir, 'stat');
  const suPath = path.join(fakeBinDir, 'su');
  const openPath = path.join(fakeBinDir, 'open');
  const suLogPath = path.join(fakeBinDir, 'su.log');
  const openLogPath = path.join(fakeBinDir, 'open.log');
  const appDir = path.join(await createTempDir('goto-app-'), 'Goto.app');

  await fs.mkdir(appDir, { recursive: true });

  await writeExecutable(statPath, `#!/bin/sh\nprintf '%s\\n' "test-user"\n`);
  await writeExecutable(
    suPath,
    `#!/bin/sh
printf '%s\\n' "$*" >> "${suLogPath}"
user=""
command=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l)
      user="$2"
      shift 2
      ;;
    -c)
      command="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
HOME="${homeDir}" SHELL="/bin/zsh" USER="$user" LOGNAME="$user" /bin/sh -c "$command"
`
  );
  await writeExecutable(
    openPath,
    `#!/bin/sh
printf '%s\\n' "$*" >> "${openLogPath}"
exit 0
`
  );

  const result = await runProcess('sh', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_APP_PATH: appDir,
      GOTO_INSTALL_SHELL_BIN: installScriptPath,
      GOTO_OPEN_BIN: openPath,
      GOTO_STAT_BIN: statPath,
      GOTO_SU_BIN: suPath,
    },
  });

  const contents = await fs.readFile(rcFile, 'utf8');
  const matches = contents.match(/source ".*goto\.zsh"/g) || [];
  const suLog = await fs.readFile(suLogPath, 'utf8');
  const openLog = await fs.readFile(openLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.equal(matches.length, 1);
  assert.match(result.stdout, /Shell integration was installed for test-user/);
  assert.match(suLog, /-l test-user -c/);
  assert.match(openLog, new RegExp(`-gj ${appDir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
});

test('pkg postinstall removes conflicting user-local app installs while keeping the system app target', async () => {
  const homeDir = await createTempDir('goto-postinstall-clean-home-');
  const fakeBinDir = await createTempDir('goto-postinstall-clean-bin-');
  const scriptPath = path.join(projectRoot, 'scripts/pkg-postinstall.sh');
  const installScriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const statPath = path.join(fakeBinDir, 'stat');
  const suPath = path.join(fakeBinDir, 'su');
  const openPath = path.join(fakeBinDir, 'open');
  const systemAppDir = path.join(await createTempDir('goto-system-app-'), 'Goto.app');
  const userAppDir = path.join(homeDir, 'Applications', 'Goto.app');

  await fs.mkdir(systemAppDir, { recursive: true });
  await fs.mkdir(path.join(userAppDir, 'Contents', 'MacOS'), { recursive: true });
  await fs.writeFile(path.join(userAppDir, 'Contents', 'MacOS', 'Goto'), '#!/bin/sh\n');

  await writeExecutable(statPath, `#!/bin/sh\nprintf '%s\\n' "test-user"\n`);
  await writeExecutable(
    suPath,
    `#!/bin/sh
user=""
command=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -l)
      user="$2"
      shift 2
      ;;
    -c)
      command="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
HOME="${homeDir}" SHELL="/bin/zsh" USER="$user" LOGNAME="$user" /bin/sh -c "$command"
`
  );
  await writeExecutable(openPath, '#!/bin/sh\nexit 0\n');

  const result = await runProcess('sh', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_APP_PATH: systemAppDir,
      GOTO_INSTALL_SHELL_BIN: installScriptPath,
      GOTO_OPEN_BIN: openPath,
      GOTO_STAT_BIN: statPath,
      GOTO_SU_BIN: suPath,
      GOTO_CONFLICT_APP_PATHS: `${systemAppDir}\n${userAppDir}`,
    },
  });

  assert.equal(result.code, 0);
  await fs.access(systemAppDir);
  await assert.rejects(fs.access(userAppDir));
});

test('install-app script copies the built app bundle to the destination and opens it', async () => {
  const appsRoot = await createTempDir('goto-install-apps-');
  const fakeBinDir = await createTempDir('goto-install-bin-');
  const buildRoot = await createTempDir('goto-install-build-');
  const scriptPath = path.join(projectRoot, 'scripts/install-app.sh');
  const buildScriptPath = path.join(fakeBinDir, 'build-app.sh');
  const openPath = path.join(fakeBinDir, 'open');
  const openLogPath = path.join(fakeBinDir, 'open.log');
  const destinationPath = path.join(appsRoot, 'Goto.app');
  const builtAppPath = path.join(buildRoot, 'Release', 'Goto.app');
  const builtBinaryDir = path.join(builtAppPath, 'Contents', 'MacOS');
  const builtPluginDir = path.join(builtAppPath, 'Contents', 'PlugIns', 'GotoFinderSync.appex', 'Contents', 'MacOS');
  const destinationBinaryPath = path.join(destinationPath, 'Contents', 'MacOS', 'Goto');
  const destinationPluginPath = path.join(destinationPath, 'Contents', 'PlugIns', 'GotoFinderSync.appex');
  const destinationPluginBinaryPath = path.join(destinationPluginPath, 'Contents', 'MacOS', 'GotoFinderSync');

  await fs.mkdir(builtBinaryDir, { recursive: true });
  await fs.mkdir(builtPluginDir, { recursive: true });
  await fs.writeFile(path.join(builtBinaryDir, 'Goto'), '#!/bin/sh\n');
  await fs.writeFile(path.join(builtPluginDir, 'GotoFinderSync'), '#!/bin/sh\n');
  await writeExecutable(buildScriptPath, `#!/bin/sh\nprintf '%s\\n' "${builtAppPath}"\n`);
  await fs.writeFile(openLogPath, '');
  await writeExecutable(
    openPath,
    `#!/bin/sh
printf '%s\\n' "$*" >> "${openLogPath}"
exit 0
`
  );

  const result = await runProcess('bash', [scriptPath, destinationPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_BUILD_APP_SCRIPT: buildScriptPath,
      GOTO_OPEN_BIN: openPath,
    },
  });

  const openLog = await fs.readFile(openLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.equal(result.stdout.trim(), destinationPath);
  await fs.access(destinationBinaryPath);
  await fs.access(destinationPluginPath);
  await fs.access(destinationPluginBinaryPath);
  assert.match(openLog, new RegExp(destinationPath.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
});

test('install-app script removes conflicting installed app copies while updating the destination', async () => {
  const fakeBinDir = await createTempDir('goto-install-clean-bin-');
  const buildRoot = await createTempDir('goto-install-clean-build-');
  const appsRoot = await createTempDir('goto-install-clean-apps-');
  const legacyRoot = await createTempDir('goto-install-clean-legacy-');
  const scriptPath = path.join(projectRoot, 'scripts/install-app.sh');
  const buildScriptPath = path.join(fakeBinDir, 'build-app.sh');
  const openPath = path.join(fakeBinDir, 'open');
  const destinationPath = path.join(appsRoot, 'Goto.app');
  const conflictingPath = path.join(legacyRoot, 'Goto.app');
  const builtAppPath = path.join(buildRoot, 'Release', 'Goto.app');

  await fs.mkdir(path.join(builtAppPath, 'Contents', 'MacOS'), { recursive: true });
  await fs.writeFile(path.join(builtAppPath, 'Contents', 'MacOS', 'Goto'), '#!/bin/sh\n');
  await fs.mkdir(path.join(conflictingPath, 'Contents', 'MacOS'), { recursive: true });
  await fs.writeFile(path.join(conflictingPath, 'Contents', 'MacOS', 'Goto'), '#!/bin/sh\n');

  await writeExecutable(buildScriptPath, `#!/bin/sh\nprintf '%s\\n' "${builtAppPath}"\n`);
  await writeExecutable(openPath, '#!/bin/sh\nexit 0\n');

  const result = await runProcess('bash', [scriptPath, destinationPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_BUILD_APP_SCRIPT: buildScriptPath,
      GOTO_OPEN_BIN: openPath,
      GOTO_CONFLICT_APP_PATHS: `${destinationPath}\n${conflictingPath}`,
    },
  });

  assert.equal(result.code, 0);
  await fs.access(destinationPath);
  await assert.rejects(fs.access(conflictingPath));
});
