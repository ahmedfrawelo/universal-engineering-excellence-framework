#!/usr/bin/env sh
set -eu
root=${1:?root required}; query=${2:-}
node -e 'const fs=require("fs"),path=require("path");const [root,q]=process.argv.slice(1),dir=path.join(root,".ueef","memory"),now=Date.now();let items=fs.existsSync(dir)?fs.readdirSync(dir).filter(x=>x.endsWith(".json")).map(x=>JSON.parse(fs.readFileSync(path.join(dir,x),"utf8"))).filter(x=>Date.parse(x.expiresAt)>now):[];if(q){const needle=q.toLowerCase();items=items.filter(x=>`${x.kind} ${x.title} ${x.detail}`.toLowerCase().includes(needle));}console.log(JSON.stringify(items.sort((a,b)=>b.createdAt.localeCompare(a.createdAt))));' "$root" "$query"
