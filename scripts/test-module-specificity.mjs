#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = path.resolve(process.argv[2] || path.join(import.meta.dirname, ".."));
const framework = path.join(root, "framework");
const forbidden = [
  "defines practical engineering behavior that AI coding assistants and engineering teams can apply during real project work",
  "provides the minimum enforceable operating guidance for this pack so the pack is not only a folder label",
];
const files = [];

for (const pack of fs.readdirSync(framework, { withFileTypes: true })) {
  if (!pack.isDirectory()) continue;
  const packPath = path.join(framework, pack.name);
  for (const entry of fs.readdirSync(packPath, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md") || /^(README|INDEX)\.md$/i.test(entry.name)) continue;
    files.push(path.join(packPath, entry.name));
  }
}

const violations = [];
const bodies = new Map();
for (const file of files) {
  const text = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  for (const phrase of forbidden) {
    if (text.includes(phrase)) violations.push(`${path.relative(root, file)} retains generic boilerplate: ${phrase}`);
  }
  const normalized = text
    .replace(/^# .*$/m, "# <title>")
    .replace(/^Pack: .*$/m, "Pack: <pack>")
    .replace(/^Applies To: .*$/m, "Applies To: <scope>")
    .trim();
  const group = bodies.get(normalized) || [];
  group.push(path.relative(root, file));
  bodies.set(normalized, group);
}

for (const group of bodies.values()) {
  if (group.length > 1) violations.push(`Duplicate module contracts: ${group.join(", ")}`);
}

if (violations.length) {
  console.error(violations.join("\n"));
  process.exit(1);
}
console.log(`Module specificity tests passed (${files.length} contracts checked)`);
