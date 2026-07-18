#!/usr/bin/env sh
set -eu

ROOT="${1:-.}"
MAX_ITEMS="${2:-40}"
case "$MAX_ITEMS" in
  ''|*[!0-9]*|0) echo "MAX_ITEMS must be a positive integer" >&2; exit 1 ;;
esac
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
      find "$ROOT" \( -type d -name .git \) -prune -o \( -type d \( -name node_modules -o -name dist -o -name build -o -name out -o -name coverage -o -name .next -o -name .angular -o -name bin -o -name obj \) \) -prune -o -name "$name" -type "$type" -print 2>/dev/null
    done | sed "s#^$ROOT/##" | sort -u | head -n "$MAX_ITEMS" || true
  )"
  if [ -n "$results" ]; then
    printf '%s\n' "$results" | sed 's/^/- /'
  else
    echo "- none detected"
  fi
}

print_test_section() {
  echo
  echo "Test candidates:"
  results="$(
    find "$ROOT" \( -type d -name .git \) -prune -o \( -type d \( -name node_modules -o -name dist -o -name build -o -name out -o -name coverage -o -name .next -o -name .angular -o -name bin -o -name obj \) \) -prune -o \( \( -type d \( -name test -o -name tests -o -name e2e -o -name spec -o -name specs -o -name __tests__ -o -name playwright -o -name cypress \) \) -o \( -type f \( -name 'test-*' -o -name '*.test.*' -o -name '*.spec.*' -o -name '*_test.*' -o -name '*Tests.*' \) \) \) -print 2>/dev/null |
      sed "s#^$ROOT/##" | sort -u | head -n "$MAX_ITEMS" || true
  )"
  if [ -n "$results" ]; then printf '%s\n' "$results" | sed 's/^/- /'; else echo "- none detected"; fi
}

print_generated_section() {
  echo
  echo "Generated/output candidates:"
  results="$(
    find "$ROOT" \( -type d -name .git \) -prune -o -type d \( -name dist -o -name build -o -name out -o -name coverage -o -name .next -o -name .angular -o -name node_modules -o -name bin -o -name obj -o -name logs -o -name screenshots -o -name artifacts \) -print -prune 2>/dev/null |
      sed "s#^$ROOT/##" | sort -u | head -n "$MAX_ITEMS" || true
  )"
  if [ -n "$results" ]; then printf '%s\n' "$results" | sed 's/^/- /'; else echo "- none detected"; fi
}

echo "Project Context Map"
echo "Root: $ROOT"
echo "Generated: $(date +%Y-%m-%dT%H:%M:%S)"

print_section "Manifests" f release-manifest.json package.json pnpm-workspace.yaml pnpm-lock.yaml yarn.lock package-lock.json angular.json vite.config.ts vite.config.js next.config.js next.config.mjs tsconfig.json Dockerfile docker-compose.yml docker-compose.yaml global.json hosting.json pyproject.toml requirements.txt Pipfile poetry.lock Cargo.toml Cargo.lock go.mod go.sum pom.xml build.gradle build.gradle.kts "*.sln" "*.csproj" "*.fsproj" "*.vbproj" "*.xcodeproj"
print_section "Shared candidates" d shared common lib libs library components ui design-system services api clients validators schemas stores state hooks utils
print_section "Feature/module candidates" d src app apps features framework modules packages pages routes domains cmd internal plugins scripts
print_section "Design system candidates" d tokens theme themes styles scss css icons assets
print_test_section
print_section "CI/deployment candidates" d .github .gitlab ci deploy deployment infra infrastructure terraform k8s helm
print_generated_section
