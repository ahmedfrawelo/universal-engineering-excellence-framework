import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildFrameworkIndexes } from './generate-framework-indexes.mjs';

const root = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
for (const [file, expected] of buildFrameworkIndexes(root)) {
  if (!fs.existsSync(file)) throw new Error(`Missing generated index: ${path.relative(root, file)}`);
  const actual = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  if (actual !== expected) throw new Error(`Stale or incomplete generated index: ${path.relative(root, file)}`);
}

const compatibilityScorecard = fs.readFileSync(path.join(root, 'framework/28-scorecards/00-engineering-scorecard.md'), 'utf8');
if (!compatibilityScorecard.includes('(engineering-scorecard.md)')) throw new Error('Numbered engineering scorecard is not a compatibility redirect.');
console.log('Framework index tests passed');
