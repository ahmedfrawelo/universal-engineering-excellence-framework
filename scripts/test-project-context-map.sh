#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_BASE="$(mktemp -d)"
FIXTURE="$TMP_BASE/project with spaces"
trap 'rm -rf "$TMP_BASE"' EXIT HUP INT TERM

mkdir -p "$FIXTURE/.openai" "$FIXTURE/src" "$FIXTURE/scripts" "$FIXTURE/.github/workflows" "$FIXTURE/packages/sample/node_modules" "$FIXTURE/packages/sample/dist"
printf '{}\n' > "$FIXTURE/release-manifest.json"
printf '{}\n' > "$FIXTURE/.openai/hosting.json"
printf '%s\n' 'echo ok' > "$FIXTURE/scripts/test-example.sh"

output="$(sh "$ROOT/scripts/project-context-map.sh" "$FIXTURE" 100)"
for term in 'release-manifest.json' '.openai/hosting.json' 'src' 'scripts/test-example.sh' '.github' 'packages/sample/node_modules' 'packages/sample/dist'; do
  printf '%s\n' "$output" | grep -Fq -- "$term" || { echo "Project context map missing: $term" >&2; exit 1; }
done

if sh "$ROOT/scripts/project-context-map.sh" "$FIXTURE" 0 >/dev/null 2>&1; then
  echo 'Project context map accepted MAX_ITEMS 0' >&2
  exit 1
fi

printf '%s\n' 'Project context map tests passed'
