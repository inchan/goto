import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { promises as fs } from 'node:fs';

import { addRegistryEntry, promoteRegistryEntry, readRegistry, removeRegistryEntry, writeRegistry } from '../src/registry.js';
import { createTempDir } from './helpers.js';

test('writeRegistry de-duplicates while preserving the existing order', async () => {
  const homeDir = await createTempDir();
  const rootDir = await createTempDir();
  const env = { ...process.env, HOME: homeDir };
  const alpha = path.join(rootDir, 'alpha');
  const beta = path.join(rootDir, 'beta');

  await fs.mkdir(alpha);
  await fs.mkdir(beta);

  await writeRegistry([beta, alpha, beta], env);
  const entries = await readRegistry(env);

  assert.deepEqual(entries, [beta, alpha]);
});

test('addRegistryEntry stores canonical absolute paths and prevents duplicates', async () => {
  const homeDir = await createTempDir();
  const workspaceDir = await createTempDir();
  const nestedDir = path.join(workspaceDir, 'nested');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(nestedDir);

  const first = await addRegistryEntry(path.join(nestedDir, '..', 'nested'), {
    cwd: workspaceDir,
    env,
  });
  const second = await addRegistryEntry(nestedDir, {
    cwd: workspaceDir,
    env,
  });
  const entries = await readRegistry(env);

  assert.equal(first.status, 'added');
  assert.equal(second.status, 'exists');
  assert.equal(entries.length, 1);
  assert.equal(entries[0], await fs.realpath(nestedDir));
});

test('removeRegistryEntry removes stored entries and reports no-op for missing ones', async () => {
  const homeDir = await createTempDir();
  const workspaceDir = await createTempDir();
  const targetDir = path.join(workspaceDir, 'project');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(targetDir);
  await addRegistryEntry(targetDir, { cwd: workspaceDir, env });

  const removed = await removeRegistryEntry(targetDir, { cwd: workspaceDir, env });
  const missing = await removeRegistryEntry(targetDir, { cwd: workspaceDir, env });
  const entries = await readRegistry(env);

  assert.equal(removed.status, 'removed');
  assert.equal(missing.status, 'missing');
  assert.deepEqual(entries, []);
});

test('promoteRegistryEntry moves the selected project to the front', async () => {
  const homeDir = await createTempDir();
  const workspaceDir = await createTempDir();
  const alphaDir = path.join(workspaceDir, 'alpha');
  const betaDir = path.join(workspaceDir, 'beta');
  const gammaDir = path.join(workspaceDir, 'gamma');
  const env = { ...process.env, HOME: homeDir };

  await fs.mkdir(alphaDir);
  await fs.mkdir(betaDir);
  await fs.mkdir(gammaDir);
  await writeRegistry([alphaDir, betaDir, gammaDir], env);

  const result = await promoteRegistryEntry(gammaDir, { cwd: workspaceDir, env });
  const entries = await readRegistry(env);

  assert.equal(result.status, 'promoted');
  assert.deepEqual(entries, [gammaDir, alphaDir, betaDir]);
});
