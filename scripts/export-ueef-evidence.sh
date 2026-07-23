#!/usr/bin/env sh
set -eu
root=${1:?repository root required}; output=${2:?output path required}; include_diff=${3:-false}
status=$("$(dirname "$0")/ueef-status.sh" 2>/dev/null || true)
diff='null'; [ "$include_diff" = true ] && diff=$("$(dirname "$0")/get-diff-impact.sh" "$root")
memory=$("$(dirname "$0")/get-project-memory.sh" "$root")
node -e 'const fs=require("fs"),path=require("path");const [out,status,diff,memory]=process.argv.slice(1);const redact=s=>s.replace(/(password|token|secret|api[_-]?key)\s*[:=]\s*[^\s,;]+/ig,"$1=[REDACTED]");const r={schemaVersion:1,generatedAt:new Date().toISOString(),runtimeStatus:status,diff:JSON.parse(diff),memorySummary:{activeRecords:JSON.parse(memory).length},redaction:"credential-like values are redacted"};fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,redact(JSON.stringify(r,null,2))+"\n");console.log(`Evidence exported: ${out}`)' "$output" "$status" "$diff" "$memory"
