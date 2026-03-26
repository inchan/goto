import os from 'node:os';
import path from 'node:path';
import { promises as fs } from 'node:fs';

import { CliError, EXIT_CODES } from './output.js';

export function resolveHome(env = process.env) {
  return env.HOME || os.homedir();
}

export function getRegistryPath(env = process.env) {
  return path.join(resolveHome(env), '.goto');
}

export function expandHomePath(inputPath, env = process.env) {
  if (!inputPath || inputPath === '~') {
    return resolveHome(env);
  }

  if (inputPath.startsWith('~/')) {
    return path.join(resolveHome(env), inputPath.slice(2));
  }

  return inputPath;
}

export function normalizePathString(inputPath, { cwd = process.cwd(), env = process.env } = {}) {
  return path.resolve(cwd, expandHomePath(inputPath, env));
}

export async function resolveExistingDirectory(inputPath, options = {}) {
  const candidate = normalizePathString(inputPath, options);

  let stat;
  try {
    stat = await fs.stat(candidate);
  } catch {
    throw new CliError(`directory does not exist: ${candidate}`, {
      exitCode: EXIT_CODES.ERROR,
    });
  }

  if (!stat.isDirectory()) {
    throw new CliError(`not a directory: ${candidate}`, {
      exitCode: EXIT_CODES.ERROR,
    });
  }

  return fs.realpath(candidate);
}

export async function normalizeRemovalTarget(inputPath, options = {}) {
  const candidate = normalizePathString(inputPath, options);

  try {
    const stat = await fs.stat(candidate);
    if (stat.isDirectory()) {
      return fs.realpath(candidate);
    }
  } catch {
    return candidate;
  }

  throw new CliError(`not a directory: ${candidate}`, {
    exitCode: EXIT_CODES.ERROR,
  });
}

export function deriveProjectName(projectPath) {
  const base = path.basename(projectPath);
  return base || projectPath;
}
