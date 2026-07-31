#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execFileSync } from "node:child_process";

const root = path.resolve(process.argv[2] || path.join(import.meta.dirname, ".."));
const installedRoot = process.argv[3] ? path.resolve(process.argv[3]) : null;
const manifest = JSON.parse(fs.readFileSync(path.join(root, "config", "preferred-skills.json"), "utf8"));
const registry = JSON.parse(fs.readFileSync(path.join(root, "config", "capability-registry.json"), "utf8"));
if (manifest.schemaVersion !== 2) throw new Error("Unsupported preferred-skills schema");
const expected = [
  "animation-vocabulary", "apple-design", "design-brief", "emil-design-eng", "frontend-design",
  "hatch-pet", "impeccable", "improve-animations", "review-animations", "typeui-fundamentals",
  "ui-ux-pro-max", "company-data-table", "design-system-guardian", "frontend-visual-qa",
  "angular-table-harness", "interface-design", "angular-developer", "source-driven-development",
  "frontend-ui-engineering", "browser-testing-with-devtools", "performance-optimization",
  "code-review-and-quality", "responsive-craft", "frontend-design-review", "web-design-guidelines",
  "prototype", "extract-design-system",
];
const ids = manifest.preferred.map((entry) => entry.id);
if (new Set(ids).size !== ids.length) throw new Error("Duplicate preferred skill ids");
for (const id of expected) if (!ids.includes(id)) throw new Error(`Missing preferred skill: ${id}`);

function validateSkillFile(file, expectedName, { manualOnly = false, requireComplete = false } = {}) {
  if (!fs.existsSync(file)) throw new Error(`SKILL.md missing: ${file}`);
  const content = fs.readFileSync(file, "utf8");
  if (!content.startsWith("---\n") && !content.startsWith("---\r\n")) throw new Error(`Frontmatter missing: ${file}`);
  const normalized = content.replaceAll("\r\n", "\n");
  const end = normalized.indexOf("\n---\n", 4);
  if (end < 0) throw new Error(`Frontmatter is not closed: ${file}`);
  const frontmatter = normalized.slice(4, end);
  const name = frontmatter.match(/^name:\s*(.+)$/m)?.[1]?.trim()?.replace(/^['"]|['"]$/g, "");
  const descriptionMatch = frontmatter.match(/^description:\s*(.*)$/m);
  let description = descriptionMatch?.[1]?.trim();
  if (description === ">" || description === "|") {
    const after = frontmatter.slice((descriptionMatch.index ?? 0) + descriptionMatch[0].length);
    const continuation = [];
    for (const line of after.split("\n").slice(1)) {
      if (line && !/^\s+/.test(line)) break;
      if (line.trim()) continuation.push(line.trim());
    }
    description = continuation.join(" ");
  }
  if (name !== expectedName) throw new Error(`Skill name mismatch for ${expectedName}: ${name || "missing"}`);
  if (!description || description.length > 2048 || (requireComplete && /[<>]/.test(description))) throw new Error(`Invalid skill description: ${expectedName}`);
  if (manualOnly && !/^disable-model-invocation:\s*true$/m.test(frontmatter)) throw new Error(`Manual-only policy missing: ${expectedName}`);
  if (requireComplete && /\b(TODO|FIXME)\b/i.test(normalized)) throw new Error(`Unfinished skill content: ${expectedName}`);
}

for (const entry of manifest.preferred) {
  if (!entry.level || !entry.installEvidence || !entry.source?.path || !entry.triggers?.length) throw new Error(`Incomplete preferred skill: ${entry.id}`);
  const kind = entry.source.kind || "github";
  if (!["github", "github-manual-only", "bundled"].includes(kind)) throw new Error(`Unknown source kind: ${entry.id}`);
  if (entry.installEvidence !== `skills/${entry.id}/SKILL.md`) throw new Error(`Non-canonical install evidence: ${entry.id}`);
  if (kind === "bundled") {
    validateSkillFile(path.join(root, entry.source.path, "SKILL.md"), entry.id, { requireComplete: true });
  } else if (!entry.source.repository || !/^[0-9a-f]{40}$/.test(entry.source.ref)) {
    throw new Error(`Preferred skill is not commit-pinned: ${entry.id}`);
  }
  if (kind === "github-manual-only" && entry.level !== "manual-only") throw new Error(`Manual-only source must have manual-only level: ${entry.id}`);
  if (installedRoot) validateSkillFile(path.join(installedRoot, entry.id, "SKILL.md"), entry.id, { manualOnly: kind === "github-manual-only" });
  const declared = registry.capabilities.find((item) => item.type === "skill" && item.id === entry.id);
  if (declared) {
    if (declared.installEvidence !== entry.installEvidence) throw new Error(`Install evidence mismatch: ${entry.id}`);
    if (kind !== "bundled" && (declared.provenance?.repository !== entry.source.repository || declared.provenance?.ref !== entry.source.ref)) throw new Error(`Provenance mismatch: ${entry.id}`);
  }
}
const routeTasks = [
  "Build an Angular data grid dashboard",
  "Build a responsive React landing page",
  "Audit frontend performance and accessibility",
  "Run visual QA and screenshot diff for the responsive UI",
  "Prototype multiple dashboard variants",
  "Extract the design system from a public website",
];
for (const task of routeTasks) {
  const output = execFileSync(process.execPath, [path.join(root, "scripts", "select-frontend-route.mjs"), "--task", task], { encoding: "utf8" });
  const route = JSON.parse(output);
  for (const id of route.skills) if (!ids.includes(id)) throw new Error(`Routed skill is absent from preferred manifest: ${id}`);
  if (route.skills.includes("browser-testing-with-devtools")) throw new Error("Policy-blocked browser skill was auto-routed");
}
const legacy = new Map(manifest.legacyEntries.map((entry) => [entry.id, entry]));
if (legacy.get("codex-home-recovery")?.classification !== "retired-local-snapshot") throw new Error("codex-home-recovery classification missing");
if (legacy.get("codex-primary-runtime")?.classification !== "runtime-component") throw new Error("codex-primary-runtime classification missing");
if (manifest.legacyEntries.some((entry) => entry.install !== false)) throw new Error("Legacy non-skills must not be installed as skills");
console.log(`Preferred skills tests passed (${ids.length} installable, ${legacy.size} legacy entries${installedRoot ? ", installed files validated" : ""})`);
