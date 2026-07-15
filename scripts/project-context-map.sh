#!/usr/bin/env sh
set -eu

ROOT="${1:-.}"
MAX_ITEMS="${2:-40}"
cd "$ROOT"
ROOT="$(pwd -P)"

print_section() {
  title="$1"
  type="$2"
  shift 2
  echo
  echo "$title:"
  results="$(
    for name in "$@"; do
      find "$ROOT" \( -path "$ROOT/.git" -o -path "$ROOT/node_modules/*" -o -path "$ROOT/dist/*" -o -path "$ROOT/build/*" -o -path "$ROOT/out/*" -o -path "$ROOT/coverage/*" -o -path "$ROOT/.next/*" -o -path "$ROOT/.angular/*" \) -prune -o -name "$name" -type "$type" -print 2>/dev/null
    done | sed "s#^$ROOT/##" | grep -v '^\(\.git\|node_modules\|dist\|build\|out\|coverage\|\.next\|\.angular\)/' | sort -u | head -n "$MAX_ITEMS" || true
  )"
  if [ -n "$results" ]; then
    printf '%s\n' "$results" | sed 's/^/- /'
  else
    echo "- none detected"
  fi
}

echo "Project Context Map"
echo "Root: $ROOT"
echo "Generated: $(date +%Y-%m-%dT%H:%M:%S)"

print_section "Manifests" f package.json pnpm-workspace.yaml yarn.lock package-lock.json angular.json vite.config.ts vite.config.js next.config.js next.config.mjs tsconfig.json Dockerfile docker-compose.yml global.json "*.sln" "*.csproj"
print_section "Shared candidates" d shared common lib libs library components ui design-system services api clients validators schemas stores state hooks utils
print_section "Feature/module candidates" d features modules apps packages pages routes domains
print_section "Design system candidates" d tokens theme themes styles scss css icons assets
print_section "Test candidates" d test tests e2e spec specs __tests__ playwright cypress
print_section "Generated/output candidates" d dist build out coverage .next .angular node_modules bin obj logs screenshots artifacts
