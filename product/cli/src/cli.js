import process from 'node:process';

import { runAdd } from './commands/add.js';
import { runRemove } from './commands/remove.js';
import { CliError, EXIT_CODES, printError, printHelp, printInfo, printVersion } from './output.js';
import { runSelect } from './select.js';

function parseArgs(argv) {
  if (argv.length === 0) {
    return { type: 'select' };
  }

  const [first, second, third, ...rest] = argv;

  if (first === '--help' || first === '-h') {
    if (second || third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }
    return { type: 'help' };
  }

  if (first === '--version') {
    if (second || third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }
    return { type: 'version' };
  }

  if (first === 'select') {
    if (second || third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }
    return { type: 'select' };
  }

  if (first === '-a') {
    if (second === '--children') {
      if (rest.length > 0) {
        throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
      }

      return { type: 'add-children', pathArg: third };
    }

    if (third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }

    return { type: 'add', pathArg: second };
  }

  if (first === '-A' || first === '--children') {
    if (third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }

    return { type: 'add-children', pathArg: second };
  }

  if (first === '-r') {
    if (third || rest.length > 0) {
      throw new CliError('too many arguments', { exitCode: EXIT_CODES.USAGE });
    }

    return { type: 'remove', pathArg: second };
  }

  throw new CliError(`unknown argument: ${first}`, {
    exitCode: EXIT_CODES.USAGE,
  });
}

export async function main(
  argv,
  {
    cwd = process.cwd(),
    env = process.env,
    stdout = process.stdout,
    stderr = process.stderr,
  } = {}
) {
  try {
    const parsed = parseArgs(argv);

    if (parsed.type === 'help') {
      printHelp(stdout);
      return EXIT_CODES.OK;
    }

    if (parsed.type === 'version') {
      printVersion(stdout);
      return EXIT_CODES.OK;
    }

    if (parsed.type === 'add') {
      const result = await runAdd(parsed.pathArg ?? cwd, { cwd, env });
      printInfo(result.stdout, stdout);
      return result.exitCode;
    }

    if (parsed.type === 'add-children') {
      const result = await runAdd(parsed.pathArg ?? cwd, { cwd, env }, { children: true });
      printInfo(result.stdout, stdout);
      return result.exitCode;
    }

    if (parsed.type === 'remove') {
      const result = await runRemove(parsed.pathArg ?? cwd, { cwd, env });
      printInfo(result.stdout, stdout);
      return result.exitCode;
    }

    const result = await runSelect({ env, stdout, stderr });

    if (result.stderr) {
      printError(result.stderr, stderr);
    }

    return result.exitCode;
  } catch (error) {
    if (error instanceof CliError) {
      printError(error.message, stderr);
      return error.exitCode;
    }

    printError(error.message, stderr);
    return EXIT_CODES.ERROR;
  }
}
