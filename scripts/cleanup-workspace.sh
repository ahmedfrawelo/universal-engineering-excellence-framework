#!/usr/bin/env sh
set -eu

ROOT_INPUT=${1:-$(dirname -- "$0")/..}
case "$ROOT_INPUT" in
  [A-Za-z]:|[A-Za-z]:/|[A-Za-z]:\\) echo "Refusing to clean a filesystem root: $ROOT_INPUT" >&2; exit 2 ;;
esac
while [ "$ROOT_INPUT" != / ] && [ "${ROOT_INPUT%/}" != "$ROOT_INPUT" ]; do ROOT_INPUT=${ROOT_INPUT%/}; done
[ "$ROOT_INPUT" != / ] || { echo "Refusing to clean a filesystem root: $ROOT_INPUT" >&2; exit 2; }
[ ! -L "$ROOT_INPUT" ] || { echo "Refusing to clean a symbolic link root: $ROOT_INPUT" >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$ROOT_INPUT" && pwd -P)
DAYS=${CLEANUP_OLDER_THAN_DAYS:-14}
APPLY=${CLEANUP_APPLY:-0}
CUTOFF=$(date -d "-$DAYS days" +%s 2>/dev/null || date -v-${DAYS}d +%s)

case $(uname -s 2>/dev/null || printf unknown) in
  CYGWIN*|MINGW*|MSYS*) WINDOWS_PATHS=1 ;;
  *) WINDOWS_PATHS=0 ;;
esac

path_key() {
  if [ "$WINDOWS_PATHS" = 1 ]; then printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'; else printf '%s\n' "$1"; fi
}

canonicalize() {
  if command -v realpath >/dev/null 2>&1; then
    realpath -- "$1"
  elif [ -d "$1" ]; then
    (CDPATH= cd -P -- "$1" && pwd -P)
  else
    directory=$(dirname -- "$1")
    basename=$(basename -- "$1")
    directory=$(CDPATH= cd -P -- "$directory" && pwd -P)
    printf '%s/%s\n' "$directory" "$basename"
  fi
}

is_reparse_point() {
  [ -L "$1" ] && return 0
  if [ "$WINDOWS_PATHS" = 1 ] && command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    windows_path=$(cygpath -w "$1")
    powershell.exe -NoProfile -NonInteractive -Command \
      '$item = Get-Item -LiteralPath $args[0] -Force -ErrorAction Stop; if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { exit 0 }; exit 1' \
      "$windows_path" >/dev/null 2>&1
    return $?
  fi
  return 1
}

ROOT_KEY=$(path_key "$ROOT")
[ "$ROOT_KEY" != / ] || { echo "Refusing to clean a filesystem root: $ROOT" >&2; exit 2; }
ROOT_PARENT=$(CDPATH= cd -P -- "$ROOT/.." && pwd -P)
[ "$ROOT_KEY" != "$(path_key "$ROOT_PARENT")" ] || { echo "Refusing to clean a filesystem root: $ROOT" >&2; exit 2; }
if [ "$WINDOWS_PATHS" = 1 ]; then
  case "$ROOT_KEY" in /[a-z]) echo "Refusing to clean a filesystem root: $ROOT" >&2; exit 2;; esac
fi
if [ "$WINDOWS_PATHS" = 1 ] && command -v cygpath >/dev/null 2>&1; then
  WINDOWS_ROOT=$(cygpath -w "$ROOT")
  case "$WINDOWS_ROOT" in [A-Za-z]:\\) echo "Refusing to clean a filesystem root: $ROOT" >&2; exit 2;; esac
fi

if [ -n "${HOME:-}" ] && [ -d "$HOME" ]; then
  HOME_CANONICAL=$(CDPATH= cd -P -- "$HOME" && pwd -P)
  [ "$ROOT_KEY" != "$(path_key "$HOME_CANONICAL")" ] || { echo "Refusing to clean the user home: $ROOT" >&2; exit 2; }
fi

has_repository_marker() {
  if ! is_reparse_point "$ROOT/.git" && { [ -d "$ROOT/.git" ] || [ -f "$ROOT/.git" ]; }; then return 0; fi
  for marker in package.json pyproject.toml Cargo.toml go.mod pom.xml build.gradle build.gradle.kts composer.json Gemfile release-manifest.json; do
    if [ -f "$ROOT/$marker" ] && ! is_reparse_point "$ROOT/$marker"; then return 0; fi
  done
  return 1
}
has_repository_marker || { echo "Refusing to clean '$ROOT': no repository marker was found." >&2; exit 2; }

is_strict_descendant() {
  candidate_key=$(path_key "$1")
  case "$candidate_key" in "$ROOT_KEY"/*) return 0;; *) return 1;; esac
}

is_protected() {
  candidate_key=$(path_key "$1")
  for name in .git node_modules release src app config secrets; do
    protected_key=$(path_key "$ROOT/$name")
    case "$candidate_key" in "$protected_key"|"$protected_key"/*) return 0;; esac
  done
  return 1
}

is_safe_candidate() {
  candidate=$1
  [ -e "$candidate" ] || return 1
  is_reparse_point "$candidate" && return 1
  canonical=$(canonicalize "$candidate") || return 1
  is_strict_descendant "$canonical" || return 1
  is_protected "$canonical" && return 1
  if [ -d "$candidate" ] && [ -n "$(find "$candidate" -type l -print -quit 2>/dev/null)" ]; then return 1; fi
  return 0
}

is_tracked() {
  [ -e "$ROOT/.git" ] || return 1
  git -C "$ROOT" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

delete_if_still_safe() {
  candidate=$1
  kind=$2
  is_safe_candidate "$candidate" || return 0
  if [ "$kind" = directory ]; then rm -rf -- "$candidate"; else rm -f -- "$candidate"; fi
}

for name in coverage .nyc_output playwright-report test-results screenshots artifacts .cache .pytest_cache tmp temp dist build out publish .deploy server-upload; do
  target="$ROOT/$name"
  [ -d "$target" ] || continue
  is_safe_candidate "$target" || continue
  is_tracked "$name" && continue
  printf '%s\n' "$target"
  [ "$APPLY" = 1 ] && delete_if_still_safe "$target" directory
done

find "$ROOT" -type f \( -name '*.log' -o -name '*.trace' -o -name '*.har' -o -name '*.tmp' \) -exec sh -c '
  root=$1 root_key=$2 cutoff=$3 apply=$4 windows_paths=$5; shift 5
  path_key() { if [ "$windows_paths" = 1 ]; then printf "%s\n" "$1" | tr "[:upper:]" "[:lower:]"; else printf "%s\n" "$1"; fi; }
  canonicalize() {
    if command -v realpath >/dev/null 2>&1; then realpath -- "$1";
    else directory=$(CDPATH= cd -P -- "$(dirname -- "$1")" && pwd -P); printf "%s/%s\n" "$directory" "$(basename -- "$1")"; fi
  }
  safe_file() {
    [ -f "$1" ] && [ ! -L "$1" ] || return 1
    canonical=$(canonicalize "$1") || return 1
    candidate_key=$(path_key "$canonical")
    case "$candidate_key" in "$root_key"/*) ;; *) return 1;; esac
    for name in .git node_modules release src app config secrets; do
      protected_key=$(path_key "$root/$name")
      case "$candidate_key" in "$protected_key"|"$protected_key"/*) return 1;; esac
    done
    return 0
  }
  for file do
    safe_file "$file" || continue
    rel=${file#"$root"/}
    if [ -e "$root/.git" ] && git -C "$root" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then continue; fi
    modified=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
    [ "$modified" -lt "$cutoff" ] || continue
    printf "%s\n" "$file"
    if [ "$apply" = 1 ] && safe_file "$file"; then rm -f -- "$file"; fi
  done
' sh "$ROOT" "$ROOT_KEY" "$CUTOFF" "$APPLY" "$WINDOWS_PATHS" {} +

if [ "$APPLY" = 1 ]; then echo "Cleanup applied: logs and temporary files removed."; else echo "Dry run only. Set CLEANUP_APPLY=1 to apply."; fi
