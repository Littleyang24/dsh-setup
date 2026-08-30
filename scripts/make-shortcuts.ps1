# make-shortcuts.ps1 - create DSH shortcuts:
#   1. Startup folder  : DSH-autostart.lnk  (auto-start DSH at logon, then open the GUI)
#   2. Desktop         : DSH.lnk
#   3. Start menu      : Programs\DSH\DSH.lnk
# All three point to wscript.exe + dsh-launch.vbs (hidden window, no console flash).
# ASCII-only on purpose: parsed by Windows PowerShell 5.1 under a non-UTF8 code page.
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'

$ws = New-Object -ComObject WScript.Shell
$icon = (Join-Path $RepoRoot 'assets\dsh.ico') + ',0'
$vbs = '"' + (Join-Path $RepoRoot 'scripts\dsh-launch.vbs') + '"'

function New-DshShortcut {
    param([string]$Path, [string]$Name, [string]$Desc)
    $lnkPath = Join-Path $Path ($Name + '.lnk')
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
    $sc.Arguments = $vbs
    $sc.WorkingDirectory = $RepoRoot
    $sc.IconLocation = $icon
    $sc.Description = $Desc
    $sc.Save()
    Write-Output "Created: $lnkPath"
}

# 1. Startup folder (runs at every logon)
# "DSH kaiji-zidongqi" (auto-start) built from char codes to keep this file ASCII-only
$startupName = 'DSH ' + [char]0x5F00 + [char]0x673A + [char]0x81EA + [char]0x542F
$startupDir = [Environment]::GetFolderPath('Startup')
New-DshShortcut -Path $startupDir -Name $startupName -Desc 'Start the DeepSeek Harness (DSH) web server at logon and open the GUI'

# 2. Desktop
$desktopDir = [Environment]::GetFolderPath('Desktop')
New-DshShortcut -Path $desktopDir -Name 'DSH' -Desc 'Open the DeepSeek Harness (DSH) web GUI'

# 3. Start menu (Programs\DSH)
$programsDir = [Environment]::GetFolderPath('Programs')
$appDir = Join-Path $programsDir 'DSH'
New-Item -ItemType Directory -Path $appDir -Force | Out-Null
New-DshShortcut -Path $appDir -Name 'DSH' -Desc 'Open the DeepSeek Harness (DSH) web GUI'

Write-Output 'All shortcuts created.'
