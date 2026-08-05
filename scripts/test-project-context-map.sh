#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_BASE="$(mktemp -d)"
FIXTURE="$TMP_BASE/project with spaces"
trap 'rm -rf "$TMP_BASE"' EXIT HUP INT TERM

mkdir -p "$FIXTURE/.openai" "$FIXTURE/src" "$FIXTURE/scripts" "$FIXTURE/.github/workflows" "$FIXTURE/packages/sample/node_modules" "$FIXTURE/packages/sample/dist" "$FIXTURE/vendor/engine/shared" "$FIXTURE/vendor/engine/tests"
printf '{}\n' > "$FIXTURE/release-manifest.json"
printf '{}\n' > "$FIXTURE/.openai/hosting.json"
printf '%s\n' 'echo ok' > "$FIXTURE/scripts/test-example.sh"
printf '%s\n' '[project]' > "$FIXTURE/vendor/engine/pyproject.toml"
printf '%s\n' 'pass' > "$FIXTURE/vendor/engine/shared/library.py"
printf '%s\n' 'def test_vendor(): pass' > "$FIXTURE/vendor/engine/tests/test_vendor.py"

output="$(sh "$ROOT/scripts/project-context-map.sh" "$FIXTURE" 100)"
for term in 'Repository intelligence: NOT_BUILT' 'release-manifest.json' '.openai/hosting.json' 'src' 'scripts/test-example.sh' '.github' 'packages/sample/node_modules' 'packages/sample/dist'; do
  printf '%s\n' "$output" | grep -Fq -- "$term" || { echo "Project context map missing: $term" >&2; exit 1; }
done
for forbidden in 'vendor/engine/pyproject.toml' 'vendor/engine/shared' 'vendor/engine/tests'; do
  if printf '%s\n' "$output" | grep -Fq -- "$forbidden"; then
    echo "Project context map traversed generated content: $forbidden" >&2
    exit 1
  fi
done

mkdir -p "$FIXTURE/.ueef/repository-graph"
printf '%s\n' '{"status":"PASS"}' > "$FIXTURE/.ueef/repository-graph/state.json"
built_output="$(sh "$ROOT/scripts/project-context-map.sh" "$FIXTURE" 100)"
printf '%s\n' "$built_output" | grep -Fq -- 'Repository intelligence: BUILT' || { echo 'Project context map did not expose built repository intelligence state.' >&2; exit 1; }

if sh "$ROOT/scripts/project-context-map.sh" "$FIXTURE" 0 >/dev/null 2>&1; then
  echo 'Project context map accepted MAX_ITEMS 0' >&2
  exit 1
fi

printf '%s\n' 'Project context map tests passed'
