import fs from 'node:fs';
import path from 'node:path';
import { copyReleaseFiles } from './runtime-file-policy.mjs';

const [sourceArgument, destinationArgument, loaderFlag] = process.argv.slice(2);
if (!sourceArgument || !destinationArgument) throw new Error('Usage: copy-release-files.mjs <source> <destination> [--include-loader]');
const source = fs.realpathSync(sourceArgument);
const destination = path.resolve(destinationArgument);
copyReleaseFiles(source, destination, { includeLoader: loaderFlag === '--include-loader' });
console.log(`Release files copied to ${destination}`);
