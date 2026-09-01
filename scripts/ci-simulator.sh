#!/usr/bin/env bash
# Names a simulator this machine actually has, rather than one it had last week.
#
# The workflow used to name "iPhone 17 Pro" outright. A build image rotated, that device
# went away, and xcodebuild answered "Unable to find a device matching the provided
# destination specifier" -- which exits 70 and reports no failing test, so the run looked
# like a compile error for as long as it took to read the log properly.
#
# The preferred device is still asked for first. Falling back is only for the day it is not
# there, and the choice is printed so the log says which machine ran the tests.
set -eu

family="${1:?usage: ci-simulator.sh <iPhone|Apple Watch> [preferred name]}"
preferred="${2:-}"

available=$(xcrun simctl list devices available)
names=$(printf '%s\n' "$available" | sed -n "s/^ *\(${family}[^(]*\) (.*/\1/p" | sed 's/ *$//' | sort -u)

if [ -z "$names" ]; then
  echo "No ${family} simulator is installed on this machine." >&2
  printf '%s\n' "$available" >&2
  exit 1
fi

if [ -n "$preferred" ] && printf '%s\n' "$names" | grep -qxF "$preferred"; then
  echo "$preferred"
  exit 0
fi

# Sorted last, which puts the highest model number at the end -- the newest the machine has.
chosen=$(printf '%s\n' "$names" | tail -1)
echo "Wanted '${preferred}', which this machine does not have. Using '${chosen}'." >&2
echo "$chosen"
