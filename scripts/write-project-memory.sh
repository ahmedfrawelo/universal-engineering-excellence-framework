#!/usr/bin/env sh
set -eu
root=${1:?root required}; kind=${2:?kind required}; title=${3:?title required}; detail=${4:?detail required}; retention=${5:-180}
case "$kind" in decision|rejected-option|owner|lesson) ;; *) echo 'invalid kind' >&2; exit 2;; esac
printf '%s' "$detail" | grep -Eqi '(password|api[_ -]?key|secret|token[[:space:]]*=|private key)' && { echo 'Project memory must not contain credentials or secrets.' >&2; exit 2; }
mkdir -p "$root/.ueef/memory"
node -e 'const fs=require("fs"),path=require("path"),crypto=require("crypto");const [root,kind,title,detail,days]=process.argv.slice(1);const now=new Date(),r={schemaVersion:1,id:crypto.randomBytes(16).toString("hex"),kind,title,detail,createdAt:now.toISOString(),expiresAt:new Date(now.getTime()+Number(days)*86400000).toISOString(),source:"explicit-user-or-agent-record",automaticPolicyChange:false};const p=path.join(root,".ueef","memory",`${r.createdAt.slice(0,10)}-${r.id}.json`);fs.writeFileSync(p,JSON.stringify(r,null,2)+"\n");console.log(JSON.stringify(r));' "$root" "$kind" "$title" "$detail" "$retention"
