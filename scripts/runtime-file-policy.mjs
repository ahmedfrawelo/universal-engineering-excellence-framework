import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

export const ownedDirectories = new Set(['framework','scripts','docs','examples','tools','assets','config']);
export const ownedRootFiles = new Set(['.gitattributes','.gitignore','BUILD_PROGRESS.md','CHANGELOG.md','CODE_OF_CONDUCT.md','CONTRIBUTING.md','INSTALL.md','LICENSE','QUICK_START.md','README.md','ROADMAP.md','SECURITY.md','VERSION.md','release-manifest.json']);

export const isOwned = (relative, includeLoader = false) => {
  if (!relative || relative.split('/').includes('..')) return false;
  if (includeLoader && relative === 'UEEF-LOADER.md') return true;
  return ownedRootFiles.has(relative) || ownedDirectories.has(relative.split('/')[0]);
};

export const isSensitive = (relative) => {
  const name = path.posix.basename(relative).toLowerCase();
  return name === '.env' || name.startsWith('.env.') || ['credentials.json','service-account.json','id_rsa','id_ed25519'].includes(name) ||
    /^service-account-.*\.json$/.test(name) || ['.pem','.key','.pfx','.p12'].includes(path.posix.extname(name));
};

export function walkFiles(root) {
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.name === '.git') continue;
      const full = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`Runtime policy rejects symbolic link: ${path.relative(root, full)}`);
      if (entry.isDirectory()) visit(full);
      else if (entry.isFile()) files.push(path.relative(root, full).split(path.sep).join('/'));
    }
  };
  visit(root);
  return files;
}

function assertNoSymbolicPath(source, relative) {
  let current = source;
  for (const segment of relative.split('/')) {
    current = path.join(current, segment);
    if (!fs.existsSync(current)) throw new Error(`Release file is missing: ${relative}`);
    if (fs.lstatSync(current).isSymbolicLink()) throw new Error(`Runtime policy rejects symbolic link: ${relative}`);
  }
}

export function releaseFiles(source, { includeLoader = false } = {}) {
  let files;
  if (fs.existsSync(path.join(source, '.git'))) {
    files = execFileSync('git', ['-C', source, 'ls-files', '--recurse-submodules'], { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean);
  } else {
    files = walkFiles(source);
  }
  files = [...new Set(files.map((file) => file.replaceAll('\\', '/')).filter((file) => isOwned(file, includeLoader)))].sort();
  for (const relative of files) {
    if (isSensitive(relative)) throw new Error(`Sensitive file cannot enter the runtime: ${relative}`);
    const full = path.join(source, ...relative.split('/'));
    assertNoSymbolicPath(source, relative);
    if (!fs.existsSync(full) || !fs.statSync(full).isFile()) throw new Error(`Release file is missing: ${relative}`);
  }
  return files;
}

export function copyReleaseFiles(source, destination, options = {}) {
  source = fs.realpathSync(source);
  destination = path.resolve(destination);
  const sourcePrefix = `${source}${path.sep}`;
  const destinationPrefix = `${destination}${path.sep}`;
  if (destination === path.parse(destination).root || destination === source || destination.startsWith(sourcePrefix) || source.startsWith(destinationPrefix)) {
    throw new Error(`Refusing unsafe or overlapping release destination: ${destination}`);
  }
  if (fs.existsSync(destination)) {
    if (fs.lstatSync(destination).isSymbolicLink()) throw new Error(`Refusing symbolic-link release destination: ${destination}`);
    if (fs.readdirSync(destination).length) throw new Error(`Release destination must be empty: ${destination}`);
  } else fs.mkdirSync(destination, { recursive: true });
  for (const relative of releaseFiles(source, options)) {
    const target = path.join(destination, ...relative.split('/'));
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(path.join(source, ...relative.split('/')), target);
  }
}
