import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scripts = path.dirname(fileURLToPath(import.meta.url));
const catalogScript = path.join(scripts, 'codex-app-server-models.mjs');
const resolverScript = path.join(scripts, 'resolve-model-route.mjs');
const recorderScript = path.join(scripts, 'codex-hooks', 'record-ueef-route.mjs');
{
  const catalogFailure = spawnSync(process.execPath, [catalogScript, '--timeout-ms', '1'], {
    encoding: 'utf8',
    timeout: 15000,
    windowsHide: true
  });
  assert.equal(catalogFailure.status, 1, `catalog process should fail cleanly: ${catalogFailure.stderr}`);
  assert.match(catalogFailure.stderr, /catalog discovery failed: Timed out after 1 ms/u);
  assert.equal(catalogFailure.signal, null, 'catalog process must own its timeout instead of being externally killed');

  const routeRaw = execFileSync(process.execPath, [resolverScript, '--tier', 'T3', '--catalog-timeout-ms', '1'], {
    encoding: 'utf8',
    timeout: 15000,
    windowsHide: true
  });
  const route = JSON.parse(routeRaw);
  assert.equal(route.modelAvailability, 'CATALOG_DISCOVERY_FAILED');
  assert.equal(route.modelSelectionMode, 'CATALOG_DISCOVERY_REQUIRED');
  assert.match(route.catalogDiscoveryError, /Timed out after 1 ms/u);

  const fallback = JSON.parse(execFileSync(process.execPath, [resolverScript, '--tier', 'T3', '--models-unavailable'], {
    encoding: 'utf8',
    timeout: 15000,
    windowsHide: true
  }));
  assert.equal(fallback.modelAvailability, 'UNAVAILABLE_BY_CALLER');
  assert.equal(fallback.modelSelectionMode, 'CAPACITY_FALLBACK_REQUIRED');

  const recorderSource = fs.readFileSync(recorderScript, 'utf8');
  assert.match(recorderSource, /timeout:\s*catalogTimeoutMs \+ resolverProcessGraceMs/u);
  assert.match(recorderSource, /resolverArgs\.push\('--catalog-timeout-ms', String\(catalogTimeoutMs\)\)/u);

  process.stdout.write('Routing timeout recovery tests passed\n');
}
