# enable-defender-exclusions.ps1 - add DSH-related paths to Windows Defender
# exclusions so cold starts are not slowed down by real-time on-access scans.
# MUST be run from an ELEVATED (Administrator) PowerShell.
# ASCII-only on purpose.
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Continue'

$paths = @(
    (Join-Path $env:APPDATA 'npm\node_modules'),
    (Join-Path $env:LOCALAPPDATA 'npm-cache'),
    (Join-Path $env:USERPROFILE '.dsh'),
    $RepoRoot
)

foreach ($p in $paths) {
    try {
        Add-MpPreference -ExclusionPath $p
        Write-Output ("Added exclusion: " + $p)
    } catch {
        Write-Output ("FAILED: " + $p + " -> " + $_.Exception.Message)
    }
}

Write-Output 'Done. The exclusions are active now.'
