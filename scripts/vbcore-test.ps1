# Runs the VBCore suite: the rulebook, and the parity proof against the shipped web app.
#
# This is the whole local loop. Everything with a screen in it is built on the cloud
# service; this is the part that can be run here, and it is the part with the rules in it.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\swift-env.ps1"
Push-Location "$PSScriptRoot\..\packages\VBCore"
try {
    swift test @args
} finally {
    Pop-Location
}
