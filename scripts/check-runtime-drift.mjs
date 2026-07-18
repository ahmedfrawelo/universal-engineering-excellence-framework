import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { releaseFiles, walkFiles } from './runtime-file-policy.mjs';

const [sourceArgument, runtimeArgument] = process.argv.slice(2);
if (!sourceArgument || !runtimeArgument) throw new Error('Usage: check-runtime-drift.mjs <source> <runtime>');
const source = fs.realpathSync(sourceArgument);
const runtime = fs.realpathSync(runtimeArgument);
const sourceFiles = releaseFiles(source);

const hash = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const mismatches = [];
for (const relative of sourceFiles) {
  const sourceFile = path.join(source, ...relative.split('/'));
  const runtimeFile = path.join(runtime, ...relative.split('/'));
  if (!fs.existsSync(runtimeFile)) mismatches.push(`Missing runtime: ${relative}`);
  else if (hash(sourceFile) !== hash(runtimeFile)) mismatches.push(`Different: ${relative}`);
}
for (const relative of walkFiles(runtime)) {
  if (relative !== 'UEEF-LOADER.md' && !sourceFiles.includes(relative)) mismatches.push(`Extra runtime: ${relative}`);
}
const loader = path.join(runtime, 'UEEF-LOADER.md');
if (!fs.existsSync(loader)) mismatches.push('Missing runtime: UEEF-LOADER.md');
else {
  const loaderText = fs.readFileSync(loader, 'utf8');
  for (const term of ['Agent and model routing:','environment-bootstrap','Loaded: boot-loader, core-system']) {
    if (!loaderText.includes(term)) mismatches.push(`Runtime loader missing contract: ${term}`);
  }
  const statePath = path.join(path.dirname(runtime), 'UEEF-ACTIVE.json');
  if (fs.existsSync(statePath)) {
    const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    if (path.resolve(state.runtimePath || '') === runtime && typeof state.runtimeLoaderSha256 === 'string' && hash(loader) !== state.runtimeLoaderSha256) {
      mismatches.push('Different: UEEF-LOADER.md');
    }
  }
}
if (mismatches.length) {
  console.error(mismatches.join('\n'));
  process.exit(1);
}
console.log(`Runtime drift check passed (${sourceFiles.length} files)`);
