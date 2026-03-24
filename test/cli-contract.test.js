import test from 'node:test';
import assert from 'node:assert/strict';

import { createTempDir, runCli } from './helpers.js';

test('help prints usage to stdout and exits successfully', async () => {
  const homeDir = await createTempDir();
  const result = await runCli(['--help'], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /Usage:/);
  assert.match(result.stdout, /goto -A \[PATH\]/);
  assert.equal(result.stderr, '');
});

test('version prints to stdout', async () => {
  const homeDir = await createTempDir();
  const result = await runCli(['--version'], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 0);
  assert.match(result.stdout, /^0\.1\.0/m);
  assert.equal(result.stderr, '');
});

test('unknown arguments fail with usage exit code and stderr output', async () => {
  const homeDir = await createTempDir();
  const result = await runCli(['--wat'], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 2);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /unknown argument/);
});

test('select without saved projects fails cleanly without stdout noise', async () => {
  const homeDir = await createTempDir();
  const result = await runCli([], {
    env: {
      ...process.env,
      HOME: homeDir,
    },
  });

  assert.equal(result.code, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /No saved projects/);
});
