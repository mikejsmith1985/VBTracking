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

# A run that never reached a test fails with no assertion at all. Saying only "nothing
# failed" about a build that exploded is worse than saying nothing, so xcodebuild's own
# complaints are printed too -- a missing simulator reads exactly like a compile error
# otherwise, and cost a run to tell apart.
echo
echo "-------------------- WHAT XCODEBUILD SAID --------------------"
printf '%s
' "$lines" | grep -E "^xcodebuild: error:|error: .*\.swift|The following build commands failed" | sort -u | head -20 || true

echo
echo "-------------------- WHAT THE SCREEN HELD --------------------"
# The diagnostic dumps a failing test prints. They are the whole reason those dumps exist.
printf '%s\n' "$lines" | grep -E "Buttons on screen|Text on screen|The bar holds" | sort -u || true

echo
echo "-------------------- THE COUNT --------------------"
printf '%s\n' "$lines" | grep -E "^Executed [0-9]+ test" | sort -u || true

# When every section above came up empty the run still failed, and the digest has said
# nothing at all -- which is exactly what happened to the phone suite. The tail of the log
# is printed as a last resort so a failure can never be silent again.
found=$(printf '%s
' "$lines" | grep -cE "^.*: error: -\[|^xcodebuild: error:|^Executed [0-9]+ test" || true)
if [ "$found" -eq 0 ]; then
  echo
  echo "-------------------- NOTHING MATCHED, SO HERE IS THE END OF THE LOG --------------------"
  printf '%s
' "$lines" | grep -v '^[[:space:]]*$' | tail -60
fi

echo "====================================================="