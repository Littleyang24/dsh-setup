# dsh-launch.ps1 - ensure the DSH web server is running (start it hidden if not),
# then optionally open the GUI in the default browser.
# Used by the startup entry and the desktop/start-menu shortcuts via dsh-launch.vbs.
#
# ASCII-only on purpose: this script is parsed by Windows PowerShell 5.1 under
# a non-UTF8 system code page; multi-byte comments could break parsing.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "D:\DSH\scripts\dsh-launch.ps1" -OpenBrowser
param(
    [switch]$OpenBrowser,   # open the GUI in the default browser once the server is ready
    [int]$Port = 3080,      # server port (default 3080; other ports are for testing)
    [switch]$NoLog
)

$ErrorActionPreference = 'Continue'
$HostUrl = "http://127.0.0.1:$Port"
$WorkDir = 'D:\DSH'
$LogDir = Join-Path $WorkDir 'logs'
$LogFile = Join-Path $LogDir 'dsh-launch.log'

function Write-Log([string]$msg) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg"
    if (-not $NoLog) {
        try {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
            Add-Content -Path $LogFile -Value $line -Encoding UTF8
        } catch { }
    }
}

function Test-PortOpen([int]$p, [int]$timeoutMs = 600) {
    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        try {
            $iar = $client.BeginConnect('127.0.0.1', $p, $null, $null)
            $ok = $iar.AsyncWaitHandle.WaitOne($timeoutMs)
            if ($ok -and $client.Connected) { return $true }
        } finally { $client.Close() }
    } catch { }
    return $false
}

Write-Log "dsh-launch: start (Port=$Port OpenBrowser=$OpenBrowser)"

if (-not (Test-PortOpen $Port)) {
    # resolve the dsh command: prefer the global install on PATH, then explicit
    # global shim, then node + the npx-cache bin.js as a last resort
    $dshCmd = $null
    $cmdInfo = Get-Command dsh.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmdInfo) { $cmdInfo = Get-Command dsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($cmdInfo) { $dshCmd = $cmdInfo.Source }
    if (-not $dshCmd) {
        $globalShim = Join-Path $env:APPDATA 'npm\dsh.cmd'
        if (Test-Path $globalShim) { $dshCmd = $globalShim }
    }
    $nodeExe = 'D:\Program Files\nodejs\node.exe'
    $fallbackBin = 'C:\Users\xiaoy\AppData\Local\npm-cache\_npx\1e7f6d9597241db0\node_modules\@deepseek-ai\dsh\lib\bin.js'

    $innerArgs = @('--profile', 'web', '--no-open')
    if ($Port -ne 3080) { $innerArgs += @('--port', "$Port") }

    Write-Log "dsh-launch: server not running on port $Port, starting dsh web (--no-open)"
    $serverProc = $null
    if ($dshCmd) {
        try {
            $serverProc = Start-Process -FilePath $dshCmd -ArgumentList $innerArgs -WorkingDirectory $WorkDir -WindowStyle Hidden -PassThru
            Write-Log "dsh-launch: launched via dsh command: $dshCmd (PID $($serverProc.Id))"
        } catch {
            Write-Log "dsh-launch: Start-Process($dshCmd) failed: $_"
            $serverProc = $null
        }
    }
    if (-not $serverProc -and (Test-Path $nodeExe) -and (Test-Path $fallbackBin)) {
        try {
            Write-Log 'dsh-launch: falling back to node + npx-cache bin.js'
            $serverProc = Start-Process -FilePath $nodeExe -ArgumentList (@($fallbackBin) + $innerArgs) -WorkingDirectory $WorkDir -WindowStyle Hidden -PassThru
            Write-Log "dsh-launch: launched via node fallback (PID $($serverProc.Id))"
        } catch {
            Write-Log "dsh-launch: node fallback failed: $_"
        }
    }

    # wait for the server to accept connections (up to 60 seconds)
    $ready = $false
    for ($i = 0; $i -lt 120; $i++) {
        Start-Sleep -Milliseconds 500
        if (Test-PortOpen $Port) { $ready = $true; break }
        if ($serverProc -and $serverProc.HasExited) {
            Write-Log "dsh-launch: server process exited early (exit code $($serverProc.ExitCode))"
            break
        }
    }
    if ($ready) {
        Write-Log "dsh-launch: server is up on port $Port"
        Start-Sleep -Seconds 2
    } else {
        Write-Log 'dsh-launch: server did not become ready in time'
    }
} else {
    Write-Log "dsh-launch: server already running on port $Port"
}

if ($OpenBrowser) {
    Write-Log "dsh-launch: opening browser at $HostUrl"
    try { Start-Process $HostUrl } catch { Write-Log "dsh-launch: open browser failed: $_" }
}
Write-Log 'dsh-launch: done'
