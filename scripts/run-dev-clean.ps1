# Launches the app for development from a clean state. The UX suite runs against this,
# never against a built binary -- there is no build step in this project.
#
# Usage:  .\scripts\run-dev-clean.ps1 [-Port 5173]

[CmdletBinding()]
param(
  [int]$Port = 5173
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Serving $repoRoot on http://localhost:$Port" -ForegroundColor Cyan
Write-Host ''
Write-Host 'localhost counts as a secure context, so the service worker registers and' -ForegroundColor DarkGray
Write-Host 'offline behaviour can be exercised in DevTools. Install and true offline'    -ForegroundColor DarkGray
Write-Host 'behaviour must still be verified on the device (quickstart.md V-7).'          -ForegroundColor DarkGray
Write-Host ''

# Article II: never wildcard-kill. Only a process already bound to this exact port is
# stopped, and only by its own PID.
$occupied = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
foreach ($connection in $occupied) {
  $ownerPid = $connection.OwningProcess
  if (-not $ownerPid) { continue }
  $owner = Get-Process -Id $ownerPid -ErrorAction SilentlyContinue
  if (-not $owner) { continue }
  Write-Host "Stopping process $($owner.ProcessName) (PID $ownerPid) holding port $Port" -ForegroundColor Yellow
  Stop-Process -Id $ownerPid -Force
}

Set-Location $repoRoot
npx --yes serve . -l $Port
