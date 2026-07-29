#!/usr/bin/env sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
task=${1:-}
[ -n "$task" ] || { echo 'usage: get-ueef-task-preflight.sh "task summary"' >&2; exit 2; }

# Unix keeps capability health intentionally unsupported, but it still
# classifies the task from the same intent signals instead of returning a
# hard-coded medium-risk route for every request.
runtime_status=$("$root/scripts/ueef-status.sh" "$root")
runtime_overall=$(printf '%s\n' "$runtime_status" | sed -n 's/^Overall: //p' | tail -n 1)
runtime_mode=$(printf '%s\n' "$runtime_status" | sed -n 's/^Mode: //p' | tail -n 1)
activation_mode="INACTIVE"
execution_authorized=false
if [ "$runtime_mode" = "managed-runtime" ] && [ "$runtime_overall" = "ACTIVE" ]; then
  activation_mode="ACTIVE_RUNTIME"
  execution_authorized=true
elif [ "$runtime_mode" = "source-checkout" ] && [ "$runtime_overall" = "SOURCE_VALIDATED" ]; then
  activation_mode="SOURCE_VALIDATED"
  execution_authorized=true
fi
node -e '
const {execFileSync}=require("child_process");
const [root,task,activationMode,executionAuthorized,runtimeMode,runtimeOverall]=process.argv.slice(1);
const t=task.toLowerCase();
const has=r=>r.test(t);
const explanatory=has(/\b(explain|answer|summari[sz]e|translate|define|what is|how does)\b/);
const change=has(/\b(build|implement|add|change|refactor|fix|repair|migrat\w*|create|update|remove|delete|harden|polish|upgrade|replace|write|edit|integrate|deploy|release)\b/)&&!explanatory;
const debug=has(/\b(bug|debug|regression|failure|failing|broken|error|crash|fix|repair)\b/);
const ambiguous=has(/\b(ambiguous|unclear|unknown requirements?|brainstorm|explore|idea|acceptance criteria|contradictory|not sure)\b/);
const browser=has(/\b(open|navigate|inspect|click|type|upload|download|authenticate|log.?in|browse|capture|screenshot|visually verify|visual check)\b/)&&has(/\b(browser|chrome|tab|website|web page|site|localhost|figma)\b/);
const ui=has(/\b(ui|ux|frontend|react|angular|css|scss|tailwind|layout|accessibility|screen|component|dashboard|landing page|visual design)\b/)&&has(/\b(build|implement|create|change|update|fix|polish|design|style|render|audit|review|inspect|verify)\b/);
const currentDocs=has(/\b(latest|current|up[- ]to[- ]date|newest|recent)\b/)&&has(/\b(documentation|docs|api|sdk|library|package|model|specification|standard|version)\b/);
const critical=has(/\b(production|prod|live environment|live system|migration|migrate|payment|billing|destructive|irreversible|incident|outage|breach)\b/);
const security=has(/\b(authentication|authorization|security|vulnerability|secret|credential|owasp|threat)\b/);
let scope=change?1:0;
if(has(/\b(project[- ]wide|repository[- ]wide|system[- ]wide|end[- ]to[- ]end|all (?:problems|issues|modules|files)|entire (?:project|repository|system)|complete migration|full migration)\b/)) scope=3;
else if(change&&has(/\b(architecture|architectural|database|schema|sql|api|endpoint|backend|server|dependency|package|platform)\b/)) scope=2;
const ambiguity=ambiguous?1:0;
const coupling=critical?3:(change&&has(/\b(architecture|architectural|database|schema|sql|api|endpoint|backend|server|dependency|package|platform|authentication|authorization|security)\b/)?2:(change?1:0));
const risk=critical?3:(security?2:(change?1:0));
const verification=risk===3?3:(debug?2:(change?1:0));
const floor=critical?(has(/\b(payment|billing)\b/)?"Payment":(has(/\b(production|prod|live)\b/)?"Production":(has(/\b(incident|outage|breach)\b/)?"Incident":"Migration"))):(security?"Security":"None");
const routeArgs=["--scope",String(scope),"--ambiguity",String(ambiguity),"--coupling",String(coupling),"--risk",String(risk),"--verification",String(verification),"--risk-floor",floor];
if(change) routeArgs.push("--code-change");
const route=JSON.parse(execFileSync("sh",[root+"/scripts/select-agent-route.sh",...routeArgs],{encoding:"utf8"}));
const tags=[ui?"ui":null,browser?"browser":null,currentDocs?"current-docs":null,ambiguous?"ambiguous":null,debug?"debugging":null].filter(Boolean);
const skills=ui?["ui-ux-pro-max","impeccable","typeui-fundamentals"]:[]; if(currentDocs) skills.push(".system/openai-docs");
const mcps=browser?["node_repl"]:[];
const workflows=[]; const decisions=[];
if(ambiguous){workflows.push("brainstorming-and-clarification");decisions.push({id:"brainstorming-and-clarification",selection:"recommended",evidence:"Resolved assumptions or clarification record before implementation."});}
if(debug){workflows.push("systematic-debugging","tdd-evidence-loop");decisions.push({id:"systematic-debugging",selection:"required",evidence:"Reproduction plus focused regression evidence."});}
else if(change){workflows.push("evidence-loop");decisions.push({id:"evidence-loop",selection:"required",evidence:"Focused test, build, static check, or visual/API evidence."});}
if(route.tier==="T3"||route.tier==="T4"){workflows.push("independent-review");decisions.push({id:"independent-review",selection:"required",evidence:"Spec-compliance and quality-review evidence."});}
const authorized=executionAuthorized==="true";
console.log(JSON.stringify({schemaVersion:3,status:authorized?"READY_WITH_FALLBACK":"BLOCKED",task,classification:{source:"inferred",tags,route},profile:{profile:(route.tier==="T3"||route.tier==="T4")?"ASSURED":"SELECTIVE",skills,mcps,workflows,workflowDecisions:decisions,limitations:"Unix preflight does not run capability health or callable probes."},activation:{mode:activationMode,executionAuthorized:authorized,runtimeMode,runtimeOverall,limitations:"Unix activation is verified structurally; capability callability remains unprobed."},health:{status:"UNSUPPORTED_ON_UNIX",detail:"No Unix capability-health implementation is available."}},null,2));
' "$root" "$task" "$activation_mode" "$execution_authorized" "$runtime_mode" "$runtime_overall"
