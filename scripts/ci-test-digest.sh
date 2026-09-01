#!/usr/bin/env bash
# Prints what failed in an xcodebuild test run, last, so it survives a truncated log.
#
# A build log keeps only its final stretch. An interface run is long enough that the early
# failures scroll off it, which is how five failing tests once showed up as one: the four
# that mattered were gone before anybody read them. Writing the whole run to a file and
# digesting it at the end puts the answer where truncation cannot reach.
set -u
log="${1:?usage: ci-test-digest.sh <log file>}"

echo
echo "==================== WHAT FAILED ===================="

if [ ! -s "$log" ]; then
  echo "The log is empty, so the run produced nothing to read."
  exit 0
fi

# Split on both kinds of line ending: a message printed by a test can carry either.
lines=$(tr '\r' '\n' < "$log")

failures=$(printf '%s\n' "$lines" | grep -E "^.*: error: -\[" || true)
if [ -n "$failures" ]; then
  # The file and line are noise once the test name is there; the message is the point.
  printf '%s\n' "$failures" | sed -E 's|^.*/([^/]+\.swift:[0-9]+): error: |\1  |'
else
  echo "No failing assertion was reported."
fi

echo
echo "-------------------- WHAT THE SCREEN HELD --------------------"
# The diagnostic dumps a failing test prints. They are the whole reason those dumps exist.
printf '%s\n' "$lines" | grep -E "Buttons on screen|Text on screen|The bar holds" | sort -u || true

echo
echo "-------------------- THE COUNT --------------------"
printf '%s\n' "$lines" | grep -E "^Executed [0-9]+ test" | sort -u || true
echo "====================================================="
