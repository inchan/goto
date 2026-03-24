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
