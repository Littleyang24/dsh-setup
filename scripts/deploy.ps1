# deploy.ps1 - one-click setup of the DSH autostart + shortcuts on a Windows PC.
# Designed for a NEW computer after `git clone` of this repository:
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
#
# What it does:
#   1. Locates Node.js (and adds its folder to the user PATH if missing)
#   2. Installs @deepseek-ai/dsh globally if it is not present (-InstallDsh forces reinstall)
#   3. Writes the logon Run key so the DSH server starts at every logon
#   4. Generates the shortcut icon if missing and creates the startup-folder /
#      desktop / start-menu shortcuts
#   5. Optionally adds Windows Defender exclusions (-DefenderExclusions, needs admin)
#
# ASCII-only on purpose: parsed by Windows PowerShell 5.1 under any code page.
param(
    [switch]$InstallDsh,          # force (re)install of @deepseek-ai/dsh
    [switch]$DefenderExclusions   # add Defender exclusions (requires an elevated shell)
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$vbs = Join-Path $RepoRoot 'scripts\dsh-launch.vbs'
$icon = Join-Path $RepoRoot 'assets\dsh.ico'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'DSH Server'
$wscript = Join-Path $env:WINDIR 'System32\wscript.exe'

function Write-Step($msg) { Write-Host "[deploy] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[deploy] OK: $msg" -ForegroundColor Green }

Write-Step "Deploying DSH setup from $RepoRoot"

# ---- 1. Node.js ----
$node = Get-Command node.exe -CommandType Application -ErrorAction SilentlyContinue
if (-not $node) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'nodejs\node.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\nodejs\node.exe'),
        'D:\Program Files\nodejs\node.exe'
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $node = Get-Item $c; break }
    }
}
if (-not $node) {
    Write-Host '[deploy] ERROR: Node.js not found. Install Node.js LTS from https://nodejs.org and re-run.' -ForegroundColor Red
    exit 1
}
Write-Ok ("Node.js: " + $node.Source)

# ensure node's folder is on the user PATH so the VBS wrapper can resolve node.exe at logon
$nodeDir = Split-Path $node.Source
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike ('*' + $nodeDir + '*')) {
    $newPath = $userPath.TrimEnd(';') + ';' + $nodeDir
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Ok ("Added to user PATH: " + $nodeDir)
} else {
    Write-Ok ("Node already on user PATH: " + $nodeDir)
}

# ---- 2. dsh global install ----
$dshBin = Join-Path $env:APPDATA 'npm\node_modules\@deepseek-ai\dsh\lib\bin.js'
$dshFound = Test-Path $dshBin
if ($InstallDsh -or -not $dshFound) {
    if ($InstallDsh) { Write-Step 'Reinstalling @deepseek-ai/dsh (global)' }
    else { Write-Step '@deepseek-ai/dsh not found - installing globally' }
    & npm install -g @deepseek-ai/dsh --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[deploy] ERROR: npm install -g @deepseek-ai/dsh failed.' -ForegroundColor Red
        exit 1
    }
    $dshFound = Test-Path $dshBin
}
if ($dshFound) { Write-Ok ("dsh CLI: " + $dshBin) }
else {
    Write-Host '[deploy] WARNING: could not locate the dsh CLI (lib/bin.js). The server will not start until it is installed.' -ForegroundColor Yellow
}

# ---- 3. Logon Run key (start the server at every logon) ----
$runValue = '"' + $wscript + '" "' + $vbs + '" server'
Set-ItemProperty -Path $runKey -Name $runName -Value $runValue -Type String
Write-Ok ("Run key set: " + $runValue)

# ---- 4. Icon + shortcuts ----
if (-not (Test-Path $icon)) {
    Write-Step 'Generating shortcut icon'
    & (Join-Path $PSScriptRoot 'make-icon.ps1') -RepoRoot $RepoRoot
}
Write-Step 'Creating shortcuts (startup folder / desktop / start menu)'
& (Join-Path $PSScriptRoot 'make-shortcuts.ps1') -RepoRoot $RepoRoot

# ---- 5. Defender exclusions (optional, admin) ----
if ($DefenderExclusions) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Write-Step 'Adding Windows Defender exclusions'
        & (Join-Path $PSScriptRoot 'enable-defender-exclusions.ps1') -RepoRoot $RepoRoot
    } else {
        Write-Host '[deploy] -DefenderExclusions requires an elevated shell. Run scripts\enable-defender-exclusions.ps1 as Administrator instead.' -ForegroundColor Yellow
    }
}

# ---- 6. Summary ----
Write-Host ''
Write-Host '==============================' -ForegroundColor Green
Write-Host ' DSH deployment finished!' -ForegroundColor Green
Write-Host '==============================' -ForegroundColor Green
Write-Host (' Repo : ' + $RepoRoot)
Write-Host ' Next steps:'
Write-Host '   1) Log off and back on (or reboot): the logon Run key starts the server.'
Write-Host '   2) The browser opens http://127.0.0.1:3080 automatically.'
Write-Host ('   3) Test now:  wscript.exe "' + $vbs + '"')
Write-Host (' Logs: ' + (Join-Path $RepoRoot 'logs\dsh-launch.log'))
