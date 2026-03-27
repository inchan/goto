import os from 'node:os';
import path from 'node:path';
import { promises as fs } from 'node:fs';
import { spawn } from 'node:child_process';

export const cliRoot = path.resolve(new URL('..', import.meta.url).pathname);
export const projectRoot = path.resolve(new URL('../../..', import.meta.url).pathname);
export const cliPath = path.join(cliRoot, 'bin', 'goto.js');

export async function createTempDir(prefix = 'goto-test-') {
  return fs.mkdtemp(path.join(os.tmpdir(), prefix));
}

export async function runProcess(command, args, { cwd = cliRoot, env = process.env } = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk;
    });

    child.on('error', reject);
    child.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
  });
}

export function runCli(args, options = {}) {
  return runProcess(process.execPath, [cliPath, ...args], options);
}

export async function readRegistry(homeDir) {
  const registryPath = path.join(homeDir, '.goto');

  try {
    const raw = await fs.readFile(registryPath, 'utf8');
    return raw.split('\n').map((line) => line.trim()).filter(Boolean);
  } catch (error) {
    if (error.code === 'ENOENT') {
      return [];
    }

    throw error;
  }
}

export async function writeExecutable(filePath, contents) {
  await fs.writeFile(filePath, contents, { mode: 0o755 });
}
