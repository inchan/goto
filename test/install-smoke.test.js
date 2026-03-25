import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';

import { promises as fs } from 'node:fs';

import { cliPath, createTempDir, projectRoot, readRegistry, runProcess, writeExecutable } from './helpers.js';

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

test('uninstall script removes packaged files and preserves user data by default', async () => {
  const homeDir = await createTempDir('goto-uninstall-home-');
  const installRoot = await createTempDir('goto-uninstall-install-');
  const appsRoot = await createTempDir('goto-uninstall-apps-');
  const binRoot = await createTempDir('goto-uninstall-bin-');
  const fakeBinDir = await createTempDir('goto-uninstall-fakebin-');
  const scriptPath = path.join(projectRoot, 'scripts/uninstall.sh');
  const menuAppPath = path.join(appsRoot, 'GotoMenuBar.app');
  const finderAppPath = path.join(appsRoot, 'GotoFinder.app');
  const extensionPath = path.join(finderAppPath, 'Contents', 'PlugIns', 'GotoFinderSync.appex');
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
    `# >>> goto >>>\nsource "${installPrefix}/shell/goto.zsh"\n# <<< goto <<<\n# keep me\n# >>> goto >>>\nsource "${projectRoot}/shell/goto.zsh"\n# <<< goto <<<\n`
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
      GOTO_MENU_APP_PATH: menuAppPath,
      GOTO_FINDER_APP_PATH: finderAppPath,
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
  await assert.rejects(fs.access(menuAppPath));
  await assert.rejects(fs.access(finderAppPath));
  await assert.rejects(fs.access(installPrefix));
  await assert.rejects(fs.access(gotoSymlink));
  await assert.rejects(fs.access(installShellSymlink));
  await assert.rejects(fs.access(uninstallSymlink));
  assert.match(zshContents, /# keep me/);
  assert.doesNotMatch(zshContents, new RegExp(`${installPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.zsh`));
  assert.match(zshContents, new RegExp(`${projectRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}/shell/goto\\.zsh`));
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
      GOTO_MENU_APP_PATH: path.join(appsRoot, 'GotoMenuBar.app'),
      GOTO_FINDER_APP_PATH: path.join(appsRoot, 'GotoFinder.app'),
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
    ['-c', `source "${path.join(projectRoot, 'shell/goto.bash')}" && goto -a "${projectDir}"`],
    { cwd: projectRoot, env }
  );
  const zshResult = await runProcess(
    'zsh',
    ['-c', `source "${path.join(projectRoot, 'shell/goto.zsh')}" && goto -a "${projectDir}"`],
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
  const wrapperBash = path.join(projectRoot, 'shell/goto.bash');
  const wrapperZsh = path.join(projectRoot, 'shell/goto.zsh');

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
  const wrapperBash = path.join(projectRoot, 'shell/goto.bash');
  const wrapperZsh = path.join(projectRoot, 'shell/goto.zsh');

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
