#!/usr/bin/env bash
# Runs an interface suite and keeps what can be read afterwards: a digest of what failed,
# and a still of every screen the suite walked through.
#
# It used to record video as well. The recording was 134 MB, Codemagic zips every artifact
# into one download, and that download took longer than the build did -- so the digest
# explaining a failure was unreachable for half an hour at a time. Nobody watched a single
# frame of it. Stills cost kilobytes and can be read at a glance.
#
# Usage: ci-run-tests.sh <family> <preferred device> <scheme> <platform> <log>

set -u

family="$1"
preferred="$2"
scheme="$3"
platform="$4"
log="$5"

device=$(./scripts/ci-simulator.sh "$family" "$preferred")
if [ -z "$device" ]; then
  # Said here rather than left to xcodebuild, which answers an empty destination with
  # "missing value for key 'name'" -- a sentence that names neither the family asked
  # for nor the fact that no device was found.
  echo "No ${family} simulator could be named, so the ${scheme} suite cannot run." >&2
  exit 1
fi
echo "Running ${scheme} on: ${device}"

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

mkdir -p /tmp/digest
./scripts/ci-test-digest.sh "$log" | tee "/tmp/digest/$(basename "${log%.log}").txt"

# The stills the suite took, lifted out of the result bundle. A film can only be judged by
# somebody watching it; a picture can be looked at by anyone, including whoever is reviewing
# this without a Mac. They are named in the test, so they arrive in reading order.
mkdir -p /tmp/shots
xcrun xcresulttool export attachments --path "$results" --output-path /tmp/shots >/dev/null 2>&1 || echo "No stills could be exported."
find /tmp/shots -name '*.png' -print | sort | sed 's/^/  still: /' || true

exit "$status"
