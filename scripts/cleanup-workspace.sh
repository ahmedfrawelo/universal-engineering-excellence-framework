#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
DAYS=${CLEANUP_OLDER_THAN_DAYS:-14}
APPLY=${CLEANUP_APPLY:-0}
CUTOFF=$(date -d "-$DAYS days" +%s 2>/dev/null || date -v-${DAYS}d +%s)

is_protected() {
  case "$1" in
    "$ROOT/.git"/*|"$ROOT/node_modules"/*|"$ROOT/release"/*|"$ROOT/src"/*|"$ROOT/app"/*|"$ROOT/config"/*|"$ROOT/secrets"/*) return 0 ;;
  esac
  return 1
}

for name in coverage .nyc_output playwright-report test-results screenshots artifacts .cache .pytest_cache tmp temp dist build out publish .deploy server-upload; do
  target="$ROOT/$name"
  [ -d "$target" ] || continue
  is_protected "$target" && continue
  git -C "$ROOT" ls-files --error-unmatch "$name" >/dev/null 2>&1 && continue
  printf '%s\n' "$target"
  [ "$APPLY" = 1 ] && rm -rf -- "$target"
done

find "$ROOT" -type f \( -name '*.log' -o -name '*.trace' -o -name '*.har' -o -name '*.tmp' \) -not -path "$ROOT/.git/*" -exec sh -c '
  root=$1 cutoff=$2 apply=$3; shift 3
  for file do
    case "$file" in "$root/.git"/*|"$root/node_modules"/*|"$root/release"/*|"$root/src"/*|"$root/app"/*|"$root/config"/*|"$root/secrets"/*) continue;; esac
    rel=${file#"$root"/}
    git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 && continue
    modified=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
    [ "$modified" -lt "$cutoff" ] || continue
    printf "%s\n" "$file"
    [ "$apply" = 1 ] && rm -f -- "$file"
  done
' sh "$ROOT" "$CUTOFF" "$APPLY" {} +

if [ "$APPLY" = 1 ]; then echo "Cleanup applied: logs and temporary files removed."; else echo "Dry run only. Set CLEANUP_APPLY=1 to apply."; fi
