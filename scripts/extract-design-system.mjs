#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || process.cwd());
const output = path.resolve(process.argv[3] || path.join(root, 'design-system-extraction.json'));
const ignored = new Set(['node_modules', '.git', 'dist', 'build', '.angular', 'coverage', 'test-results', 'docs', 'documentation', '.playwright-mcp', '.storybook']);
const files = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ignored.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (/\.(css|scss|html|ts|json|tsx|jsx|vue|woff2?|ttf|otf|eot)$/i.test(entry.name) || /^package(-lock)?\.json$/.test(entry.name)) files.push(full);
  }
}
walk(root);
const text = files.map((file) => ({ file, text: fs.readFileSync(file, 'utf8') }));
const collect = (regex, map = (m) => m[1]) => [...new Set(text.flatMap(({ text: value }) => [...value.matchAll(regex)].map(map)))].sort();
const cssVars = collect(/(--[a-zA-Z0-9_-]+)\s*:/g);
const fonts = collect(/font-family\s*:\s*([^;}{]+)/gi).map((v) => v.trim()).filter((v) => v.length > 1 && !/[&;]/.test(v));
const colors = collect(/(?:#(?:[0-9a-f]{3,8})\b|rgba?\([^)]*\)|hsla?\([^)]*\)|oklch\([^)]*\))/gi, (m) => m[0]);
const radii = collect(/border-radius\s*:\s*([^;}{]+)/gi).map((v) => v.trim());
const strokes = collect(/(?:border|outline)(?:-[a-z]+)?\s*:\s*([^;}{]+)/gi).map((v) => v.trim());
const iconPackages = collect(/['"](@[^'"/]+\/[^'"/]+|(?:lucide|bootstrap|material|heroicons)[^'"/]*)['"]/gi, (m) => m[1]).filter((v) => /icon|huge|lucide|bootstrap|material|hero/i.test(v));
const fontAssets = files.map((file) => path.relative(root, file)).filter((file) => /\.(woff2?|ttf|otf|eot)$/i.test(file));
const sourceFiles = {
  theme: files.map((file) => path.relative(root, file)).filter((file) => /theme|token|design-system|styles?\.(css|scss)$/i.test(file)),
  typography: files.map((file) => path.relative(root, file)).filter((file) => /font|typography|theme|token|styles?\.(css|scss)$/i.test(file)),
  icons: files.map((file) => path.relative(root, file)).filter((file) => /icon|app\.component\.(ts|html)|package\.json$/i.test(file)),
  package: files.map((file) => path.relative(root, file)).filter((file) => /^package(-lock)?\.json$/i.test(path.basename(file)))
};
const report = {
  generatedAt: new Date().toISOString(), root,
  evidence: { filesScanned: files.length, sourceFiles, cssVars, fonts, colors, radii, strokes, iconPackages, fontAssets },
  recommendations: {
    missingEvidence: [],
    rules: [
      'Reuse extracted tokens before adding a new color, font, radius, stroke, or icon family.',
      'If a needed role is absent, add a semantic token to the existing design-system source before consuming it.',
      'Prefer the existing icon family and stroke style; introduce another library only with an explicit ownership and bundle-cost decision.',
      'Use extracted font assets and declared font stacks before recommending a new font.',
      'Do not recommend visual values from category convention alone; require project evidence or a documented exception.'
    ]
  }
};
if (!fonts.length) report.recommendations.missingEvidence.push('font-family');
if (!colors.length && !cssVars.length) report.recommendations.missingEvidence.push('semantic colors');
if (!radii.length) report.recommendations.missingEvidence.push('radius tokens');
if (!strokes.length) report.recommendations.missingEvidence.push('outline/stroke tokens');
if (!iconPackages.length) report.recommendations.missingEvidence.push('icon library');
fs.writeFileSync(output, JSON.stringify(report, null, 2) + '\n', 'utf8');
console.log(`Design extraction written: ${output}`);
console.log(`Scanned ${files.length} source files; fonts=${fonts.length}, colors=${colors.length}, tokens=${cssVars.length}, icons=${iconPackages.length}`);
