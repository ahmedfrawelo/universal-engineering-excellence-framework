#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
CLEANUP="$SCRIPT_DIR/cleanup-workspace.sh"
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/ueef-cleanup-test.XXXXXX")

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_exists() {
  [ -e "$1" ] || fail "expected path to exist: $1"
}

assert_missing() {
  [ ! -e "$1" ] || fail "expected path to be absent: $1"
}

assert_rejected() {
  root=$1
  expected=$2
  output="$SANDBOX/rejection-output"
  if CLEANUP_APPLY=0 "$CLEANUP" "$root" >"$output" 2>&1; then
    fail "cleanup accepted unsafe root: $root"
  fi
  grep -F "$expected" "$output" >/dev/null || fail "unexpected rejection for $root"
}

make_old_file() {
  mkdir -p "$(dirname -- "$1")"
  printf 'fixture\n' >"$1"
  touch -d '30 days ago' "$1" 2>/dev/null || touch -t 200001010000 "$1"
}

cleanup() {
  rm -rf -- "$SANDBOX"
}
trap cleanup EXIT HUP INT TERM

assert_rejected / 'filesystem root'
assert_rejected "$HOME" 'user home'

mkdir -p "$SANDBOX/unmarked"
assert_rejected "$SANDBOX/unmarked" 'repository marker'

repo="$SANDBOX/repo"
mkdir -p "$repo"
printf '{}\n' >"$repo/package.json"
make_old_file "$repo/stale.tmp"
dry_output=$(CLEANUP_APPLY=0 "$CLEANUP" "$repo")
assert_exists "$repo/stale.tmp"
printf '%s\n' "$dry_output" | grep -F 'Dry run only' >/dev/null || fail 'dry-run message missing'
CLEANUP_APPLY=1 "$CLEANUP" "$repo" >/dev/null
assert_missing "$repo/stale.tmp"

git_repo="$SANDBOX/git-repo"
mkdir -p "$git_repo"
git -C "$git_repo" init -q
make_old_file "$git_repo/tracked.tmp"
make_old_file "$git_repo/untracked.tmp"
git -C "$git_repo" -c core.autocrlf=false add tracked.tmp
git -C "$git_repo" -c user.name=UEEF -c user.email=ueef@example.invalid commit -qm fixture
CLEANUP_APPLY=1 "$CLEANUP" "$git_repo" >/dev/null
assert_exists "$git_repo/tracked.tmp"
assert_missing "$git_repo/untracked.tmp"

outside="$SANDBOX/outside"
link_repo="$SANDBOX/link-repo"
mkdir -p "$outside" "$link_repo/reports"
printf '{}\n' >"$link_repo/package.json"
make_old_file "$outside/sentinel.tmp"
ln -s "$outside" "$link_repo/build"
ln -s "$outside" "$link_repo/reports/escape"
if [ -L "$link_repo/build" ] && [ -L "$link_repo/reports/escape" ]; then
  CLEANUP_APPLY=1 "$CLEANUP" "$link_repo" >/dev/null
  assert_exists "$outside/sentinel.tmp"
  assert_exists "$link_repo/build"
  assert_exists "$link_repo/reports/escape"
else
  rm -rf -- "$link_repo/build" "$link_repo/reports/escape"
fi

linked_marker_repo="$SANDBOX/linked-marker-repo"
mkdir -p "$linked_marker_repo"
ln -s "$outside" "$linked_marker_repo/.git"
if [ -L "$linked_marker_repo/.git" ]; then assert_rejected "$linked_marker_repo" 'repository marker'; fi

root_link="$SANDBOX/root-link"
ln -s "$repo" "$root_link"
if [ -L "$root_link" ]; then assert_rejected "$root_link" 'symbolic link'; fi

printf 'Shell workspace cleanup tests passed\n'
