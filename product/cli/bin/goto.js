#!/usr/bin/env node

import process from 'node:process';

import { main } from '../src/cli.js';

const exitCode = await main(process.argv.slice(2));
process.exit(exitCode);
