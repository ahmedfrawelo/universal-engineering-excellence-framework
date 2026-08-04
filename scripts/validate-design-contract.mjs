#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const at = (name, fallback) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const file = path.resolve(at('--path', 'DESIGN.md'));
if (!fs.existsSync(file)) { console.error(`DESIGN_CONTRACT: FAIL\nMissing: ${file}`); process.exit(1); }
const text = fs.readFileSync(file, 'utf8');
const required = ['Overview', 'Color', 'Typography', 'Spacing', 'Shapes', 'Components', 'Do / Don\'t'];
const headings = [...text.matchAll(/^##\s+(.+?)\s*$/gm)].map((m) => m[1]);
const normalizedHeadings = headings.map((heading) => heading.trim().toLowerCase());
const duplicates = headings.filter((_, i) => normalizedHeadings.indexOf(normalizedHeadings[i]) !== i);
const missing = required.filter((h) => !normalizedHeadings.includes(h.toLowerCase()));
const frontmatter = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
const frontmatterKeys = frontmatter ? [...frontmatter[1].matchAll(/^([a-zA-Z][\w-]*):/gm)].map((m) => m[1]) : [];
const missingKeys = ['name', 'colors', 'typography', 'spacing', 'rounded'].filter((k) => !frontmatterKeys.includes(k));
const placeholder = /^(?:\{\}|\[\]|null|~|x|tbd|todo|replace-me)$/iu;
const weakKeys = [];
if (frontmatter) {
  for (const key of ['name', 'colors', 'typography', 'spacing', 'rounded']) {
    const match = frontmatter[1].match(new RegExp(`^${key}:\\s*(.*)(?:\\r?\\n((?:[ \\t]+.*(?:\\r?\\n|$))*))?`, 'm'));
    if (!match) continue;
    const inline = match[1].trim();
    const nested = String(match[2] || '').split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith('#'));
    const inlineValid = inline && !placeholder.test(inline);
    const nestedValid = nested.some((line) => /:\s*\S/.test(line) && !placeholder.test(line.split(/:\s*/, 2)[1] || ''));
    if (!inlineValid && !nestedValid) weakKeys.push(key);
  }
}
const weakSections = [];
for (const heading of required) {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const section = text.match(new RegExp(`^##\\s+${escaped}\\s*$([\\s\\S]*?)(?=^##\\s+|(?![\\s\\S]))`, 'mi'));
  const body = String(section?.[1] || '').replace(/<!--([\s\S]*?)-->/g, '').trim();
  if (body.length < 20 || placeholder.test(body)) weakSections.push(heading);
}
if (!frontmatter || missing.length || duplicates.length || missingKeys.length || weakKeys.length || weakSections.length) {
  console.error(JSON.stringify({status:'FAIL', file, missingSections:missing, weakSections, duplicateSections:[...new Set(duplicates)], missingFrontmatterKeys:missingKeys, weakFrontmatterKeys:weakKeys}, null, 2));
  process.exit(1);
}
console.log(JSON.stringify({status:'PASS', file, sections:required, frontmatterKeys, substantive:true}, null, 2));
