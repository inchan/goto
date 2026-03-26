import process from 'node:process';

import { VERSION } from './version.js';

export const EXIT_CODES = {
  OK: 0,
  CANCELLED: 1,
  ERROR: 1,
  USAGE: 2,
};

export class CliError extends Error {
  constructor(message, { exitCode = EXIT_CODES.ERROR } = {}) {
    super(message);
    this.name = 'CliError';
    this.exitCode = exitCode;
  }
}

export function printHelp(stream = process.stdout) {
  stream.write(
    [
      'goto',
      '',
      'Usage:',
      '  goto                     Open the saved project picker',
      '  goto -a [PATH]           Add the current directory or PATH to ~/.goto',
      '  goto -A [PATH]           Add direct child directories from PATH or the current directory',
      '  goto --children [PATH]   Same as -A',
      '  goto -r [PATH]           Remove the current directory or PATH from ~/.goto',
      '  goto --help              Show this help',
      '  goto --version           Show the current version',
      '',
      'Notes:',
      '  Source the goto shell integration script to make `goto` change',
      '  the current shell directory after selection.',
      '',
    ].join('\n')
  );
}

export function printVersion(stream = process.stdout) {
  stream.write(`${VERSION}\n`);
}

export function printInfo(message, stream = process.stdout) {
  stream.write(`${message}\n`);
}

export function printError(message, stream = process.stderr) {
  stream.write(`goto: ${message}\n`);
}
