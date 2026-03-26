import fs from 'node:fs';
import readline from 'node:readline';
import tty from 'node:tty';

import { listRegistryProjects, promoteRegistryEntry } from './registry.js';

const ANSI = {
  reset: '\u001B[0m',
  bold: '\u001B[1m',
  dim: '\u001B[2m',
  cyan: '\u001B[36m',
  yellow: '\u001B[33m',
  red: '\u001B[31m',
  reverse: '\u001B[7m',
  hideCursor: '\u001B[?25l',
  showCursor: '\u001B[?25h',
  enterAlt: '\u001B[?1049h',
  exitAlt: '\u001B[?1049l',
  clear: '\u001B[2J',
  home: '\u001B[H',
};

function paint(enabled, ...tokens) {
  if (!enabled) {
    return tokens.join('');
  }

  return tokens.join('');
}

function truncateMiddle(text, maxWidth) {
  if (text.length <= maxWidth || maxWidth < 8) {
    return text;
  }

  const head = Math.max(3, Math.floor((maxWidth - 1) / 2));
  const tail = Math.max(3, maxWidth - head - 1);
  return `${text.slice(0, head)}…${text.slice(-tail)}`;
}

function openUiTty() {
  try {
    const inputFd = fs.openSync('/dev/tty', 'r');
    const outputFd = fs.openSync('/dev/tty', 'w');

    return {
      inputFd,
      outputFd,
      input: new tty.ReadStream(inputFd),
      output: new tty.WriteStream(outputFd),
      owned: true,
    };
  } catch {
    if (process.stdin.isTTY && process.stderr.isTTY) {
      return {
        input: process.stdin,
        output: process.stderr,
        owned: false,
      };
    }

    return null;
  }
}

function closeUiTty(ui) {
  if (!ui || !ui.owned) {
    return;
  }

  ui.input.destroy();
  ui.output.destroy();
}

function render(ui, projects, selectedIndex, message = '') {
  const color = !process.env.NO_COLOR;
  const width = Math.max(48, ui.output.columns || 80);
  const body = [];

  body.push(
    paint(color, ANSI.bold, ANSI.cyan, 'goto', ANSI.reset),
    paint(color, ANSI.dim, '  saved project picker', ANSI.reset),
    '',
    paint(color, ANSI.dim, 'Pick a project and press Enter to jump into it.', ANSI.reset),
    ''
  );

  if (projects.length === 0) {
    body.push('  No saved projects yet.');
    body.push('');
    body.push(paint(color, ANSI.dim, '  Use `goto -a` to save the current directory first.', ANSI.reset));
  } else {
    for (const [index, project] of projects.entries()) {
      const selected = index === selectedIndex;
      const prefix = selected ? paint(color, ANSI.cyan, '›', ANSI.reset) : ' ';
      const label = project.exists
        ? project.name
        : paint(color, ANSI.red, project.name, ANSI.reset);
      const decoratedLabel = selected
        ? paint(color, ANSI.reverse, ` ${label} `, ANSI.reset)
        : paint(color, ANSI.bold, label, ANSI.reset);
      const pathWidth = width - 6;
      const renderedPath = truncateMiddle(project.path, pathWidth);
      const suffix = project.exists
        ? ''
        : paint(color, ANSI.yellow, '  missing', ANSI.reset);

      body.push(` ${prefix} ${decoratedLabel}${suffix}`);
      body.push(`   ${paint(color, ANSI.dim, renderedPath, ANSI.reset)}`);
      body.push('');
    }
  }

  body.push(paint(color, ANSI.dim, '↑/↓ move  Enter open  Esc cancel', ANSI.reset));

  if (message) {
    body.push('');
    body.push(paint(color, ANSI.yellow, message, ANSI.reset));
  }

  ui.output.write(`${ANSI.clear}${ANSI.home}${body.join('\n')}`);
}

export async function runSelect({ env = process.env, stdout = process.stdout } = {}) {
  const projects = await listRegistryProjects(env);

  if (projects.length === 0) {
    return {
      exitCode: 1,
      stderr: 'No saved projects. Run `goto -a` in a project folder first.',
    };
  }

  const ui = openUiTty();

  if (!ui) {
    return {
      exitCode: 1,
      stderr: 'Interactive picker requires a TTY. Source the goto shell integration script for jump mode.',
    };
  }

  let selectedIndex = Math.max(0, projects.findIndex((project) => project.exists));
  let message = '';
  let finishing = false;

  return new Promise((resolve, reject) => {
    const cleanup = () => {
      ui.output.write(`${ANSI.reset}${ANSI.showCursor}${ANSI.exitAlt}`);
      if (ui.input.isRaw) {
        ui.input.setRawMode(false);
      }
      closeUiTty(ui);
    };

    const finish = (result) => {
      cleanup();
      resolve(result);
    };

    readline.emitKeypressEvents(ui.input);
    ui.input.setRawMode(true);
    ui.input.resume();
    ui.output.write(`${ANSI.enterAlt}${ANSI.hideCursor}`);
    render(ui, projects, selectedIndex, message);

    ui.input.on('keypress', (_character, key) => {
      if (!key) {
        return;
      }

      if (key.name === 'up') {
        selectedIndex = (selectedIndex - 1 + projects.length) % projects.length;
        message = '';
        render(ui, projects, selectedIndex, message);
        return;
      }

      if (key.name === 'down') {
        selectedIndex = (selectedIndex + 1) % projects.length;
        message = '';
        render(ui, projects, selectedIndex, message);
        return;
      }

      if (key.name === 'return') {
        if (finishing) {
          return;
        }

        const project = projects[selectedIndex];

        if (!project.exists) {
          message = 'This path no longer exists. Remove it with `goto -r PATH`.';
          render(ui, projects, selectedIndex, message);
          return;
        }

        finishing = true;

        (async () => {
          try {
            await promoteRegistryEntry(project.path, { env });
          } catch {
            // Do not block the jump flow if MRU persistence fails.
          }

          stdout.write(`${project.path}\n`);
          finish({
            exitCode: 0,
          });
        })();
        return;
      }

      if (key.name === 'escape' || (key.ctrl && key.name === 'c')) {
        finish({
          exitCode: 1,
        });
      }
    });

    ui.input.on('error', (error) => {
      cleanup();
      reject(error);
    });
  });
}
