import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { cleanupHookState } from './codex-hooks/ueef-hook-common.mjs';

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ueef-hook-retention-'));
const nowMs = Date.now();
const oldMs = nowMs - 10 * 24 * 60 * 60 * 1000;
const recentMs = nowMs - 60 * 1000;
const writeState = (name, sessionId, mtimeMs) => {
  const file = path.join(root, name);
  fs.writeFileSync(file, `${JSON.stringify({ schemaVersion: 1, sessionId })}\n`, 'utf8');
  const time = new Date(mtimeMs);
  fs.utimesSync(file, time, time);
  return file;
};

try {
  const currentFiles = Array.from({ length: 3 }, (_, index) => writeState(`current.turn-${index}.json`, 'current', oldMs));
  const liveFiles = Array.from({ length: 3 }, (_, index) => writeState(`live.turn-${index}.json`, 'live', oldMs));
  const recentFiles = Array.from({ length: 3 }, (_, index) => writeState(`recent.turn-${index}.json`, 'recent', recentMs));
  Array.from({ length: 5 }, (_, index) => writeState(`old-a.turn-${index}.json`, 'old-a', oldMs + index));
  Array.from({ length: 4 }, (_, index) => writeState(`old-b.turn-${index}.json`, 'old-b', oldMs + index));
  const liveLock = path.join(root, 'live.lock');
  fs.writeFileSync(liveLock, `${JSON.stringify({ schemaVersion: 1, pid: process.pid, token: 'live-token', sessionId: 'live', turnId: '__session__' })}\n`, 'utf8');

  const fixtureBefore = fs.readdirSync(root).length;
  const first = cleanupHookState({ root, currentSessionId: 'current', nowMs, ttlMs: 24 * 60 * 60 * 1000, maxFilesPerSession: 2, maxFilesGlobal: 8, maxScan: 100, maxDelete: 4 });
  const fixtureAfterFirst = fs.readdirSync(root).length;
  if (first.before !== 18 || first.deleted !== 4 || first.after !== 14 || fixtureBefore !== 19 || fixtureAfterFirst !== 15) throw new Error(`Unexpected bounded cleanup counts: ${JSON.stringify({ fixtureBefore, first, fixtureAfterFirst })}`);
  for (const file of [...currentFiles, ...liveFiles, ...recentFiles, liveLock]) if (!fs.existsSync(file)) throw new Error(`Protected state was deleted: ${file}`);

  const second = cleanupHookState({ root, currentSessionId: 'current', nowMs, ttlMs: 24 * 60 * 60 * 1000, maxFilesPerSession: 2, maxFilesGlobal: 8, maxScan: 100, maxDelete: 100 });
  if (second.deleted !== 5 || second.after !== 9) throw new Error(`Remaining eligible state was not removed: ${JSON.stringify(second)}`);
  const third = cleanupHookState({ root, currentSessionId: 'current', nowMs, ttlMs: 24 * 60 * 60 * 1000, maxFilesPerSession: 2, maxFilesGlobal: 8, maxScan: 100, maxDelete: 100 });
  if (third.deleted !== 0 || third.after !== 9) throw new Error(`Cleanup was not idempotent: ${JSON.stringify(third)}`);

  const bounded = cleanupHookState({ root, currentSessionId: 'current', nowMs, ttlMs: 0, maxFilesPerSession: 0, maxFilesGlobal: 0, maxScan: 2, maxDelete: 1 });
  if (bounded.scanned !== 2 || bounded.deleted > 1 || bounded.bounded !== true) throw new Error(`Cleanup bounds were not enforced: ${JSON.stringify(bounded)}`);
  process.stdout.write(`${JSON.stringify({ fixtureBefore, fixtureAfterFirst, fixtureAfterFinal: fs.readdirSync(root).length, first, second, third, bounded })}\n`);
  process.stdout.write('Hook state retention tests passed\n');
} finally {
  fs.rmSync(root, { recursive: true, force: true });
}
