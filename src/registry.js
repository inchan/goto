import path from 'node:path';
import { promises as fs } from 'node:fs';

import {
  deriveProjectName,
  getRegistryPath,
  normalizePathString,
  normalizeRemovalTarget,
  resolveExistingDirectory,
} from './paths.js';

function compareProjectPaths(left, right) {
  const leftName = deriveProjectName(left).toLowerCase();
  const rightName = deriveProjectName(right).toLowerCase();

  if (leftName !== rightName) {
    return leftName.localeCompare(rightName);
  }

  return left.localeCompare(right);
}

function uniquePreservingOrder(entries) {
  return [...new Set(entries)];
}

async function canonicalizeForCompare(inputPath, options = {}) {
  const normalizedPath = normalizePathString(inputPath, options);

  try {
    const stat = await fs.stat(normalizedPath);

    if (stat.isDirectory()) {
      return fs.realpath(normalizedPath);
    }
  } catch {
    return normalizedPath;
  }

  return normalizedPath;
}

export async function readRegistry(env = process.env) {
  const registryPath = getRegistryPath(env);

  let raw;
  try {
    raw = await fs.readFile(registryPath, 'utf8');
  } catch (error) {
    if (error.code === 'ENOENT') {
      return [];
    }

    throw error;
  }

  return uniquePreservingOrder(raw.split('\n').map((line) => line.trim()).filter(Boolean));
}

export async function writeRegistry(entries, env = process.env) {
  const registryPath = getRegistryPath(env);
  const directory = path.dirname(registryPath);
  const tempPath = path.join(directory, `.goto.tmp-${process.pid}-${Date.now()}`);
  const normalizedEntries = uniquePreservingOrder(entries);
  const contents = normalizedEntries.length > 0 ? `${normalizedEntries.join('\n')}\n` : '';

  await fs.mkdir(directory, { recursive: true });
  await fs.writeFile(tempPath, contents, 'utf8');
  await fs.rename(tempPath, registryPath);
}

export async function addRegistryEntry(inputPath, options = {}) {
  const targetPath = await resolveExistingDirectory(inputPath, options);
  const entries = await readRegistry(options.env);

  for (const entry of entries) {
    if ((await canonicalizeForCompare(entry, options)) === targetPath) {
      return {
        status: 'exists',
        path: entry,
        entries,
      };
    }
  }

  const nextEntries = [...entries, targetPath];
  await writeRegistry(nextEntries, options.env);

  return {
    status: 'added',
    path: targetPath,
    entries: uniquePreservingOrder(nextEntries),
  };
}

export async function addChildRegistryEntries(inputPath, options = {}) {
  const rootPath = await resolveExistingDirectory(inputPath, options);
  const dirents = await fs.readdir(rootPath, { withFileTypes: true });
  const entries = await readRegistry(options.env);
  const nextEntries = [...entries];
  const added = [];
  const existing = [];

  const sortedDirents = [...dirents].sort((left, right) => left.name.localeCompare(right.name));

  for (const dirent of sortedDirents) {
    const childPath = path.join(rootPath, dirent.name);

    if (!dirent.isDirectory() && !dirent.isSymbolicLink()) {
      continue;
    }

    let canonicalChildPath;
    try {
      canonicalChildPath = await resolveExistingDirectory(childPath, options);
    } catch {
      continue;
    }

    let alreadySaved = false;
    for (const entry of nextEntries) {
      if ((await canonicalizeForCompare(entry, options)) === canonicalChildPath) {
        existing.push(entry);
        alreadySaved = true;
        break;
      }
    }

    if (alreadySaved) {
      continue;
    }

    nextEntries.push(canonicalChildPath);
    added.push(canonicalChildPath);
  }

  if (added.length > 0) {
    await writeRegistry(nextEntries, options.env);
  }

  return {
    status: added.length > 0 ? 'added-many' : 'unchanged-many',
    rootPath,
    added: added.sort(compareProjectPaths),
    existing: existing.sort(compareProjectPaths),
    entries: uniquePreservingOrder(nextEntries),
  };
}

export async function removeRegistryEntry(inputPath, options = {}) {
  const targetPath = await normalizeRemovalTarget(inputPath, options);
  const entries = await readRegistry(options.env);
  const normalizedTarget = await canonicalizeForCompare(targetPath, options);

  const keptEntries = [];
  let removedPath = null;

  for (const entry of entries) {
    const normalizedEntry = await canonicalizeForCompare(entry, options);

    if (entry === targetPath || normalizedEntry === normalizedTarget) {
      removedPath = entry;
      continue;
    }

    keptEntries.push(entry);
  }

  if (!removedPath) {
    return {
      status: 'missing',
      path: targetPath,
      entries,
    };
  }

  await writeRegistry(keptEntries, options.env);

  return {
    status: 'removed',
    path: removedPath,
    entries: keptEntries,
  };
}

export async function listRegistryProjects(env = process.env) {
  const entries = await readRegistry(env);

  const projects = await Promise.all(
    entries.map(async (projectPath) => {
      try {
        const stat = await fs.stat(projectPath);
        return {
          name: deriveProjectName(projectPath),
          path: projectPath,
          exists: stat.isDirectory(),
        };
      } catch {
        return {
          name: deriveProjectName(projectPath),
          path: projectPath,
          exists: false,
        };
      }
    })
  );

  return projects;
}

export async function promoteRegistryEntry(inputPath, options = {}) {
  const targetPath = await normalizeRemovalTarget(inputPath, options);
  const entries = await readRegistry(options.env);
  const normalizedTarget = await canonicalizeForCompare(targetPath, options);
  const remainingEntries = [];
  let promotedPath = null;

  for (const entry of entries) {
    const normalizedEntry = await canonicalizeForCompare(entry, options);

    if (!promotedPath && (entry === targetPath || normalizedEntry === normalizedTarget)) {
      promotedPath = entry;
      continue;
    }

    remainingEntries.push(entry);
  }

  if (!promotedPath) {
    return {
      status: 'missing',
      path: targetPath,
      entries,
    };
  }

  const nextEntries = [promotedPath, ...remainingEntries];

  if (entries[0] !== promotedPath) {
    await writeRegistry(nextEntries, options.env);
  }

  return {
    status: 'promoted',
    path: promotedPath,
    entries: nextEntries,
  };
}
