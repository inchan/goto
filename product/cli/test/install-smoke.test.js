import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';

import { promises as fs } from 'node:fs';

import { cliPath, cliRoot, createTempDir, projectRoot, readRegistry, runProcess, writeExecutable } from './helpers.js';

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

  const firstRun = await runProcess('bash', [scriptPath, '--shell', 'zsh'], {
    cwd: projectRoot,
    env,
  });
  const secondRun = await runProcess('bash', [scriptPath, '--shell', 'zsh'], {
    cwd: projectRoot,
    env,
  });
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

  const firstRun = await runProcess('bash', [scriptPath, '--shell', 'bash'], {
    cwd: projectRoot,
    env,
  });
  const secondRun = await runProcess('bash', [scriptPath, '--shell', 'bash'], {
    cwd: projectRoot,
    env,
  });
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

test('pkg postinstall runs shell integration for the logged-in user and registers Goto.app extension', async () => {
  const homeDir = await createTempDir('goto-postinstall-home-');
  const fakeBinDir = await createTempDir('goto-postinstall-bin-');
  const scriptPath = path.join(projectRoot, 'scripts/pkg-postinstall.sh');
  const installScriptPath = path.join(projectRoot, 'scripts/install-shell.sh');
  const rcFile = path.join(homeDir, '.zshrc');
  const statPath = path.join(fakeBinDir, 'stat');
  const suPath = path.join(fakeBinDir, 'su');
  const pluginkitPath = path.join(fakeBinDir, 'pluginkit');
  const killallPath = path.join(fakeBinDir, 'killall');
  const openPath = path.join(fakeBinDir, 'open');
  const suLogPath = path.join(fakeBinDir, 'su.log');
  const pluginkitLogPath = path.join(fakeBinDir, 'pluginkit.log');
  const openLogPath = path.join(fakeBinDir, 'open.log');
  const appDir = path.join(await createTempDir('goto-app-'), 'Goto.app');
  const extensionPath = path.join(appDir, 'Contents', 'PlugIns', 'GotoFinderSync.appex');

  await fs.mkdir(extensionPath, { recursive: true });

  await writeExecutable(
    statPath,
    `#!/bin/sh
printf '%s\\n' "test-user"
`
  );
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
    pluginkitPath,
    `#!/bin/sh
printf '%s\\n' "$*" >> "${pluginkitLogPath}"
exit 0
`
  );
  await writeExecutable(
    killallPath,
    `#!/bin/sh
exit 0
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
      GOTO_FINDER_APP: appDir,
      GOTO_INSTALL_SHELL_BIN: installScriptPath,
      GOTO_PLUGINKIT_BIN: pluginkitPath,
      GOTO_KILLALL_BIN: killallPath,
      GOTO_OPEN_BIN: openPath,
      GOTO_STAT_BIN: statPath,
      GOTO_SU_BIN: suPath,
    },
  });

  const contents = await fs.readFile(rcFile, 'utf8');
  const matches = contents.match(/source ".*goto\.zsh"/g) || [];
  const suLog = await fs.readFile(suLogPath, 'utf8');
  const pluginkitLog = await fs.readFile(pluginkitLogPath, 'utf8');
  const openLog = await fs.readFile(openLogPath, 'utf8');

  assert.equal(result.code, 0);
  assert.equal(matches.length, 1);
  assert.match(result.stdout, /Shell integration was installed for test-user/);
  assert.match(suLog, /-l test-user -c/);
  assert.match(pluginkitLog, /-a .*GotoFinderSync\.appex/);
  assert.match(openLog, new RegExp(`-gj ${appDir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`));
});

test('uninstall script removes packaged files and preserves user data by default', async () => {
  const homeDir = await createTempDir('goto-uninstall-home-');
  const installRoot = await createTempDir('goto-uninstall-install-');
  const appsRoot = await createTempDir('goto-uninstall-apps-');
  const binRoot = await createTempDir('goto-uninstall-bin-');
  const fakeBinDir = await createTempDir('goto-uninstall-fakebin-');
  const scriptPath = path.join(projectRoot, 'scripts/uninstall.sh');
  const appPath = path.join(appsRoot, 'Goto.app');
  const extensionPath = path.join(appPath, 'Contents', 'PlugIns', 'GotoFinderSync.appex');
  const installPrefix = path.join(installRoot, 'goto');
  const gotoSymlink = path.join(binRoot, 'goto');
  const installShellSymlink = path.join(binRoot, 'goto-install-shell');
  const uninstallSymlink = path.join(binRoot, 'goto-uninstall');
  const registryPath = path.join(homeDir, '.goto');
  const settingsPath = path.join(homeDir, '.goto-settings');
  const zshrcPath = path.join(homeDir, '.zshrc');
  const bashrcPath = path.join(homeDir, '.bashrc');
  const pluginkitLogPath = path.join(fakeBinDir, 'pluginkit.log');
  const pkgutilLogPath = path.join(fakeBinDir, 'pkgutil.log');

  await fs.mkdir(path.join(installPrefix, 'scripts'), { recursive: true });
  await fs.mkdir(extensionPath, { recursive: true });
  await fs.writeFile(path.join(installPrefix, 'scripts', 'install-shell.sh'), '#!/bin/sh\n');
  await writeExecutable(path.join(fakeBinDir, 'pluginkit'), `#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"${pluginkitLogPath}\"\n`);
  await writeExecutable(path.join(fakeBinDir, 'pkgutil'), `#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"${pkgutilLogPath}\"\n`);
  await writeExecutable(path.join(fakeBinDir, 'pkill'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'killall'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'dscl'), `#!/bin/sh\nprintf 'NFSHomeDirectory: %s\\n' \"${homeDir}\"\n`);
  await writeExecutable(path.join(fakeBinDir, 'stat'), '#!/bin/sh\nprintf \'%s\\n\' test-user\n');
  await fs.symlink(path.join(installPrefix, 'bin', 'goto.js'), gotoSymlink).catch(() => {});
  await fs.symlink(path.join(installPrefix, 'scripts', 'install-shell.sh'), installShellSymlink).catch(() => {});
  await fs.symlink(scriptPath, uninstallSymlink).catch(() => {});
  await fs.writeFile(registryPath, '/tmp/project\n');
  await fs.writeFile(settingsPath, '{"finder":{"enabled":true}}\n');
  await fs.writeFile(
    zshrcPath,
    `# >>> goto >>>\nsource "${installPrefix}/shell/goto.zsh"\n# <<< goto <<<\n# keep me\n# >>> goto >>>\nsource "${cliRoot}/shell/goto.zsh"\n# <<< goto <<<\n`
  );
  await fs.writeFile(
    bashrcPath,
    `# >>> goto >>>\nsource "${installPrefix}/shell/goto.bash"\n# <<< goto <<<\nexport PATH="$PATH:/tmp"\n`
  );

  const result = await runProcess('bash', [scriptPath], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_UNINSTALL_ALLOW_NON_ROOT: '1',
      GOTO_INSTALL_PREFIX: installPrefix,
      GOTO_BIN_PREFIX: binRoot,
      GOTO_APP_PATH: appPath,
      GOTO_PLUGINKIT_BIN: path.join(fakeBinDir, 'pluginkit'),
      GOTO_PKGUTIL_BIN: path.join(fakeBinDir, 'pkgutil'),
      GOTO_PKILL_BIN: path.join(fakeBinDir, 'pkill'),
      GOTO_KILLALL_BIN: path.join(fakeBinDir, 'killall'),
      GOTO_DSCL_BIN: path.join(fakeBinDir, 'dscl'),
      GOTO_STAT_BIN: path.join(fakeBinDir, 'stat'),
      GOTO_TARGET_USER: 'test-user',
    },
  });

  const zshContents = await fs.readFile(zshrcPath, 'utf8');
  const bashContents = await fs.readFile(bashrcPath, 'utf8');
  const pluginkitLog = await fs.readFile(pluginkitLogPath, 'utf8');
  const pkgutilLog = await fs.readFile(pkgutilLogPath, 'utf8');

  assert.equal(result.code, 0);
  await assert.rejects(fs.access(appPath));
  await assert.rejects(fs.access(installPrefix));
  await assert.rejects(fs.access(gotoSymlink));
  await assert.rejects(fs.access(installShellSymlink));
  await assert.rejects(fs.access(uninstallSymlink));
  assert.match(zshContents, /# keep me/);
  assert.doesNotMatch(zshContents, new RegExp(`${installPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.zsh`));
  assert.match(zshContents, new RegExp(`${cliRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.zsh`));
  assert.match(bashContents, /export PATH/);
  assert.doesNotMatch(bashContents, new RegExp(`${installPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.bash`));
  await fs.access(registryPath);
  await fs.access(settingsPath);
  assert.match(pluginkitLog, /-e ignore -i dev\.goto\.finder\.findersync/);
  assert.match(pkgutilLog, /--forget dev\.goto\.installer/);
  assert.match(result.stdout, /Preserved user data files/);
});

test('uninstall script removes user data with --purge', async () => {
  const homeDir = await createTempDir('goto-uninstall-purge-home-');
  const installRoot = await createTempDir('goto-uninstall-purge-install-');
  const appsRoot = await createTempDir('goto-uninstall-purge-apps-');
  const binRoot = await createTempDir('goto-uninstall-purge-bin-');
  const fakeBinDir = await createTempDir('goto-uninstall-purge-fakebin-');
  const scriptPath = path.join(projectRoot, 'scripts/uninstall.sh');
  const installPrefix = path.join(installRoot, 'goto');
  const registryPath = path.join(homeDir, '.goto');
  const settingsPath = path.join(homeDir, '.goto-settings');

  await fs.mkdir(installPrefix, { recursive: true });
  await writeExecutable(path.join(fakeBinDir, 'pluginkit'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'pkgutil'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'pkill'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'killall'), '#!/bin/sh\nexit 0\n');
  await writeExecutable(path.join(fakeBinDir, 'dscl'), `#!/bin/sh\nprintf 'NFSHomeDirectory: %s\\n' \"${homeDir}\"\n`);
  await writeExecutable(path.join(fakeBinDir, 'stat'), '#!/bin/sh\nprintf \'%s\\n\' test-user\n');
  await fs.writeFile(registryPath, '/tmp/project\n');
  await fs.writeFile(settingsPath, '{"finder":{"enabled":true}}\n');

  const result = await runProcess('bash', [scriptPath, '--purge'], {
    cwd: projectRoot,
    env: {
      ...process.env,
      GOTO_UNINSTALL_ALLOW_NON_ROOT: '1',
      GOTO_INSTALL_PREFIX: installPrefix,
      GOTO_BIN_PREFIX: binRoot,
      GOTO_APP_PATH: path.join(appsRoot, 'Goto.app'),
      GOTO_PLUGINKIT_BIN: path.join(fakeBinDir, 'pluginkit'),
      GOTO_PKGUTIL_BIN: path.join(fakeBinDir, 'pkgutil'),
      GOTO_PKILL_BIN: path.join(fakeBinDir, 'pkill'),
      GOTO_KILLALL_BIN: path.join(fakeBinDir, 'killall'),
      GOTO_DSCL_BIN: path.join(fakeBinDir, 'dscl'),
      GOTO_STAT_BIN: path.join(fakeBinDir, 'stat'),
      GOTO_TARGET_USER: 'test-user',
    },
  });

  assert.equal(result.code, 0);
  await assert.rejects(fs.access(registryPath));
  await assert.rejects(fs.access(settingsPath));
  assert.match(result.stdout, /Removed user data files/);
});

test('bash and zsh wrappers pass through registry management commands', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const env = { ...process.env, HOME: homeDir };

  const bashResult = await runProcess(
    'bash',
    ['-c', `source "${path.join(cliRoot, 'shell/goto.bash')}" && goto -a "${projectDir}"`],
    { cwd: projectRoot, env }
  );
  const zshResult = await runProcess(
    'zsh',
    ['-c', `source "${path.join(cliRoot, 'shell/goto.zsh')}" && goto -a "${projectDir}"`],
    { cwd: projectRoot, env }
  );

  const entries = await readRegistry(homeDir);
  assert.equal(bashResult.code, 0);
  assert.equal(zshResult.code, 0);
  assert.match(bashResult.stdout, /Added:|Already saved:/);
  assert.match(zshResult.stdout, /Added:|Already saved:/);
  assert.deepEqual(entries, [await fs.realpath(projectDir)]);
});

test('bash and zsh wrappers only cd on successful no-arg selection', async () => {
  const fakeBinDir = await createTempDir('goto-fake-node-');
  const targetDir = await createTempDir('goto-target-');
  const fakeNodePath = path.join(fakeBinDir, 'node');
  const wrapperBash = path.join(cliRoot, 'shell/goto.bash');
  const wrapperZsh = path.join(cliRoot, 'shell/goto.zsh');

  await writeExecutable(
    fakeNodePath,
    `#!/bin/sh
if [ "$1" = "${cliPath}" ] && [ "$#" -eq 1 ]; then
  printf '%s\\n' "${targetDir}"
  exit 0
fi
exec "${process.execPath}" "$@"
`
  );

  const baseEnv = {
    ...process.env,
    PATH: `${fakeBinDir}:${process.env.PATH}`,
  };

  const bashResult = await runProcess(
    'bash',
    [
      '-c',
      `source "${wrapperBash}" && start="$PWD" && goto && printf '%s\\n%s\\n' "$start" "$PWD"`,
    ],
    { cwd: projectRoot, env: baseEnv }
  );
  const zshResult = await runProcess(
    'zsh',
    [
      '-c',
      `source "${wrapperZsh}" && start="$PWD" && goto && printf '%s\\n%s\\n' "$start" "$PWD"`,
    ],
    { cwd: projectRoot, env: baseEnv }
  );

  const bashLines = bashResult.stdout.trim().split('\n');
  const zshLines = zshResult.stdout.trim().split('\n');

  assert.equal(bashResult.code, 0);
  assert.equal(zshResult.code, 0);
  assert.equal(bashLines.at(-1), targetDir);
  assert.equal(zshLines.at(-1), targetDir);
});

test('bash and zsh wrappers leave the directory unchanged on cancel', async () => {
  const fakeBinDir = await createTempDir('goto-fake-node-cancel-');
  const fakeNodePath = path.join(fakeBinDir, 'node');
  const wrapperBash = path.join(cliRoot, 'shell/goto.bash');
  const wrapperZsh = path.join(cliRoot, 'shell/goto.zsh');

  await writeExecutable(
    fakeNodePath,
    `#!/bin/sh
if [ "$1" = "${cliPath}" ] && [ "$#" -eq 1 ]; then
  exit 1
fi
exec "${process.execPath}" "$@"
`
  );

  const baseEnv = {
    ...process.env,
    PATH: `${fakeBinDir}:${process.env.PATH}`,
  };

  const bashResult = await runProcess(
    'bash',
    [
      '-c',
      `source "${wrapperBash}" && start="$PWD" && goto || true && printf '%s\\n%s\\n' "$start" "$PWD"`,
    ],
    { cwd: projectRoot, env: baseEnv }
  );
  const zshResult = await runProcess(
    'zsh',
    [
      '-c',
      `source "${wrapperZsh}" && start="$PWD" && goto || true && printf '%s\\n%s\\n' "$start" "$PWD"`,
    ],
    { cwd: projectRoot, env: baseEnv }
  );

  const bashLines = bashResult.stdout.trim().split('\n');
  const zshLines = zshResult.stdout.trim().split('\n');

  assert.equal(bashResult.code, 0);
  assert.equal(zshResult.code, 0);
  assert.equal(bashLines.at(-2), bashLines.at(-1));
  assert.equal(zshLines.at(-2), zshLines.at(-1));
});
