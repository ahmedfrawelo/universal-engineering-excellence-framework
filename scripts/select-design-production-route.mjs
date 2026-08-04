#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {selectDesignProductionRoute} from './frontend-design-production-route-lib.mjs';

const args = process.argv.slice(2);
const value = (name, fallback = '') => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] ?? fallback : fallback; };
const task = value('--task', args.find((x) => !x.startsWith('--')) ?? '');
if (!task) { console.error('usage: select-design-production-route.mjs --task "task summary"'); process.exit(2); }
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const policy = JSON.parse(fs.readFileSync(path.join(root, 'config/frontend-design-production-policy.json'), 'utf8'));
console.log(JSON.stringify(selectDesignProductionRoute(task, policy), null, 2));
