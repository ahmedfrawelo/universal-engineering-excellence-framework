import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildFrameworkIndexes, discoverPackDirectories, packId } from './generate-framework-indexes.mjs';

const root = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const frameworkRoot = path.join(root, 'framework');
for (const [file, expected] of buildFrameworkIndexes(root)) {
  if (!fs.existsSync(file)) throw new Error(`Missing generated index: ${path.relative(root, file)}`);
  const actual = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
  if (actual !== expected) throw new Error(`Stale or incomplete generated index: ${path.relative(root, file)}`);
}

const packNames = discoverPackDirectories(frameworkRoot)
  .map((packDirectory) => packId(frameworkRoot, packDirectory))
  .sort((a, b) => a.localeCompare(b));
const domainMapPath = path.join(frameworkRoot, '_domains/INVENTORY.md');
const domainMap = fs.readFileSync(domainMapPath, 'utf8');
for (const pack of packNames) {
  const matches = domainMap.match(new RegExp(`\\[\\\`${pack}\\\`\\]`, 'g')) ?? [];
  if (matches.length !== 1) throw new Error(`Domain map must list ${pack} exactly once; found ${matches.length}`);
}
if (!domainMap.includes('Pack paths come from the current framework structure')) throw new Error('Domain map must describe current structure-derived pack paths.');
const frontendDomain = fs.readFileSync(path.join(frameworkRoot, '_domains/product-ui-frontend-experience.md'), 'utf8');
if (!frontendDomain.includes('Use both when a frontend task needs behavior and production design evidence.')) throw new Error('Frontend domain must explain the two frontend owners.');

const compatibilityScorecard = fs.readFileSync(path.join(root, 'framework/12-delivery-quality/05-scorecards/00-engineering-scorecard.md'), 'utf8');
if (!compatibilityScorecard.includes('(engineering-scorecard.md)')) throw new Error('Numbered engineering scorecard is not a compatibility redirect.');
console.log('Framework index tests passed');
