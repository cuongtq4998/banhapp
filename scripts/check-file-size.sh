#!/usr/bin/env bash
# Enforces the project rule "at most 200 lines per hand-written file" (CLAUDE.md).
# Known violations are listed in scripts/file-size-baseline.txt as "<lines> <path>"; the list may only shrink:
# a listed file must not grow, a new file must not pass the limit, and a listed file that fits again must be removed.
# Portable to bash 3.2 (macOS) and to the CI images.
set -euo pipefail

LIMIT=200
cd "$(git rev-parse --show-toplevel)"
BASELINE=scripts/file-size-baseline.txt
[ -f "$BASELINE" ] || : > "$BASELINE"

# Generated, machine-owned and already-applied files are exempt (CLAUDE.md): an applied migration is never edited.
is_checked() {
  case "$1" in
    *.pbxproj|*.lock|*Package.resolved|*.json|*.ttf|*.otf|*.png|*.jpg|*.svg|*.jar|*.xcstrings|*.html) return 1 ;;
    contracts/fixtures/*|backend/db/migrations/*|*/gradlew|*/gradlew.bat|"$BASELINE") return 1 ;;
    *.swift|*.kt|*.kts|*.md|*.yml|*.yaml|*.sh|*.py|*.sql|*.toml|*.xml|*.properties|Dockerfile|*/Dockerfile) return 0 ;;
    *) return 1 ;;
  esac
}

recorded_lines() { awk -v p="$1" '$2 == p { print $1 }' "$BASELINE"; }

status=0
while IFS= read -r path; do
  is_checked "$path" || continue
  [ -f "$path" ] || continue
  lines=$(wc -l < "$path" | tr -d ' ')
  allowed=$(recorded_lines "$path")
  if [ "$lines" -gt "$LIMIT" ]; then
    if [ -z "$allowed" ]; then
      echo "ERROR: $path has $lines lines (limit $LIMIT); split it by responsibility."; status=1
    elif [ "$lines" -gt "$allowed" ]; then
      echo "ERROR: $path grew from $allowed to $lines lines; split it instead of growing it."; status=1
    fi
  elif [ -n "$allowed" ]; then
    echo "ERROR: $path now has $lines lines; remove it from $BASELINE."; status=1
  fi
done < <(git ls-files)

while read -r _ path; do
  [ -n "${path:-}" ] && [ ! -f "$path" ] && { echo "ERROR: $path is in the baseline but no longer exists; remove the entry."; status=1; }
done < "$BASELINE"
exit $status
