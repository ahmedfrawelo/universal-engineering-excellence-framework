import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';

const [rootArgument] = process.argv.slice(2);
if (!rootArgument) throw new Error('Usage: batch-file-hashes.mjs <root>');

const root = path.resolve(rootArgument);
const relativePaths = (await new Promise((resolve, reject) => {
  const chunks = [];
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => chunks.push(chunk));
  process.stdin.on('end', () => resolve(chunks.join('').split(/\r?\n/u).filter(Boolean)));
  process.stdin.on('error', reject);
}));

const concurrency = Math.min(64, Math.max(4, Number.parseInt(process.env.UEEF_HASH_CONCURRENCY ?? '32', 10) || 32));
const hashes = new Array(relativePaths.length);
let cursor = 0;

async function worker() {
  while (cursor < relativePaths.length) {
    const index = cursor++;
    const relative = relativePaths[index];
    if (relative.split('/').includes('..') || path.isAbsolute(relative)) {
      throw new Error(`Unsafe relative path: ${relative}`);
    }
    const data = await fs.readFile(path.join(root, ...relative.split('/')));
    hashes[index] = crypto.createHash('sha256').update(data).digest('hex').toUpperCase();
  }
}

await Promise.all(Array.from({ length: Math.min(concurrency, relativePaths.length) }, worker));
process.stdout.write(`${hashes.join('\n')}\n`);
