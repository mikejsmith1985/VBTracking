# Sends a branch to TestFlight, and watches the build that results.
#
# The `ios-watch` workflow has no triggers of its own on purpose: a build that signs, uploads
# and consumes a TestFlight build number should happen because somebody asked for it, not
# because a branch moved. So it is started here, by name, against a named branch.
#
# It lived in a scratch folder for most of this project's life, which meant the branch it
# built was a fact nobody could read and nothing could review. It builds `main` now, and that
# is visible in the repository like everything else.
#
# Nothing here writes the token: it is read from the environment the vault injected and used
# only as a request header.
param(
    [string]$Branch = 'main',
    [string]$Workflow = 'ios-watch',
    [string]$OutFile = "$env:TEMP\vbtracking-build.txt",
    [int]$TimeoutMinutes = 40
)

$ErrorActionPreference = 'Stop'

if (-not $env:CODEMAGIC_API_TOKEN) {
    throw 'No CODEMAGIC_API_TOKEN in the environment. Inject it with the Forge Vault first.'
}

$appId = '6a936398b0228428dad92e84'
$headers = @{ 'x-auth-token' = $env:CODEMAGIC_API_TOKEN; 'Content-Type' = 'application/json' }
$body = @{ appId = $appId; workflowId = $Workflow; branch = $Branch } | ConvertTo-Json

$reply = Invoke-RestMethod -Method Post -Uri 'https://api.codemagic.io/builds' -Headers $headers -Body $body
$buildId = $reply.buildId
"branch:  $Branch"
"workflow: $Workflow"
"buildId: $buildId"

# The watcher runs on its own so this returns at once. A build takes tens of minutes and
# nothing is gained by holding a terminal open for it.
Remove-Item $OutFile -ErrorAction SilentlyContinue
$watcher = Join-Path $PSScriptRoot 'watch-build.ps1'
Start-Process pwsh -ArgumentList @(
    '-NoProfile', '-File', $watcher,
    '-BuildId', $buildId,
    '-OutFile', $OutFile,
    '-TimeoutMinutes', "$TimeoutMinutes"
) -WindowStyle Hidden

"watching: $OutFile"
