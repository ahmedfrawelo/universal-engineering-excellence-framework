import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const frameworkRoot = path.resolve(process.argv[2] || path.join(import.meta.dirname, '..'));
const vendorRoot = path.join(frameworkRoot, 'vendor', 'repository-intelligence-engine');
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const manifest = readJson(path.join(vendorRoot, 'UEEF-VENDOR.json'));
const inventory = readJson(path.join(vendorRoot, 'UPSTREAM-FILES.json'));

if (inventory.commit !== manifest.upstream.commit || inventory.tree !== manifest.upstream.tree) {
  throw new Error('Vendor inventory revision does not match the vendor manifest.');
}
if (inventory.files.length !== manifest.upstream.trackedFiles) {
  throw new Error(`Vendor inventory count mismatch: ${inventory.files.length}`);
}

const modified = new Set(manifest.modifiedUpstreamPaths || []);
const expected = new Set(inventory.files.map((entry) => entry.path));
const added = new Set(manifest.ueefAddedPaths || []);
let exact = 0;
for (const entry of inventory.files) {
  if (entry.path.includes('..') || path.isAbsolute(entry.path)) throw new Error(`Unsafe inventory path: ${entry.path}`);
  const fullPath = path.join(vendorRoot, ...entry.path.split('/'));
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) throw new Error(`Vendored upstream file missing: ${entry.path}`);
  if (modified.has(entry.path)) continue;
  const body = fs.readFileSync(fullPath);
  const gitBlob = (content) => crypto.createHash('sha1').update(`blob ${content.length}\0`).update(content).digest('hex');
  const rawBlob = gitBlob(body);
  const normalizedBody = body.includes(0) ? body : Buffer.from(body.toString('binary').replaceAll('\r\n', '\n'), 'binary');
  const normalizedBlob = gitBlob(normalizedBody);
  if (rawBlob !== entry.blob && normalizedBlob !== entry.blob) throw new Error(`Vendored upstream file drifted without a modification record: ${entry.path}`);
  exact += 1;
}

function walk(directory, prefix = '') {
  const files = [];
  const generatedDirectories = new Set(['.venv', '.pytest_cache', '.hypothesis', '.ruff_cache', '.mypy_cache', '__pycache__', 'build', 'dist']);
  for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
    if (item.isDirectory() && (generatedDirectories.has(item.name) || item.name.endsWith('.egg-info'))) continue;
    const relative = prefix ? `${prefix}/${item.name}` : item.name;
    const full = path.join(directory, item.name);
    if (item.isDirectory()) files.push(...walk(full, relative));
    else if (item.isFile()) files.push(relative);
  }
  return files;
}

for (const relative of walk(vendorRoot)) {
  if (!expected.has(relative) && !added.has(relative)) throw new Error(`Unrecorded vendor file: ${relative}`);
}
for (const relative of added) {
  if (!fs.existsSync(path.join(vendorRoot, ...relative.split('/')))) throw new Error(`Recorded UEEF vendor file missing: ${relative}`);
}

process.stdout.write(JSON.stringify({
  status: 'PASS',
  upstreamFiles: inventory.files.length,
  exactUpstreamFiles: exact,
  modifiedUpstreamFiles: modified.size,
  ueefAddedFiles: added.size,
  nestedGit: fs.existsSync(path.join(vendorRoot, '.git')),
}) + '\n');
