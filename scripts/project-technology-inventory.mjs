#!/usr/bin/env node
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { basename, join, relative, resolve } from 'node:path';

const root = resolve(process.argv[2] || process.cwd());
const ignored = new Set(['.git', 'node_modules', 'vendor', 'dist', 'build', 'coverage', '.next', '.nuxt', 'bin', 'obj']);
const manifestPatterns = [
  /^release-manifest\.json$/,
  /^package\.json$/, /^package-lock\.json$/, /^pnpm-lock\.yaml$/, /^yarn\.lock$/, /^bun\.lockb?$/,
  /^global\.json$/, /\.csproj$/, /\.fsproj$/, /^Directory\.Packages\.props$/,
  /^requirements.*\.txt$/, /^pyproject\.toml$/, /^poetry\.lock$/, /^Pipfile(?:\.lock)?$/,
  /^pom\.xml$/, /^build\.gradle(?:\.kts)?$/, /^gradle-wrapper\.properties$/,
  /^go\.mod$/, /^go\.sum$/, /^Cargo\.toml$/, /^Cargo\.lock$/,
  /^Gemfile(?:\.lock)?$/, /^composer\.json$/, /^composer\.lock$/,
  /^Dockerfile(?:\..+)?$/, /^compose\.ya?ml$/,
];

function walk(dir, files = []) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory() && ignored.has(entry.name)) continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) walk(path, files);
    else if (manifestPatterns.some((pattern) => pattern.test(entry.name)) || path.includes(`${join('.github', 'workflows')}`)) files.push(path);
  }
  return files;
}

function parseJson(path) {
  try { return JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, '')); }
  catch (error) { return { parseError: error.message }; }
}

function ecosystem(name) {
  if (name === 'release-manifest.json') return 'ueef';
  if (/^(package|pnpm|yarn|bun)/.test(name)) return 'node';
  if (/\.(cs|fs)proj$|^global\.json$|^Directory\.Packages/.test(name)) return 'dotnet';
  if (/^(requirements|pyproject|poetry|Pipfile)/.test(name)) return 'python';
  if (/^(pom|build\.gradle|gradle-wrapper)/.test(name)) return 'java';
  if (/^go\./.test(name)) return 'go';
  if (/^Cargo\./.test(name)) return 'rust';
  if (/^Gemfile/.test(name)) return 'ruby';
  if (/^composer\./.test(name)) return 'php';
  if (/^(Dockerfile|compose\.)/.test(name)) return 'container';
  if (/\.ya?ml$/.test(name)) return 'ci';
  return 'unknown';
}

function details(path) {
  const name = basename(path);
  if (name === 'package.json') {
    const json = parseJson(path);
    if (json.parseError) return { parseError: json.parseError };
    return {
      packageManager: json.packageManager || null,
      engines: json.engines || {},
      dependencies: json.dependencies || {},
      devDependencies: json.devDependencies || {},
      peerDependencies: json.peerDependencies || {},
    };
  }
  if (name === 'release-manifest.json' || name === 'global.json' || name === 'composer.json') return parseJson(path);
  const text = readFileSync(path, 'utf8');
  if (/\.(cs|fs)proj$|^Directory\.Packages\.props$/.test(name)) {
    return {
      targetFrameworks: [...text.matchAll(/<TargetFrameworks?>([^<]+)</g)].map((m) => m[1]),
      packages: [...text.matchAll(/<PackageReference\s+Include="([^"]+)"(?:\s+Version="([^"]+)")?/g)].map((m) => ({ name: m[1], version: m[2] || null })),
    };
  }
  if (/^requirements.*\.txt$/.test(name)) {
    return { packages: text.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#')) };
  }
  if (name === 'go.mod') {
    return { module: text.match(/^module\s+(.+)$/m)?.[1] || null, go: text.match(/^go\s+(.+)$/m)?.[1] || null };
  }
  if (/^Dockerfile/.test(name)) return { baseImages: [...text.matchAll(/^FROM\s+([^\s]+)/gim)].map((m) => m[1]) };
  if (/\.ya?ml$/.test(name)) return { actions: [...text.matchAll(/uses:\s*([^\s#]+)/g)].map((m) => m[1]) };
  return {};
}

if (!statSync(root).isDirectory()) throw new Error(`Inventory root is not a directory: ${root}`);
const entries = walk(root).sort().map((path) => ({
  path: relative(root, path).replaceAll('\\', '/'),
  ecosystem: ecosystem(basename(path)),
  details: details(path),
}));
const ecosystems = [...new Set(entries.map((entry) => entry.ecosystem))].sort();
process.stdout.write(`${JSON.stringify({ root: '<project-root>', generatedAt: new Date().toISOString(), ecosystems, entries }, null, 2)}\n`);
