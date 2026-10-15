#!/usr/bin/env bash
# Summarizes coverage/lcov.info for the CI run.
#
# `flutter test --coverage` only records files that some test actually loads,
# so a bare percentage over lcov.info hides every file no test touches. This
# reports both numbers: line coverage of the files tests load, and how many
# lib/ files no test loads at all.
set -euo pipefail

lcov="${1:-coverage/lcov.info}"
if [ ! -f "$lcov" ]; then
  echo "No coverage file at $lcov" >&2
  exit 1
fi

read -r found hit files < <(
  awk -F: '/^SF:/{n++} /^LF:/{f+=$2} /^LH:/{h+=$2} END{print f+0, h+0, n+0}' "$lcov"
)
pct=$(awk -v h="$hit" -v f="$found" 'BEGIN{ if (f == 0) print "0.0"; else printf "%.1f", 100 * h / f }')

all_lib=$(find lib -name '*.dart' ! -path '*/generated/*' | sort)
total=$(printf '%s\n' "$all_lib" | grep -c .)
loaded=$(grep '^SF:' "$lcov" | sed 's/^SF://' | sort -u)
unloaded=$(comm -23 <(printf '%s\n' "$all_lib") <(printf '%s\n' "$loaded") | grep -c . || true)

msg="Line coverage of files loaded by tests: ${pct}% (${hit}/${found} lines in ${files} files). Files no test loads: ${unloaded} of ${total}."
echo "$msg"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Test coverage"
    echo
    echo "$msg"
  } >> "$GITHUB_STEP_SUMMARY"
fi
