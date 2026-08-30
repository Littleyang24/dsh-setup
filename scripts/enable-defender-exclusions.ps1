# enable-defender-exclusions.ps1 - add DSH-related paths to Windows Defender
# exclusions so cold starts are not slowed down by real-time on-access scans.
# MUST be run from an ELEVATED (Administrator) PowerShell.
# ASCII-only on purpose.
$ErrorActionPreference = 'Continue'

$paths = @(
    'C:\Users\xiaoy\AppData\Roaming\npm\node_modules',
    'C:\Users\xiaoy\AppData\Local\npm-cache',
    'C:\Users\xiaoy\.dsh',
    'D:\DSH'
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
