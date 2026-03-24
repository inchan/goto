import { removeRegistryEntry } from '../registry.js';

export async function runRemove(pathArg, context) {
  const result = await removeRegistryEntry(pathArg, context);

  if (result.status === 'missing') {
    return {
      exitCode: 0,
      stdout: `Not saved: ${result.path}`,
    };
  }

  return {
    exitCode: 0,
    stdout: `Removed: ${result.path}`,
  };
}
