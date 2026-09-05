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

# The logs are only fetched when something went wrong, and only the error lines are kept. A
# whole xcodebuild log is tens of megabytes and the answer is four lines of it.
$artefact = $build.artefacts | Select-Object -First 1
if ($artefact -and $build.status -ne 'finished') {
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
            if ($hits -or $file.Extension -eq '.txt') {
                $report.Add('')
                $report.Add("--- $($file.Name) ---")
                if ($hits) {
                    $hits | ForEach-Object { $report.Add($_) }
                } else {
                    Get-Content $file.FullName | Select-Object -First 60 | ForEach-Object { $report.Add($_) }
                }
            }
        }
    } catch {
        $report.Add("could not read the artefact: $($_.Exception.Message)")
    }
}

Save $report.ToArray()
