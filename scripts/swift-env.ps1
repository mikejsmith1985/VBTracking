# The build environment for VBCore on Windows.
#
# Swift on Windows links with MSVC, so three things have to be in the session before
# `swift build` will work: the Visual Studio developer environment, the user PATH (which
# holds the toolchain), and SDKROOT (which holds the standard library). None of them are in
# a shell that was open before the toolchain was installed, which is why this exists rather
# than being someone's forgotten one-liner.
#
# Usage:  . .\scripts\swift-env.ps1

$buildTools = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
$vcvars = "$buildTools\VC\Auxiliary\Build\vcvars64.bat"

if (-not (Test-Path $vcvars)) {
    throw "Visual Studio Build Tools not found at $buildTools. Swift on Windows needs the MSVC linker."
}

cmd /c "call `"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') {
        Set-Item -Path "env:$($matches[1])" -Value $matches[2] -ErrorAction SilentlyContinue
    }
}

$env:Path = $env:Path + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:SDKROOT = [System.Environment]::GetEnvironmentVariable("SDKROOT", "User")

if (-not $env:SDKROOT) { throw "SDKROOT is not set. Reinstall the Swift toolchain." }

Write-Host "Swift:  $((Get-Command swift).Source)"
Write-Host "SDKROOT: $env:SDKROOT"
