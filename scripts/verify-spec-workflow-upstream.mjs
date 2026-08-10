import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const expectedAlgorithm = 'sha256(sorted-utf8(uint32be(path-length) + path-utf8 + uint64be(content-length) + raw-bytes))';
const expectedSnapshotPath = 'upstream/spec-kit';
const expectedModificationPolicy = 'None inside snapshotPath. UEEF-owned code lives under ueef/.';
const manifestKeys = [
  'aggregateAlgorithm',
  'commit',
  'commitDate',
  'included',
  'license',
  'project',
  'release',
  'repository',
  'schemaVersion',
  'snapshotAggregateSha256',
  'snapshotFileCount',
  'snapshotPath',
  'ueefModifications',
];
const windowsReservedName = /^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)/i;

function parseArguments(argv) {
  let engineRoot = path.join(repositoryRoot, 'engines', 'spec-workflow');
  let json = false;
  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--engine-root') {
      const value = argv[index + 1];
      if (!value) throw new Error('--engine-root requires a value');
      engineRoot = path.resolve(value);
      index += 1;
    } else if (argument === '--json') {
      json = true;
    } else {
      throw new Error(`unsupported argument: ${argument}`);
    }
  }
  return { engineRoot, json };
}

function isWithin(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function sameResolvedPath(left, right) {
  const normalizedLeft = path.normalize(left);
  const normalizedRight = path.normalize(right);
  return process.platform === 'win32'
    ? normalizedLeft.toLowerCase() === normalizedRight.toLowerCase()
    : normalizedLeft === normalizedRight;
}

function assertPlainPath(absolute, engineRealPath, label) {
  const stat = fs.lstatSync(absolute, { bigint: true });
  if (stat.isSymbolicLink()) throw new Error(`${label} contains a link or reparse point: ${absolute}`);
  const real = fs.realpathSync.native(absolute);
  if (!isWithin(engineRealPath, real)) throw new Error(`${label} escapes the engine root: ${absolute}`);
  if (!sameResolvedPath(path.resolve(absolute), real)) {
    throw new Error(`${label} resolves through a link or reparse point: ${absolute}`);
  }
  return stat;
}

function sameIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino;
}

function sameStableMetadata(left, right) {
  return sameIdentity(left, right)
    && left.size === right.size
    && left.mtimeNs === right.mtimeNs
    && left.ctimeNs === right.ctimeNs
    && left.nlink === right.nlink;
}

function readStableFile(absolute, engineRealPath, label) {
  const before = assertPlainPath(absolute, engineRealPath, label);
  if (!before.isFile()) throw new Error(`${label} contains a non-regular file: ${absolute}`);
  if (before.nlink !== 1n) throw new Error(`${label} contains a hard-linked file: ${absolute}`);
  const descriptor = fs.openSync(absolute, fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW ?? 0));
  try {
    const opened = fs.fstatSync(descriptor, { bigint: true });
    if (!opened.isFile() || !sameStableMetadata(opened, before)) {
      throw new Error(`${label} file changed identity while opening: ${absolute}`);
    }
    const content = fs.readFileSync(descriptor);
    const afterRead = fs.fstatSync(descriptor, { bigint: true });
    if (!sameStableMetadata(afterRead, opened)) {
      throw new Error(`${label} file changed while reading: ${absolute}`);
    }
    const afterPath = assertPlainPath(absolute, engineRealPath, label);
    if (!afterPath.isFile() || !sameStableMetadata(afterPath, opened)) {
      throw new Error(`${label} pathname changed while reading: ${absolute}`);
    }
    return { content, stat: afterPath };
  } finally {
    fs.closeSync(descriptor);
  }
}

function validatePortableRelativePath(value, { allowTrailingSlash = false, label = 'path' } = {}) {
  if (typeof value !== 'string' || !value || value.startsWith('/') || value.includes('\\') || value.includes(':')) {
    throw new Error(`${label} must be a safe relative POSIX path`);
  }
  const hasTrailingSlash = value.endsWith('/');
  if (hasTrailingSlash && !allowTrailingSlash) throw new Error(`${label} must identify a file`);
  const normalized = hasTrailingSlash ? value.slice(0, -1) : value;
  if (!normalized || normalized !== normalized.normalize('NFC')) {
    throw new Error(`${label} must use Unicode NFC normalization`);
  }
  const parts = normalized.split('/');
  for (const part of parts) {
    if (!part || part === '.' || part === '..') throw new Error(`${label} contains an unsafe segment`);
    if (/[\u0000-\u001f\u007f<>"|?*]/u.test(part)) throw new Error(`${label} is not portable to Windows`);
    if (/[. ]$/u.test(part) || windowsReservedName.test(part)) throw new Error(`${label} is not portable to Windows`);
  }
  return { normalized, hasTrailingSlash };
}

function compareUtf8(left, right) {
  return Buffer.compare(Buffer.from(left, 'utf8'), Buffer.from(right, 'utf8'));
}

function enumerateSnapshot(snapshotRoot, engineRealPath) {
  const files = [];
  const directories = [];
  const collisionKeys = new Map();
  function registerPortablePath(relative, kind) {
    validatePortableRelativePath(relative, { label: `snapshot ${kind} path` });
    const collisionKey = relative.normalize('NFC').toLowerCase();
    const prior = collisionKeys.get(collisionKey);
    if (prior && prior !== relative) {
      throw new Error(`snapshot contains paths that collide on portable filesystems: ${prior}, ${relative}`);
    }
    collisionKeys.set(collisionKey, relative);
  }
  function walk(directory) {
    const directoryStat = assertPlainPath(directory, engineRealPath, 'snapshot');
    if (!directoryStat.isDirectory()) throw new Error(`snapshot path is not a directory: ${directory}`);
    const directoryRelative = path.relative(snapshotRoot, directory).split(path.sep).join('/');
    if (directoryRelative) registerPortablePath(directoryRelative, 'directory');
    directories.push({ absolute: directory, relative: directoryRelative, stat: directoryStat });
    const entries = fs.readdirSync(directory, { withFileTypes: true });
    if (directoryRelative && entries.length === 0) {
      throw new Error(`snapshot contains an untracked empty directory: ${directoryRelative}`);
    }
    for (const entry of entries) {
      const absolute = path.join(directory, entry.name);
      const stat = assertPlainPath(absolute, engineRealPath, 'snapshot');
      if (stat.isDirectory()) {
        walk(absolute);
      } else if (stat.isFile()) {
        const relative = path.relative(snapshotRoot, absolute).split(path.sep).join('/');
        registerPortablePath(relative, 'file');
        if (stat.nlink !== 1n) throw new Error(`snapshot contains a hard-linked file: ${absolute}`);
        files.push({ absolute, relative, stat });
      } else {
        throw new Error(`snapshot contains an unsupported filesystem entry: ${absolute}`);
      }
    }
  }
  walk(snapshotRoot);
  files.sort((left, right) => compareUtf8(left.relative, right.relative));
  directories.sort((left, right) => compareUtf8(left.relative, right.relative));
  return { files, directories };
}

function assertSameSnapshot(before, after) {
  for (const kind of ['files', 'directories']) {
    const prior = before[kind];
    const current = after[kind];
    if (prior.length !== current.length) throw new Error(`snapshot ${kind} changed while hashing`);
    for (let index = 0; index < prior.length; index += 1) {
      if (prior[index].relative !== current[index].relative || !sameStableMetadata(prior[index].stat, current[index].stat)) {
        throw new Error(`snapshot ${kind} changed while hashing: ${prior[index].relative || '.'}`);
      }
    }
  }
}

function validIsoDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value;
}

function validateManifest(manifest) {
  if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) throw new Error('UPSTREAM.json must contain an object');
  const keys = Object.keys(manifest).sort();
  if (keys.length !== manifestKeys.length || keys.some((key, index) => key !== manifestKeys[index])) {
    throw new Error('UPSTREAM.json must contain exactly the schema-version-2 keys');
  }
  if (manifest.schemaVersion !== 2) throw new Error('UPSTREAM.json schemaVersion must be 2');
  if (manifest.project !== 'GitHub Spec Kit') throw new Error('UPSTREAM.json project must be GitHub Spec Kit');
  if (manifest.repository !== 'https://github.com/github/spec-kit') throw new Error('UPSTREAM.json repository is not the official Spec Kit repository');
  if (typeof manifest.release !== 'string' || !/^v\d+\.\d+\.\d+$/.test(manifest.release)) throw new Error('UPSTREAM.json release must be a stable semantic version tag');
  if (typeof manifest.commit !== 'string' || !/^[0-9a-f]{40}$/.test(manifest.commit)) throw new Error('UPSTREAM.json commit must be a lowercase full SHA-1');
  if (!validIsoDate(manifest.commitDate)) throw new Error('UPSTREAM.json commitDate must be a valid YYYY-MM-DD date');
  if (manifest.license !== 'MIT') throw new Error('UPSTREAM.json license must be MIT');
  if (manifest.snapshotPath !== expectedSnapshotPath) throw new Error(`UPSTREAM.json snapshotPath must be ${expectedSnapshotPath}`);
  if (!Number.isSafeInteger(manifest.snapshotFileCount) || manifest.snapshotFileCount < 1) throw new Error('UPSTREAM.json snapshotFileCount must be a positive integer');
  if (typeof manifest.snapshotAggregateSha256 !== 'string' || !/^[0-9a-f]{64}$/.test(manifest.snapshotAggregateSha256)) throw new Error('UPSTREAM.json snapshotAggregateSha256 must be lowercase SHA-256');
  if (manifest.aggregateAlgorithm !== expectedAlgorithm) throw new Error('UPSTREAM.json aggregateAlgorithm is unsupported');
  if (manifest.ueefModifications !== expectedModificationPolicy) throw new Error('UPSTREAM.json ueefModifications policy is invalid');
  if (!Array.isArray(manifest.included) || manifest.included.length < 1) throw new Error('UPSTREAM.json included must be a non-empty array');
  const seen = new Set();
  const priorItems = [];
  let previous;
  for (const item of manifest.included) {
    validatePortableRelativePath(item, { allowTrailingSlash: true, label: 'UPSTREAM.json included path' });
    const collisionKey = (item.endsWith('/') ? item.slice(0, -1) : item).normalize('NFC').toLowerCase();
    if (seen.has(collisionKey)) throw new Error('UPSTREAM.json included paths must be unique');
    const itemBase = (item.endsWith('/') ? item : `${item}/`).toLowerCase();
    if (priorItems.some((prior) => {
      const priorBase = (prior.endsWith('/') ? prior : `${prior}/`).toLowerCase();
      const foldedItem = item.toLowerCase();
      const foldedPrior = prior.toLowerCase();
      return foldedItem.startsWith(priorBase) || foldedPrior.startsWith(itemBase);
    })) {
      throw new Error('UPSTREAM.json included paths must not overlap');
    }
    if (previous !== undefined && compareUtf8(previous, item) >= 0) throw new Error('UPSTREAM.json included paths must be UTF-8 sorted');
    seen.add(collisionKey);
    priorItems.push(item);
    previous = item;
  }
}

function uint32(value) {
  const output = Buffer.alloc(4);
  output.writeUInt32BE(value);
  return output;
}

function uint64(value) {
  const output = Buffer.alloc(8);
  output.writeBigUInt64BE(BigInt(value));
  return output;
}

export function calculateAggregate(records) {
  const hash = crypto.createHash('sha256');
  const sorted = [...records].sort((left, right) => compareUtf8(left.relative, right.relative));
  for (const record of sorted) {
    const relative = Buffer.from(record.relative, 'utf8');
    const content = Buffer.isBuffer(record.content) ? record.content : Buffer.from(record.content);
    hash.update(uint32(relative.length));
    hash.update(relative);
    hash.update(uint64(content.length));
    hash.update(content);
  }
  return hash.digest('hex');
}

export function verifySpecWorkflowUpstream(engineRoot) {
  const engine = path.resolve(engineRoot);
  const engineStat = fs.lstatSync(engine, { bigint: true });
  if (!engineStat.isDirectory() || engineStat.isSymbolicLink()) throw new Error('engine root must be a real directory');
  const engineRealPath = fs.realpathSync.native(engine);
  if (!sameResolvedPath(engine, engineRealPath)) throw new Error('engine root must not resolve through a link or reparse point');
  const manifestPath = path.join(engine, 'UPSTREAM.json');
  const initialManifest = readStableFile(manifestPath, engineRealPath, 'manifest');
  const manifest = JSON.parse(initialManifest.content.toString('utf8'));
  validateManifest(manifest);
  const canonicalManifest = `${JSON.stringify(manifest, null, 2)}\n`;
  if (initialManifest.content.toString('utf8').replaceAll('\r\n', '\n') !== canonicalManifest) {
    throw new Error('UPSTREAM.json must use canonical schema-version-2 JSON without duplicate keys');
  }

  const snapshotRoot = path.resolve(engine, ...manifest.snapshotPath.split('/'));
  if (!isWithin(engine, snapshotRoot)) throw new Error('UPSTREAM.json snapshotPath escapes the engine root');
  const snapshotRealPath = fs.realpathSync.native(snapshotRoot);
  if (!isWithin(engineRealPath, snapshotRealPath)) throw new Error('snapshot real path escapes the engine root');
  if (!sameResolvedPath(snapshotRoot, snapshotRealPath)) throw new Error('snapshot root resolves through a link or reparse point');
  const initialSnapshot = enumerateSnapshot(snapshotRoot, engineRealPath);
  if (initialSnapshot.files.length !== manifest.snapshotFileCount) {
    throw new Error(`snapshot file count mismatch: expected ${manifest.snapshotFileCount}, observed ${initialSnapshot.files.length}`);
  }

  const records = initialSnapshot.files.map((file) => ({
    relative: file.relative,
    content: readStableFile(file.absolute, engineRealPath, 'snapshot').content,
  }));
  const actualDigest = calculateAggregate(records);
  if (actualDigest !== manifest.snapshotAggregateSha256) {
    throw new Error(`snapshot digest mismatch: expected ${manifest.snapshotAggregateSha256}, observed ${actualDigest}`);
  }

  const available = new Set(initialSnapshot.files.map((file) => file.relative));
  for (const included of manifest.included) {
    const prefix = included.endsWith('/') ? included : `${included}/`;
    if (!available.has(included) && !initialSnapshot.files.some((file) => file.relative.startsWith(prefix))) {
      throw new Error(`UPSTREAM.json included path is missing from the snapshot: ${included}`);
    }
  }
  for (const file of initialSnapshot.files) {
    if (!manifest.included.some((included) => file.relative === included || (included.endsWith('/') && file.relative.startsWith(included)))) {
      throw new Error(`snapshot file is not covered by UPSTREAM.json included paths: ${file.relative}`);
    }
  }

  const finalSnapshot = enumerateSnapshot(snapshotRoot, engineRealPath);
  assertSameSnapshot(initialSnapshot, finalSnapshot);
  const finalManifest = readStableFile(manifestPath, engineRealPath, 'manifest');
  if (!initialManifest.content.equals(finalManifest.content) || !sameStableMetadata(initialManifest.stat, finalManifest.stat)) {
    throw new Error('UPSTREAM.json changed during verification');
  }
  return {
    schemaVersion: 2,
    status: 'PASS',
    project: manifest.project,
    release: manifest.release,
    commit: manifest.commit,
    snapshotPath: manifest.snapshotPath,
    snapshotFileCount: initialSnapshot.files.length,
    snapshotAggregateSha256: actualDigest,
    aggregateAlgorithm: expectedAlgorithm,
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const options = parseArguments(process.argv.slice(2));
    const result = verifySpecWorkflowUpstream(options.engineRoot);
    if (options.json) process.stdout.write(`${JSON.stringify(result)}\n`);
    else console.log(`Spec workflow upstream integrity PASS: ${result.release} ${result.snapshotAggregateSha256}`);
  } catch (error) {
    console.error(`Spec workflow upstream integrity failed: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  }
}
