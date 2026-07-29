#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = path.resolve(process.argv[2] || path.join(import.meta.dirname, ".."));
const manifest = JSON.parse(fs.readFileSync(path.join(root, "config", "preferred-skills.json"), "utf8"));
const registry = JSON.parse(fs.readFileSync(path.join(root, "config", "capability-registry.json"), "utf8"));
if (manifest.schemaVersion !== 1) throw new Error("Unsupported preferred-skills schema");
const expected = [
  "animation-vocabulary", "apple-design", "design-brief", "emil-design-eng", "frontend-design",
  "hatch-pet", "impeccable", "improve-animations", "review-animations", "typeui-fundamentals",
  "ui-ux-pro-max",
];
const ids = manifest.preferred.map((entry) => entry.id);
if (new Set(ids).size !== ids.length) throw new Error("Duplicate preferred skill ids");
for (const id of expected) if (!ids.includes(id)) throw new Error(`Missing preferred skill: ${id}`);
for (const entry of manifest.preferred) {
  if (!entry.level || !entry.installEvidence || !entry.source?.repository || !entry.source?.path) throw new Error(`Incomplete preferred skill: ${entry.id}`);
  if (!/^[0-9a-f]{40}$/.test(entry.source.ref)) throw new Error(`Preferred skill is not commit-pinned: ${entry.id}`);
  const declared = registry.capabilities.find((item) => item.type === "skill" && item.id === entry.id);
  if (!declared) throw new Error(`Preferred skill missing from capability registry: ${entry.id}`);
  if (declared.installEvidence !== entry.installEvidence) throw new Error(`Install evidence mismatch: ${entry.id}`);
  if (declared.provenance?.repository !== entry.source.repository || declared.provenance?.ref !== entry.source.ref) throw new Error(`Provenance mismatch: ${entry.id}`);
}
const legacy = new Map(manifest.legacyEntries.map((entry) => [entry.id, entry]));
if (legacy.get("codex-home-recovery")?.classification !== "retired-local-snapshot") throw new Error("codex-home-recovery classification missing");
if (legacy.get("codex-primary-runtime")?.classification !== "runtime-component") throw new Error("codex-primary-runtime classification missing");
if (manifest.legacyEntries.some((entry) => entry.install !== false)) throw new Error("Legacy non-skills must not be installed as skills");
console.log(`Preferred skills tests passed (${ids.length} installable, ${legacy.size} legacy entries)`);
