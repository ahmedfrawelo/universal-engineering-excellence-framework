# Context and Token Economy

## Child Context Packet

Send only:

- outcome and acceptance criteria;
- exact repository root and relevant paths;
- constraints and risk floor;
- owned files or read-only question;
- expected evidence and concise response format.

Do not send full chat history by default. Prefer explicit file references and current repository evidence. Reuse an existing agent for dependent follow-up instead of spawning another one.

## Economy Rules

- Route first, then inspect only the selected surface.
- Parallelize independent reads or tests, not coupled decisions.
- Avoid duplicate summaries and repeated repository scans.
- Cap child output to decisions, evidence, changed files, and blockers.
- Cancel obsolete work after scope changes.
- Cache stable findings inside the rollout, but re-check drift-prone state.
- The lead synthesizes results once and does not re-perform completed child work.

Token reduction is a constraint, not the success metric. Correctness, security, and completion remain release gates.
