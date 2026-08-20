import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { calculateAggregate } from './verify-spec-workflow-upstream.mjs';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const verifier = path.join(repositoryRoot, 'scripts', 'verify-spec-workflow-upstream.mjs');
const boundaryVerifier = path.join(repositoryRoot, 'scripts', 'verify-spec-workflow-boundary.mjs');
const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-spec-upstream-'));
const algorithm = 'sha256(sorted-utf8(uint32be(path-length) + path-utf8 + uint64be(content-length) + raw-bytes))';

function enumerate(root) {
  const records = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.isFile()) {
        records.push({
          relative: path.relative(root, absolute).split(path.sep).join('/'),
          content: fs.readFileSync(absolute),
        });
      }
    }
  }
  walk(root);
  return records;
}

function digest(root) {
  const records = enumerate(root);
  return { fileCount: records.length, sha256: calculateAggregate(records) };
}

function fixture(name = 'engine') {
  const engineRoot = path.join(sandbox, name);
  const snapshot = path.join(engineRoot, 'upstream', 'spec-kit');
  fs.mkdirSync(path.join(snapshot, 'src', 'unicodé'), { recursive: true });
  fs.writeFileSync(path.join(snapshot, 'LICENSE'), 'MIT\n', 'utf8');
  fs.writeFileSync(path.join(snapshot, 'src', 'unicodé', 'binary.bin'), Buffer.from([0, 255, 10, 13]));
  const current = digest(snapshot);
  const manifest = {
    schemaVersion: 2,
    project: 'GitHub Spec Kit',
    repository: 'https://github.com/github/spec-kit',
    release: 'v0.16.1',
    commit: 'a'.repeat(40),
    commitDate: '2026-08-07',
    license: 'MIT',
    snapshotPath: 'upstream/spec-kit',
    snapshotFileCount: current.fileCount,
    snapshotAggregateSha256: current.sha256,
    aggregateAlgorithm: algorithm,
    included: ['LICENSE', 'src/'],
    ueefModifications: 'None inside snapshotPath. UEEF-owned code lives under ueef/.',
  };
  fs.writeFileSync(path.join(engineRoot, 'UPSTREAM.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  return { engineRoot, snapshot, manifest };
}

function run(engineRoot) {
  return spawnSync(process.execPath, [verifier, '--engine-root', engineRoot, '--json'], {
    cwd: repositoryRoot,
    encoding: 'utf8',
  });
}

function writeManifest(engineRoot, manifest) {
  fs.writeFileSync(path.join(engineRoot, 'UPSTREAM.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
}

function updateDigest(snapshot, engineRoot, manifest) {
  const current = digest(snapshot);
  const updated = {
    ...manifest,
    snapshotFileCount: current.fileCount,
    snapshotAggregateSha256: current.sha256,
  };
  writeManifest(engineRoot, updated);
  return updated;
}

function expectFailure(engineRoot, pattern) {
  const result = run(engineRoot);
  assert.notEqual(result.status, 0, result.stdout);
  assert.match(result.stderr, pattern);
}

try {
  {
    const boundary = spawnSync(process.execPath, [boundaryVerifier, repositoryRoot], { cwd: repositoryRoot, encoding: 'utf8' });
    assert.equal(boundary.status, 0, boundary.stderr);
    assert.equal(JSON.parse(boundary.stdout).status, 'PASS');

    const boundaryFixture = path.join(sandbox, 'boundary-fixture');
    fs.mkdirSync(path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef'), { recursive: true });
    fs.writeFileSync(path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'), "from '../../../upstream/spec-kit/src' import unsafe\n", 'utf8');
    const rejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(rejected.status, 0, 'synthetic production dependency on Spec Kit must fail');
    assert.match(rejected.stderr, /must not import or execute/u);

    fs.writeFileSync(
      path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
      "Path('engines/spec-workflow/upstream/spec-kit/LICENSE').read_text()\n",
      'utf8',
    );
    const directReadRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(directReadRejected.status, 0, 'synthetic direct read of Spec Kit must fail');

    fs.writeFileSync(
      path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
      "Path('upstream' + '/spec-kit/LICENSE').read_text()\n",
      'utf8',
    );
    const assembledReadRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(assembledReadRejected.status, 0, 'synthetic assembled read of Spec Kit must fail');

    const misleadingDirectory = path.join(boundaryFixture, 'framework', 'testimony');
    fs.mkdirSync(misleadingDirectory, { recursive: true });
    fs.writeFileSync(path.join(misleadingDirectory, 'testament.py'), "Path('upstream/spec-kit/LICENSE').read_text()\n", 'utf8');
    const misleadingNameRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(misleadingNameRejected.status, 0, 'production files with test-like names must still be scanned');

    fs.rmSync(path.join(boundaryFixture, 'framework'), { recursive: true, force: true });
    fs.writeFileSync(
      path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
      "p='up'+'stream'+'/'+'spec'+'-'+'kit'+'/LICENSE'; open(p).read()\n",
      'utf8',
    );
    const fragmentedReadRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(fragmentedReadRejected.status, 0, 'fragmented snapshot path must fail');

    fs.writeFileSync(
      path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
      'p="upstream/spec\\u002dkit/LICENSE"; open(p).read()\n',
      'utf8',
    );
    const escapedReadRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(escapedReadRejected.status, 0, 'escaped snapshot path must fail');

    for (const escapedPath of ['upstream/spec\\055kit/LICENSE', 'upstream/spec\\N{HYPHEN-MINUS}kit/LICENSE']) {
      fs.writeFileSync(
        path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
        `p=${JSON.stringify(escapedPath)}; open(p).read()\n`,
        'utf8',
      );
      const pythonEscapeRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
      assert.notEqual(pythonEscapeRejected.status, 0, `Python escape must fail: ${escapedPath}`);
    }

    fs.writeFileSync(
      path.join(boundaryFixture, 'engines', 'spec-workflow', 'ueef', 'runtime.py'),
      "a='up'; b='stream'; c='spec'; d='kit'; open(a+b+'/'+c+'-'+d+'/LICENSE').read()\n",
      'utf8',
    );
    const distributedFragmentsRejected = spawnSync(process.execPath, [boundaryVerifier, boundaryFixture], { encoding: 'utf8' });
    assert.notEqual(distributedFragmentsRejected.status, 0, 'distributed snapshot path fragments must fail');
  }

  {
    const { engineRoot } = fixture('valid');
    const first = run(engineRoot);
    const second = run(engineRoot);
    assert.equal(first.status, 0, first.stderr);
    assert.equal(second.status, 0, second.stderr);
    assert.deepEqual(JSON.parse(first.stdout), JSON.parse(second.stdout));
    assert.equal(JSON.parse(first.stdout).schemaVersion, 2);
  }

  {
    const ambiguousA = [
      { relative: 'a', content: Buffer.alloc(0) },
      { relative: 'm', content: Buffer.from('z\0') },
    ];
    const ambiguousB = [
      { relative: 'a', content: Buffer.from('m\0') },
      { relative: 'z', content: Buffer.alloc(0) },
    ];
    const oldDigest = (records) => {
      const hash = crypto.createHash('sha256');
      for (const record of records) hash.update(record.relative).update(Buffer.from([0])).update(record.content);
      return hash.digest('hex');
    };
    assert.equal(oldDigest(ambiguousA), oldDigest(ambiguousB));
    assert.notEqual(calculateAggregate(ambiguousA), calculateAggregate(ambiguousB));
  }

  {
    const { engineRoot, snapshot } = fixture('tamper');
    fs.appendFileSync(path.join(snapshot, 'LICENSE'), 'tampered', 'utf8');
    expectFailure(engineRoot, /digest mismatch/i);
  }

  {
    const { engineRoot, snapshot } = fixture('extra');
    fs.writeFileSync(path.join(snapshot, 'unexpected.txt'), 'extra', 'utf8');
    expectFailure(engineRoot, /file count mismatch/i);
  }

  for (const unsafe of ['../outside', 'C:/absolute', '/absolute', 'upstream\\spec-kit']) {
    const { engineRoot, manifest } = fixture(`unsafe-${crypto.randomUUID()}`);
    writeManifest(engineRoot, { ...manifest, snapshotPath: unsafe });
    expectFailure(engineRoot, /snapshotPath/i);
  }

  for (const included of ['bad:name', 'CON', 'trailing.']) {
    const { engineRoot, manifest } = fixture(`portable-${crypto.randomUUID()}`);
    writeManifest(engineRoot, { ...manifest, included: ['LICENSE', included, 'src/'].sort() });
    expectFailure(engineRoot, /included path|portable to Windows/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-extra-key');
    writeManifest(engineRoot, { ...manifest, unexpected: true });
    expectFailure(engineRoot, /exactly the schema-version-2 keys/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-duplicate-key');
    const canonical = `${JSON.stringify(manifest, null, 2)}\n`;
    const duplicated = canonical.replace('  "schemaVersion": 2,', '  "schemaVersion": 1,\n  "schemaVersion": 2,');
    fs.writeFileSync(path.join(engineRoot, 'UPSTREAM.json'), duplicated, 'utf8');
    expectFailure(engineRoot, /canonical schema-version-2 JSON|duplicate keys/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-missing-key');
    const { commitDate: _omitted, ...missing } = manifest;
    writeManifest(engineRoot, missing);
    expectFailure(engineRoot, /exactly the schema-version-2 keys/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-invalid-date');
    writeManifest(engineRoot, { ...manifest, commitDate: '2026-02-30' });
    expectFailure(engineRoot, /valid YYYY-MM-DD/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-duplicate-included');
    writeManifest(engineRoot, { ...manifest, included: ['LICENSE', 'LICENSE', 'src/'] });
    expectFailure(engineRoot, /unique/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-overlapping-included');
    writeManifest(engineRoot, { ...manifest, included: ['LICENSE', 'src/', 'src/unicodé/'] });
    expectFailure(engineRoot, /must not overlap/i);
  }

  {
    const { engineRoot, manifest } = fixture('manifest-uncovered');
    writeManifest(engineRoot, { ...manifest, included: ['LICENSE'] });
    expectFailure(engineRoot, /not covered/i);
  }

  {
    const { engineRoot, snapshot, manifest } = fixture('nfd');
    const nfdName = `caf${String.fromCharCode(0x65, 0x301)}.txt`;
    fs.writeFileSync(path.join(snapshot, nfdName), 'nfd', 'utf8');
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /NFC normalization/i);
  }

  if (process.platform !== 'win32') {
    const { engineRoot, snapshot, manifest } = fixture('case-collision');
    fs.writeFileSync(path.join(snapshot, 'case.txt'), 'lower', 'utf8');
    fs.writeFileSync(path.join(snapshot, 'CASE.txt'), 'upper', 'utf8');
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /collide on portable filesystems/i);
  }

  if (process.platform !== 'win32') {
    const { engineRoot, snapshot, manifest } = fixture('directory-case-collision');
    fs.mkdirSync(path.join(snapshot, 'Dir'));
    fs.mkdirSync(path.join(snapshot, 'dir'));
    fs.writeFileSync(path.join(snapshot, 'Dir', 'one.txt'), 'one', 'utf8');
    fs.writeFileSync(path.join(snapshot, 'dir', 'two.txt'), 'two', 'utf8');
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /collide on portable filesystems/i);
  }

  {
    const { engineRoot, snapshot, manifest } = fixture('empty-directory');
    fs.mkdirSync(path.join(snapshot, 'empty'));
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /untracked empty directory/i);
  }

  {
    const { engineRoot, snapshot, manifest } = fixture('hardlink');
    const external = path.join(engineRoot, 'external.txt');
    fs.writeFileSync(external, 'shared', 'utf8');
    fs.linkSync(external, path.join(snapshot, 'hard-linked.txt'));
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /hard-linked/i);
  }

  {
    const { engineRoot, snapshot, manifest } = fixture('file-link');
    const external = path.join(engineRoot, 'external.txt');
    fs.writeFileSync(external, 'external', 'utf8');
    try {
      fs.symlinkSync(external, path.join(snapshot, 'linked.txt'), 'file');
      updateDigest(snapshot, engineRoot, manifest);
      expectFailure(engineRoot, /link|reparse/i);
    } catch (error) {
      if (!(error instanceof Error) || !('code' in error) || error.code !== 'EPERM') throw error;
    }
  }

  {
    const { engineRoot, snapshot, manifest } = fixture('directory-link');
    const target = path.join(engineRoot, 'external');
    fs.mkdirSync(target);
    fs.writeFileSync(path.join(target, 'payload.txt'), 'external', 'utf8');
    fs.symlinkSync(target, path.join(snapshot, 'linked'), process.platform === 'win32' ? 'junction' : 'dir');
    updateDigest(snapshot, engineRoot, manifest);
    expectFailure(engineRoot, /link|reparse/i);
  }

  console.log('Spec workflow upstream integrity tests passed');
} finally {
  fs.rmSync(sandbox, { recursive: true, force: true });
}
