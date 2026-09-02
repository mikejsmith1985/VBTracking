#!/usr/bin/env bash
# Films a simulator while the interface suite drives it, so the app can be watched before
# anybody installs it.
#
# The film is the point, not a debugging aid. Every screen in this app is written on a
# machine that cannot run it, so until now the first person to SEE a screen was the operator
# holding a phone -- which is how a keyboard that could not be dismissed reached a release.
#
# Usage: ci-film-tests.sh <family> <preferred device> <scheme> <platform> <log> <film>
set -u

family="$1"
preferred="$2"
scheme="$3"
platform="$4"
log="$5"
film="$6"

device=$(./scripts/ci-simulator.sh "$family" "$preferred")

mkdir -p "$(dirname "$film")"

# Booted here rather than left to xcodebuild, because the recorder has to attach to a
# running device before the first test types anything.
xcrun simctl boot "$device" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 || true

xcrun simctl io "$device" recordVideo --codec h264 --force "$film" &
recorder=$!

results="/tmp/results/$(basename "${log%.log}").xcresult"
rm -rf "$results"
mkdir -p /tmp/results

status=0
set -o pipefail
xcodebuild test \
  -project ios/VBTracker.xcodeproj \
  -scheme "$scheme" \
  -destination "platform=$platform,name=$device" \
  -resultBundlePath "$results" \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$log" | tail -200 || status=$?

# The one process this script started, addressed by the pid it was given. Never a pattern:
# a pattern kill on a build machine is how an agent ends its own session.
kill -INT "$recorder" 2>/dev/null || true
wait "$recorder" 2>/dev/null || true

mkdir -p /tmp/digest
./scripts/ci-test-digest.sh "$log" | tee "/tmp/digest/$(basename "${log%.log}").txt"

# The stills the suite took, lifted out of the result bundle. A film can only be judged by
# somebody watching it; a picture can be looked at by anyone, including whoever is reviewing
# this without a Mac. They are named in the test, so they arrive in reading order.
mkdir -p /tmp/shots
xcrun xcresulttool export attachments --path "$results" --output-path /tmp/shots >/dev/null 2>&1 || echo "No stills could be exported."
find /tmp/shots -name '*.png' -print | sort | sed 's/^/  still: /' || true

if [ -s "$film" ]; then
  echo "Film: $film ($(du -h "$film" | cut -f1))"
else
  echo "No film was made."
fi

exit "$status"
