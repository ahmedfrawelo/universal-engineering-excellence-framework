import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultRoot = path.resolve(scriptDir, '..');

function filesMatching(root, predicate) {
  const files = [];
  const walk = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const full = path.join(directory, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.isFile() && predicate(entry.name)) files.push(full);
    }
  };
  walk(root);
  return files.sort((a, b) => a.localeCompare(b));
}

const markdownFiles = (root) => filesMatching(root, (name) => name.endsWith('.md'));

function directMarkdownFiles(root) {
  return fs.readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => path.join(root, entry.name))
    .sort((a, b) => a.localeCompare(b));
}

const DOMAIN_GROUPS = [
  {
    id: 'foundation-runtime',
    title: 'Foundation and Runtime',
    purpose: 'Start here for activation, installation, runtime sequence, workspace readiness, and safe local execution.',
    packs: [
      '00-foundation',
      '01-core',
      '02-installation',
      '03-runtime',
      '18-runtime-operations',
      '18-runtime-operations/01-environment-bootstrap',
      '18-runtime-operations/03-workspace-hygiene'
    ]
  },
  {
    id: 'engineering-quality',
    title: 'Engineering Quality',
    purpose: 'Use for architecture, code quality, security, performance, scalability, assurance, and engineering-health control.',
    packs: [
      '04-engineering',
      '05-architecture',
      '06-code-quality',
      '07-security',
      '08-performance',
      '09-scalability',
      '12-delivery-quality',
      '12-delivery-quality/08-engineering-guardian',
      '18-runtime-operations/04-continuous-assurance',
      '20-repository-evolution/02-performance-forensics'
    ]
  },
  {
    id: 'application-engineering',
    title: 'Application Engineering',
    purpose: 'Use for implementation owners across frontend, backend, database, API, stack packs, identity, grids, and application shells.',
    packs: [
      '10-frontend/01-engineering',
      '11-server-side',
      '11-server-side/02-backend',
      '11-server-side/03-database',
      '11-server-side/01-api',
      '15-tech-stacks/01-technology-packs',
      '15-tech-stacks',
      '15-tech-stacks/02-react',
      '15-tech-stacks/03-dotnet',
      '15-tech-stacks/04-sql-server',
      '15-tech-stacks/05-nodejs',
      '15-tech-stacks/06-python',
      '15-tech-stacks/07-angular',
      '15-tech-stacks/08-cloud',
      '17-product-platform/01-identity-access-application-models',
      '17-product-platform',
      '17-product-platform/03-data-grid-platform',
      '17-product-platform/04-application-shell-design'
    ]
  },
  {
    id: 'product-ui-frontend-experience',
    title: 'Product UI and Frontend Experience',
    purpose: 'Use for product UI, UX, accessibility, design systems, themes, responsive behavior, skeletons, design intelligence, and production frontend craft.',
    packs: [
      '10-frontend',
      '10-frontend/03-ui',
      '10-frontend/04-ux',
      '12-delivery-quality/07-accessibility',
      '16-design-system/01-consistency-reuse',
      '16-design-system',
      '16-design-system/02-theme-responsive-interaction-security-performance',
      '16-design-system/03-governance',
      '17-product-platform/02-skeleton-loading',
      '16-design-system/04-intelligence',
      '10-frontend/02-production-design'
    ]
  },
  {
    id: 'delivery-gates-evidence',
    title: 'Delivery, Gates, and Evidence',
    purpose: 'Use for testing, documentation, DevOps, enterprise readiness, quality gates, scorecards, checklists, templates, examples, scripts, references, roadmap, changelog, and future planning.',
    packs: [
      '12-delivery-quality/01-testing',
      '12-delivery-quality/02-documentation',
      '12-delivery-quality/03-devops',
      '17-product-platform/05-enterprise',
      '12-delivery-quality/04-quality-gates',
      '12-delivery-quality/05-scorecards',
      '12-delivery-quality/06-checklists',
      '21-framework-resources/01-templates',
      '21-framework-resources',
      '21-framework-resources/02-examples',
      '21-framework-resources/03-scripts',
      '21-framework-resources/04-reference',
      '21-framework-resources/05-roadmap',
      '21-framework-resources/06-changelog',
      '21-framework-resources/07-future'
    ]
  },
  {
    id: 'ai-agents-spec-workflow',
    title: 'AI, Agents, and Spec Workflow',
    purpose: 'Use for AI behavior, memory, review, decision routing, browser session policy, model orchestration, skill invocation, and spec-driven work.',
    packs: [
      '13-ai/01-core',
      '13-ai',
      '13-ai/02-intelligence',
      '13-ai/03-memory',
      '13-ai/04-review',
      '14-decision/01-engine',
      '14-decision',
      '14-decision/02-graphs',
      '18-runtime-operations/02-browser-session-control',
      '19-agent-workflow/01-model-orchestration',
      '19-agent-workflow',
      '19-agent-workflow/02-skill-invocation-protocol',
      '19-agent-workflow/03-spec-driven-development'
    ]
  },
  {
    id: 'repository-intelligence-modernization',
    title: 'Repository Intelligence and Modernization',
    purpose: 'Use for repository graphing, project mapping, modernization plans, dependency/refactor strategy, and large-project reuse.',
    packs: [
      '20-repository-evolution/01-project-modernization',
      '20-repository-evolution',
      '20-repository-evolution/03-repository-intelligence'
    ]
  }
];

export function packId(frameworkRoot, packDirectory) {
  return path.relative(frameworkRoot, packDirectory).replaceAll(path.sep, '/');
}

export function discoverPackDirectories(frameworkRoot) {
  const topLevelPacks = fs.readdirSync(frameworkRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^[0-9][0-9]-/.test(entry.name))
    .map((entry) => path.join(frameworkRoot, entry.name))
    .sort((a, b) => a.localeCompare(b));

  const packs = [];
  for (const pack of topLevelPacks) {
    const nestedPacks = fs.readdirSync(pack, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^[0-9][0-9]-/.test(entry.name))
      .map((entry) => path.join(pack, entry.name))
      .sort((a, b) => a.localeCompare(b));
    if (nestedPacks.length > 0) packs.push(pack, ...nestedPacks);
    else packs.push(pack);
  }
  return packs;
}

function validateDomainGroups(frameworkRoot, packDirectories) {
  const actual = packDirectories.map((pack) => packId(frameworkRoot, pack));
  const actualSet = new Set(actual);
  const seen = new Map();
  for (const group of DOMAIN_GROUPS) {
    for (const pack of group.packs) {
      if (!actualSet.has(pack)) throw new Error(`Domain map references unknown framework pack: ${pack}`);
      if (seen.has(pack)) throw new Error(`Domain map assigns framework pack more than once: ${pack}`);
      seen.set(pack, group.title);
    }
  }
  const missing = actual.filter((pack) => !seen.has(pack));
  if (missing.length > 0) throw new Error(`Domain map missing framework packs: ${missing.join(', ')}`);
  return seen;
}

function packIndex(frameworkRoot, packDirectory) {
  const packName = packId(frameworkRoot, packDirectory);
  const hasNestedPacks = fs.readdirSync(packDirectory, { withFileTypes: true })
    .some((entry) => entry.isDirectory() && /^[0-9][0-9]-/.test(entry.name));
  const packFiles = hasNestedPacks
    ? directMarkdownFiles(packDirectory)
    : packName === '21-framework-resources/01-templates'
    ? filesMatching(packDirectory, (name) => name.endsWith('.md') || name.endsWith('.json'))
    : markdownFiles(packDirectory);
  const files = packFiles
    .filter((file) => path.basename(file) !== 'INDEX.md')
    .map((file) => path.relative(packDirectory, file).replaceAll(path.sep, '/'));
  files.sort((a, b) => {
    if (a === 'README.md') return -1;
    if (b === 'README.md') return 1;
    return a.localeCompare(b);
  });
  return [
    `# ${packName} index`,
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    'This is the canonical file inventory for this pack. Use README.md for pack guidance.',
    '',
    ...files.map((file) => `- [\`${file}\`](${file})`),
    ''
  ].join('\n');
}

function masterIndex(frameworkRoot, packDirectories) {
  const lines = [
    '# UEEF Framework Master Index',
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    'Start with [DOMAIN_MAP.md](DOMAIN_MAP.md) for fast conceptual routing, then use this index for exact pack inventories.',
    '',
    'This index lists every Markdown module in the framework exactly once, grouped by owner pack.',
    ''
  ];
  for (const packDirectory of packDirectories) {
    const packName = packId(frameworkRoot, packDirectory);
    lines.push(`## ${packName}`, '');
    const files = markdownFiles(packDirectory)
      .map((file) => path.relative(frameworkRoot, file).replaceAll(path.sep, '/'))
      .sort((a, b) => a.localeCompare(b));
    for (const file of files) lines.push(`- [\`${file}\`](${file})`);
    lines.push('');
  }
  return lines.join('\n');
}

function domainReadme(frameworkRoot, packDirectories) {
  validateDomainGroups(frameworkRoot, packDirectories);
  const lines = [
    '# UEEF Framework Domains',
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    'This folder is the physical organization layer for fast UEEF navigation. It groups stable numbered packs and nested pack families by domain.',
    '',
    '## Domains',
    ''
  ];
  for (const group of DOMAIN_GROUPS) {
    lines.push(`- [${group.title}](${group.id}.md) - ${group.purpose}`);
  }
  lines.push(
    '',
    '## Use order',
    '',
    '1. Start with this domain folder.',
    '2. Open the selected domain page.',
    '3. Load only the listed owner packs needed for the task.',
    '4. Use [`../MASTER_INDEX.md`](../MASTER_INDEX.md) only when exact file inventory is needed.',
    ''
  );
  return lines.join('\n');
}

function domainPage(frameworkRoot, group) {
  const lines = [
    `# ${group.title}`,
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    `Purpose: ${group.purpose}`,
    '',
    '## Owner packs',
    ''
  ];
  for (const pack of group.packs) {
    lines.push(`- [\`${pack}\`](../${pack}/)`);
  }
  if (group.id === 'product-ui-frontend-experience') {
    lines.push(
      '',
      '## Frontend pairing',
      '',
      '- [`10-frontend/01-engineering`](../10-frontend/01-engineering/) remains in Application Engineering because it owns implementation behavior.',
      '- [`10-frontend/02-production-design`](../10-frontend/02-production-design/) stays here because it owns production visual quality.',
      '- Use both when a frontend task needs behavior and production design evidence.'
    );
  }
  lines.push('');
  return lines.join('\n');
}

function legacyDomainMap(frameworkRoot, packDirectories) {
  validateDomainGroups(frameworkRoot, packDirectories);
  const lines = [
    '# UEEF Framework Domain Map',
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    'The physical domain organization lives in [`_domains/README.md`](_domains/README.md). Use that folder first, then use [MASTER_INDEX.md](MASTER_INDEX.md) for exact inventory.',
    '',
    'Pack paths are generated from the current framework structure so links, loaders, runtime checks, and release validation stay aligned after reorganizations.',
    '',
    '## Domain folders',
    ''
  ];
  for (const group of DOMAIN_GROUPS) {
    lines.push(`- [${group.title}](_domains/${group.id}.md)`);
  }
  lines.push('');
  return lines.join('\n');
}

function domainInventory(frameworkRoot, packDirectories) {
  validateDomainGroups(frameworkRoot, packDirectories);
  const lines = [
    '# UEEF Framework Domain Inventory',
    '',
    '<!-- Generated by scripts/generate-framework-indexes.mjs. Do not edit manually. -->',
    '',
    'This file lists each stable numbered framework pack exactly once under its domain.',
    '',
    'Pack paths come from the current framework structure; this inventory is the generated coverage proof for the domain organization.',
    ''
  ];
  for (const group of DOMAIN_GROUPS) {
    lines.push(`## ${group.title}`, '');
    lines.push(`Purpose: ${group.purpose}`, '');
    for (const pack of group.packs) {
      lines.push(`- [\`${pack}\`](../${pack}/)`);
    }
    lines.push('');
  }
  lines.push(
    ''
  );
  return lines.join('\n');
}

export function buildFrameworkIndexes(root = defaultRoot) {
  const frameworkRoot = path.join(root, 'framework');
  const packs = discoverPackDirectories(frameworkRoot);
  const outputs = new Map();
  for (const pack of packs) outputs.set(path.join(pack, 'INDEX.md'), packIndex(frameworkRoot, pack));
  outputs.set(path.join(frameworkRoot, 'DOMAIN_MAP.md'), legacyDomainMap(frameworkRoot, packs));
  outputs.set(path.join(frameworkRoot, '_domains', 'README.md'), domainReadme(frameworkRoot, packs));
  outputs.set(path.join(frameworkRoot, '_domains', 'INVENTORY.md'), domainInventory(frameworkRoot, packs));
  for (const group of DOMAIN_GROUPS) outputs.set(path.join(frameworkRoot, '_domains', `${group.id}.md`), domainPage(frameworkRoot, group));
  outputs.set(path.join(frameworkRoot, 'MASTER_INDEX.md'), masterIndex(frameworkRoot, packs));
  return outputs;
}

export function writeFrameworkIndexes(root = defaultRoot) {
  for (const [file, content] of buildFrameworkIndexes(root)) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (fs.existsSync(file)) {
      const existing = fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n');
      if (existing === content) continue;
    }
    fs.writeFileSync(file, content, 'utf8');
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  writeFrameworkIndexes(process.argv[2] ? path.resolve(process.argv[2]) : defaultRoot);
  console.log('Framework indexes generated');
}
