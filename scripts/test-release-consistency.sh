#!/usr/bin/env sh
set -eu

ROOT=$(CDPATH= cd -- "${1:-$(dirname -- "$0")/..}" && pwd)
manifest="$ROOT/release-manifest.json"
metadata=$(node -e '
  const fs = require("fs");
  const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  const version = String(manifest.version || "");
  const releaseDate = String(manifest.releaseDate || "");
  if (!/^\d+\.\d+\.\d+$/.test(version)) throw new Error(`Invalid manifest version: ${version}`);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(releaseDate)) throw new Error(`Invalid manifest release date: ${releaseDate}`);
  const parsed = new Date(`${releaseDate}T00:00:00Z`);
  if (Number.isNaN(parsed.valueOf()) || parsed.toISOString().slice(0, 10) !== releaseDate) {
    throw new Error(`Invalid manifest release date: ${releaseDate}`);
  }
  process.stdout.write(`${version}\n${releaseDate}\n`);
' "$manifest")
version=$(printf '%s\n' "$metadata" | sed -n '1p')
release_date=$(printf '%s\n' "$metadata" | sed -n '2p')

require_literal() {
  file="$1"
  expected="$2"
  [ -f "$ROOT/$file" ] || { echo "Missing release file: $file" >&2; exit 1; }
  grep -Fq "$expected" "$ROOT/$file" || { echo "$file is not aligned with release $version; missing: $expected" >&2; exit 1; }
}

require_literal VERSION.md "version: $version."
require_literal README.md "current release is $version"
require_literal QUICK_START.md "current release is $version"
require_literal INSTALL.md "current release is $version"
require_literal CHANGELOG.md "through \`v$version\`"
require_literal CHANGELOG.md "## $version - $release_date"

expected_notes="docs/releases/v$version.md"
grep -Fq "\"releaseNotes\": \"$expected_notes\"" "$manifest" || { echo "Manifest releaseNotes must be $expected_notes" >&2; exit 1; }
require_literal "$expected_notes" "# UEEF $version"
require_literal "$expected_notes" "Release date: $release_date"
markdown_count=$(find "$ROOT" -path "$ROOT/.git" -prune -o -path "$ROOT/.ueef" -prune -o -name '*.md' -type f -print | wc -l | tr -d ' ')
manifest_markdown=$(node -e 'const m=require(process.argv[1]); process.stdout.write(String(m.trackedMarkdownFiles || 0))' "$manifest")
[ "$markdown_count" -eq "$manifest_markdown" ] || { echo "Manifest Markdown inventory mismatch: $manifest_markdown != $markdown_count" >&2; exit 1; }

echo "Release consistency tests passed for $version"
