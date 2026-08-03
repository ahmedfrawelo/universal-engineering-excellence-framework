import { readTurnState, updateTurnState } from './ueef-hook-common.mjs';

const args = process.argv.slice(2);
const value = (name) => {
  const index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) throw new Error(`Missing ${name}.`);
  return args[index + 1];
};
const sessionId = value('--session-id');
const turnId = value('--turn-id');
const tier = value('--tier');
const intent = value('--intent');
const agentRoute = value('--agent-route');
const browserReason = value('--browser-reason');
if (!/^T[0-4]$/.test(tier)) throw new Error(`Invalid tier: ${tier}`);
for (const [name, item] of Object.entries({intent, agentRoute, browserReason})) {
  if (!item || item.length > 500) throw new Error(`${name} must contain 1-500 characters.`);
}
if (!readTurnState(sessionId, turnId)) throw new Error('No current UEEF turn state exists. Submit the prompt through the managed UserPromptSubmit hook first.');
updateTurnState(sessionId, turnId, (state) => {
  state.route = {tier, intent, agentRoute, browserReason, recordedAtUtc:new Date().toISOString()};
});
process.stdout.write(`UEEF route recorded: ${tier}\n`);
