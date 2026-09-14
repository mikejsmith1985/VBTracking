#!/usr/bin/env bash
# Proves the simulator picker names devices the way the machine names them.
#
# It reads a captured copy of `xcrun simctl list devices available` rather than a Mac, which
# is what lets it run on the machine this project is written on. Two real failures came from
# this one parser -- a watch name cut at its first bracket, and then a pattern that matched
# nothing at all and left the destination without a name -- and both were invisible until a
# cloud build had already spent twenty minutes.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
export SIMCTL_DEVICES_FILE="$here/simctl-sample.txt"

failed=0

expect() {
  local what="$1" want="$2" got="$3"
  if [ "$got" = "$want" ]; then
    echo "  ok  $what"
  else
    echo "  FAIL $what"
    echo "       wanted: '$want'"
    echo "       got:    '$got'"
    failed=1
  fi
}

pick() { bash "$root/scripts/ci-simulator.sh" "$@" 2>/dev/null; }

echo "The simulator picker:"

expect "asks for the phone it prefers" \
  "iPhone 17 Pro" "$(pick 'iPhone' 'iPhone 17 Pro')"

# A watch carries its size inside its name. This is the one that broke.
expect "keeps the size that is part of a watch's name" \
  "Apple Watch Ultra 2 (49mm)" "$(pick 'Apple Watch' 'Apple Watch Ultra 2 (49mm)')"

expect "falls back to the newest phone it has" \
  "iPhone 17 Pro Max" "$(pick 'iPhone' 'iPhone 99 Pro')"

expect "falls back to a watch it has" \
  "Apple Watch Ultra 2 (49mm)" "$(pick 'Apple Watch' 'Apple Watch Ultra 9 (49mm)')"

# An empty answer is what leaves xcodebuild with "missing value for key 'name'", which reads
# like nothing at all in a log. It must never be the outcome of a successful run.
for family in 'iPhone' 'Apple Watch'; do
  got=$(pick "$family" '')
  if [ -n "$got" ]; then
    echo "  ok  never answers with nothing for $family"
  else
    echo "  FAIL never answers with nothing for $family"
    failed=1
  fi
done

exit "$failed"
