import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { promises as fs } from 'node:fs';

import { createTempDir, readRegistry, runCli } from './helpers.js';

test('goto -a uses the current directory when no path is provided', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const result = await runCli(['-a'], {
    cwd: projectDir,
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  const entries = await readRegistry(homeDir);
  assert.equal(result.code, 0);
  assert.match(result.stdout, /Added:/);
  assert.equal(result.stderr, '');
  assert.deepEqual(entries, [await fs.realpath(projectDir)]);
});

test('goto -A adds only direct child directories from the target root', async () => {
  const homeDir = await createTempDir();
  const rootDir = await createTempDir();
  const alphaDir = path.join(rootDir, 'alpha');
  const betaDir = path.join(rootDir, 'beta');
  const nestedDir = path.join(alphaDir, 'nested');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(alphaDir);
  await fs.mkdir(betaDir);
  await fs.mkdir(nestedDir, { recursive: true });
  await fs.writeFile(path.join(rootDir, 'notes.txt'), 'ignore me');

  const result = await runCli(['-A', rootDir], { env });
  const entries = await readRegistry(homeDir);

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Added 2 directories from:/);
  assert.equal(result.stderr, '');
  assert.deepEqual(entries, [await fs.realpath(alphaDir), await fs.realpath(betaDir)]);
});

test('goto --children defaults to the current directory', async () => {
  const homeDir = await createTempDir();
  const rootDir = await createTempDir();
  const projectOne = path.join(rootDir, 'project-one');
  const projectTwo = path.join(rootDir, 'project-two');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(projectOne);
  await fs.mkdir(projectTwo);

  const result = await runCli(['--children'], {
    cwd: rootDir,
    env,
  });
  const entries = await readRegistry(homeDir);

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Added 2 directories from:/);
  assert.deepEqual(entries, [await fs.realpath(projectOne), await fs.realpath(projectTwo)]);
});

test('goto -A reports already-saved child directories without duplicating them', async () => {
  const homeDir = await createTempDir();
  const rootDir = await createTempDir();
  const alphaDir = path.join(rootDir, 'alpha');
  const betaDir = path.join(rootDir, 'beta');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(alphaDir);
  await fs.mkdir(betaDir);

  await runCli(['-A', rootDir], { env });
  const secondRun = await runCli(['-A', rootDir], { env });
  const entries = await readRegistry(homeDir);

  assert.equal(secondRun.code, 0);
  assert.match(secondRun.stdout, /No new directories added from:/);
  assert.match(secondRun.stdout, /Already saved 2 directories/);
  assert.equal(entries.length, 2);
});

test('duplicate add is idempotent and keeps stdout/stderr contract clean', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const env = { ...process.env, HOME: homeDir };

  await runCli(['-a', projectDir], { env });
  const duplicate = await runCli(['-a', projectDir], { env });
  const entries = await readRegistry(homeDir);

  assert.equal(duplicate.code, 0);
  assert.match(duplicate.stdout, /Already saved:/);
  assert.equal(duplicate.stderr, '');
  assert.equal(entries.length, 1);
});

test('goto -r removes the current directory when no path is provided', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const env = { ...process.env, HOME: homeDir };

  await runCli(['-a'], { cwd: projectDir, env });
  const removed = await runCli(['-r'], { cwd: projectDir, env });
  const entries = await readRegistry(homeDir);

  assert.equal(removed.code, 0);
  assert.match(removed.stdout, /Removed:/);
  assert.equal(removed.stderr, '');
  assert.deepEqual(entries, []);
});

test('remove of a non-registered path is a clear no-op', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const result = await runCli(['-r', projectDir], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Not saved:/);
  assert.equal(result.stderr, '');
});

test('invalid add path fails with stderr output and no registry writes', async () => {
  const homeDir = await createTempDir();
  const missingPath = path.join(await createTempDir(), 'missing-project');
  const result = await runCli(['-a', missingPath], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  const entries = await readRegistry(homeDir);
  assert.equal(result.code, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /directory does not exist/);
  assert.deepEqual(entries, []);
});

test('select with saved projects but no tty reports the shell-integration requirement', async () => {
  const homeDir = await createTempDir();
  const projectDir = await createTempDir();
  const env = { ...process.env, HOME: homeDir };

  await runCli(['-a', projectDir], { env });
  const result = await runCli([], { env });

  assert.equal(result.code, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /Interactive picker requires a TTY/);
});
