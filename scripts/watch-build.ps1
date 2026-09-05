# Waits for a cloud build to finish and writes down what it said.
#
# The build machine is the only place the iOS targets compile, so every compile error costs a
# round trip. Hand-polling that round trip turns a five-minute fix into a conversation, and a
# guess made while waiting costs another build.
#
# So this waits, and when the build ends it writes the verdict and every error line to a file.
# Nothing here ever writes the token: it is read from the environment the vault injected and
# used only as a request header.
param(
    [Parameter(Mandatory = $true)][string]$BuildId,
    [Parameter(Mandatory = $true)][string]$OutFile,
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = 'Stop'
$headers = @{ 'x-auth-token' = $env:CODEMAGIC_API_TOKEN }
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$report = New-Object System.Collections.Generic.List[string]

function Save([string[]]$lines) {
    $directory = Split-Path -Parent $OutFile
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -ItemType Directory -Force $directory | Out-Null
    }
    Set-Content -Path $OutFile -Value $lines -Encoding UTF8
}

while ($true) {
    if ((Get-Date) -gt $deadline) {
        Save @("status: timed out after $TimeoutMinutes minutes", "build: $BuildId")
        exit 0
    }

    try {
        $build = (Invoke-RestMethod -Uri "https://api.codemagic.io/builds/$BuildId" -Headers $headers).build
    } catch {
        Start-Sleep -Seconds 20
        continue
    }

    if ($build.status -in 'finished', 'failed', 'canceled', 'timeout') { break }
    Start-Sleep -Seconds 20
}

$report.Add("status: $($build.status)")
$report.Add("build: $BuildId")
$report.Add('')
foreach ($step in $build.buildActions) { $report.Add("  $($step.name): $($step.status)") }

# The artefact is always read. A whole xcodebuild log is tens of megabytes and only its error
# lines are worth keeping, but anything else in there was put there deliberately to be read.
$artefact = $build.artefacts | Select-Object -First 1
if ($artefact) {
    $folder = Join-Path ([System.IO.Path]::GetTempPath()) "watch-$BuildId"
    Remove-Item -Recurse -Force $folder -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $folder | Out-Null
    try {
        Invoke-WebRequest -Uri $artefact.url -Headers $headers -OutFile "$folder\a.zip"
        Expand-Archive "$folder\a.zip" -DestinationPath $folder -Force
        foreach ($file in Get-ChildItem -Recurse $folder -Include *.log, *.txt) {
            $hits = Select-String -Path $file.FullName -Pattern 'error:' |
                Select-Object -ExpandProperty Line -Unique |
                Select-Object -First 25
            # An xcodebuild log is only worth its error lines. Anything else in the artefact
            # was put there deliberately to be read, so it is printed whether it mentions an
            # error or not -- a filter that hid such a file cost two whole builds.
            $isBuildLog = $file.Name -in 'phone.log', 'watch.log'
            $report.Add('')
            $report.Add("--- $($file.Name) ---")
            if ($isBuildLog) {
                if ($hits) {
                    $hits | ForEach-Object { $report.Add($_) }
                } else {
                    $report.Add('(no error lines)')
                }
            } else {
                Get-Content $file.FullName | Select-Object -First 80 | ForEach-Object { $report.Add($_) }
            }
        }
    } catch {
        $report.Add("could not read the artefact: $($_.Exception.Message)")
    }
}

Save $report.ToArray()
