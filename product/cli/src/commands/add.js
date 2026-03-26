import { addChildRegistryEntries, addRegistryEntry } from '../registry.js';

function pluralize(count, singular, plural = `${singular}s`) {
  return count === 1 ? singular : plural;
}

function formatBulkAddResult(result) {
  const lines = [];
  const totalChildren = result.added.length + result.existing.length;

  if (totalChildren === 0) {
    return `No direct child directories found in: ${result.rootPath}`;
  }

  if (result.added.length > 0) {
    lines.push(
      `Added ${result.added.length} ${pluralize(result.added.length, 'directory', 'directories')} from: ${result.rootPath}`
    );
  } else {
    lines.push(`No new directories added from: ${result.rootPath}`);
  }

  if (result.existing.length > 0) {
    lines.push(
      `Already saved ${result.existing.length} ${pluralize(result.existing.length, 'directory', 'directories')}`
    );
  }

  return lines.join('\n');
}

export async function runAdd(pathArg, context, options = {}) {
  if (options.children) {
    const result = await addChildRegistryEntries(pathArg, context);

    return {
      exitCode: 0,
      stdout: formatBulkAddResult(result),
    };
  }

  const result = await addRegistryEntry(pathArg, context);

  if (result.status === 'exists') {
    return {
      exitCode: 0,
      stdout: `Already saved: ${result.path}`,
    };
  }

  return {
    exitCode: 0,
    stdout: `Added: ${result.path}`,
  };
}
