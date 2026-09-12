#!/usr/bin/env bash
# Names a simulator this machine actually has, rather than one it had last week.
#
# The workflow used to name "iPhone 17 Pro" outright. A build image rotated, that device
# went away, and xcodebuild answered "Unable to find a device matching the provided
# destination specifier" -- which exits 70 and reports no failing test, so the run looked
# like a compile error for as long as it took to read the log properly.
#
# The preferred device is asked for first. Falling back is only for the day it is not there,
# and the choice is printed so the log says which machine ran the tests.
set -eu

family="${1:?usage: ci-simulator.sh <iPhone|Apple Watch> [preferred name]}"
preferred="${2:-}"

# The device list can be read from a file instead of the machine, which is the only way this
# parser can be tested anywhere but a Mac. Nothing in CI sets it.
if [ -n "${SIMCTL_DEVICES_FILE:-}" ]; then
  available=$(cat "$SIMCTL_DEVICES_FILE")
else
  available=$(xcrun simctl list devices available)
fi

# The trailing "(UDID) (state)" is REMOVED rather than the name captured. Capturing meant a
# pattern that had to describe the whole line, and the version of it that cut at the first
# bracket turned "Apple Watch Ultra 2 (49mm)" into "Apple Watch Ultra 2" -- a device that
# does not exist, so every watch run died before a test ran. Removing only the part that is
# certainly not the name cannot make that mistake.
names=$(printf '%s\n' "$available" \
  | grep -E "^[[:space:]]*${family}" \
  | grep -v "unavailable" \
  | sed -E 's/[[:space:]]*\([0-9A-Fa-f-]{36}\)[[:space:]]*\([^)]*\)[[:space:]]*$//' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  | grep -v '^$' \
  | sort -u)

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
echo "Wanted '${preferred}', which this machine does not have." >&2
echo "The ${family} simulators it does have:" >&2
printf '%s\n' "$names" | sed 's/^/  /' >&2
echo "Using '${chosen}'." >&2
echo "$chosen"
