import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const markdown = [];
const walk = (directory) => {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === '.git') continue;
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (entry.isFile() && entry.name.endsWith('.md')) markdown.push(full);
  }
};
walk(root);

const broken = new Set();
for (const file of markdown) {
  const content = fs.readFileSync(file, 'utf8');
  for (const match of content.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    let target = match[1].trim().replace(/^<|>$/g, '');
    if (/^(https?:\/\/|mailto:|#)/i.test(target)) continue;
    target = decodeURIComponent(target.split('#')[0]);
    if (!target) continue;
    const resolved = path.resolve(path.dirname(file), target);
    if (!fs.existsSync(resolved)) broken.add(`${path.relative(root, file)} -> ${target}`);
  }
  for (const match of content.matchAll(/(?:^|[^A-Za-z0-9_.-])((?:framework|examples|docs)\/[A-Za-z0-9_./-]+\.md)(?:#[A-Za-z0-9_-]+)?/g)) {
    const target = match[1];
    if (!fs.existsSync(path.join(root, ...target.split('/')))) broken.add(`${path.relative(root, file)} -> ${target}`);
  }
}
if (broken.size) throw new Error(`Broken documentation paths:\n${[...broken].sort().join('\n')}`);
console.log('Documentation link tests passed');
