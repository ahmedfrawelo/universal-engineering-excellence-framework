import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const defaultRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const repositoryRoot = path.resolve(process.argv[2] || defaultRoot);
const productionRoots = ['engines/spec-workflow/ueef', 'framework', 'scripts'];
const allowedScripts = new Set([
  'scripts/review-spec-kit-update.ps1',
  'scripts/test-spec-workflow-upstream.mjs',
  'scripts/test-spec-workflow-engine.ps1',
  'scripts/validate-framework.ps1',
  'scripts/validate-framework.sh',
  'scripts/verify-spec-workflow-boundary.mjs',
  'scripts/verify-spec-workflow-upstream.mjs',
]);
const sourceExtensions = new Set(['.js', '.mjs', '.cjs', '.ts', '.mts', '.cts', '.py', '.ps1', '.sh']);
const upstreamTerm = /upstream/iu;
const specKitTerm = /speckit/iu;

function walk(directory, records) {
  if (!fs.existsSync(directory)) return;
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    const relative = path.relative(repositoryRoot, absolute).split(path.sep).join('/');
    if (entry.isDirectory()) {
      if (relative === 'engines/spec-workflow/upstream' || relative.includes('/__pycache__') || relative.includes('/.venv')) continue;
      walk(absolute, records);
    } else if (entry.isFile() && sourceExtensions.has(path.extname(entry.name)) && !allowedScripts.has(relative)) {
      records.push({ relative, text: fs.readFileSync(absolute, 'utf8') });
    }
  }
}

const records = [];
for (const root of productionRoots) walk(path.join(repositoryRoot, root), records);
// Production code has no legitimate reason to mention both the snapshot
// ownership term and Spec Kit. Independent tokens catch concatenated paths.
const violations = records.filter(({ text }) => {
  const decoded = text
    .replace(/\\N\{HYPHEN-MINUS\}/giu, '-')
    .replace(/\\u\{([0-9a-f]{1,6})\}/giu, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/\\u([0-9a-f]{4})/giu, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/\\x([0-9a-f]{2})/giu, (_, hex) => String.fromCodePoint(Number.parseInt(hex, 16)))
    .replace(/\\([0-7]{1,3})/gu, (_, octal) => String.fromCodePoint(Number.parseInt(octal, 8)));
  const normalized = decoded.normalize('NFKC').replace(/[^\p{L}\p{N}]/gu, '');
  const literalStream = [...decoded.matchAll(/(['"])(?:\\.|(?!\1)[\s\S])*?\1/gu)]
    .map((match) => match[0].slice(1, -1))
    .join('')
    .normalize('NFKC')
    .replace(/[^\p{L}\p{N}]/gu, '');
  return (upstreamTerm.test(normalized) && specKitTerm.test(normalized)) ||
    (upstreamTerm.test(literalStream) && specKitTerm.test(literalStream));
}).map(({ relative }) => relative).sort();
if (violations.length) {
  process.stderr.write(`Production code must not import or execute the Spec Kit snapshot:\n${violations.map((item) => `- ${item}`).join('\n')}\n`);
  process.exit(1);
}
process.stdout.write(`${JSON.stringify({ schemaVersion: 1, status: 'PASS', scannedFiles: records.length, violations: [] })}\n`);
