import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { version } = require('../package.json');

export const VERSION = version;
export const MACOS_BUNDLE_VERSION = version.split('-')[0].split('+')[0];
