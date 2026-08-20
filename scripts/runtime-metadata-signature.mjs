import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const [sourceRootArg, runtimeRootArg, expectedLoaderHash = ''] = process.argv.slice(2);
if (!sourceRootArg || !runtimeRootArg) throw new Error('Usage: runtime-metadata-signature.mjs <source-root> <runtime-root> [loader-hash]');
const sourceRoot = path.resolve(sourceRootArg);
const runtimeRoot = path.resolve(runtimeRootArg);
const relativePaths = fs.readFileSync(0, 'utf8').split(/\r?\n/u).filter(Boolean);
const generated = new Set(['.venv', 'build', 'graphifyy.egg-info', 'ueef_spec_workflow.egg-info', '__pycache__', '.pytest_cache', '.hypothesis', '.ruff_cache', '.mypy_cache']);
const records = [];

function statRecord(prefix, root, relative) {
  try {
    const stat = fs.lstatSync(path.join(root, ...relative.split('/')), { bigint: true });
    records.push(`${prefix}|${relative}|${stat.dev}|${stat.ino}|${stat.mode}|${stat.size}|${stat.mtimeNs}|${stat.ctimeNs}|${stat.birthtimeNs}`);
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    records.push(`${prefix}|${relative}|MISSING`);
  }
}

for (const relative of relativePaths) {
  statRecord('S', sourceRoot, relative);
  statRecord('R', runtimeRoot, relative);
}

function walk(directory, prefix = '') {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const relative = prefix ? `${prefix}/${entry.name}` : entry.name;
    const segments = relative.split('/');
    if (segments[0] === 'engines' && segments.length >= 3 && generated.has(segments[2])) continue;
    statRecord(entry.isDirectory() ? 'D' : 'X', runtimeRoot, relative);
    if (entry.isDirectory() && !fs.lstatSync(path.join(directory, entry.name)).isSymbolicLink()) walk(path.join(directory, entry.name), relative);
  }
}
walk(runtimeRoot);
records.push(`L|${expectedLoaderHash}`);
records.sort();
const signature = crypto.createHash('sha256').update(records.join('\n')).digest('hex').toUpperCase();
process.stdout.write(`${signature}\n`);
