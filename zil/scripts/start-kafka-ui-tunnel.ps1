# Starts (if needed) an SSH tunnel: Kafka UI (8080) + brokers LAB11 (19094/19095).
# Uses ClearAllForwardings so LocalForward lines in ssh config do not double-bind local ports.
# Safe to run repeatedly: existing tunnel is reused, duplicates are not started.

$ErrorActionPreference = "Stop"

$localUrl = "http://127.0.0.1:8080/"
$aliasTarget = "zil-hl15"
$fallbackTarget = "hl@hlssh.zil.digital"
$identityFile = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
$forwardArgs = @(
    "-L", "8080:127.0.0.1:8080",
    "-L", "19094:hl15.zil:9094",
    "-L", "19095:hl14.zil:9094"
)
$sshCommonArgs = @(
    "-N",
    "-o", "ClearAllForwardings=yes",
    "-o", "BatchMode=yes",
    "-o", "ExitOnForwardFailure=yes",
    "-o", "ConnectTimeout=12"
)
$pidFile = Join-Path $PSScriptRoot "kafka-ui-tunnel.pid"

function Write-Info([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-WarnMsg([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorMsg([string]$Message) {
    Write-Host $Message -ForegroundColor Red
}

function Get-ManagedTunnelProcess {
    if (-not (Test-Path $pidFile)) {
        return $null
    }

    $pidRaw = (Get-Content -Path $pidFile -Raw).Trim()
    if (-not $pidRaw -or -not ($pidRaw -as [int])) {
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        return $null
    }

    $managedPid = [int]$pidRaw
    $proc = Get-CimInstance Win32_Process -Filter "Name='ssh.exe' AND ProcessId=$managedPid" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        return $null
    }

    if ($proc.CommandLine -notmatch "-L\s*8080:127\.0\.0\.1:8080") {
        Write-WarnMsg "PID file points to PID $managedPid, but command does not match Kafka UI tunnel. Cleaning stale PID file."
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        return $null
    }

    return $proc
}

function Ensure-KeyInAgent {
    if (-not (Test-Path -LiteralPath $identityFile)) {
        return
    }
    $prevEa = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    try {
        $agentSvc = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
        if ($agentSvc -and $agentSvc.Status -ne "Running") {
            Set-Service -Name ssh-agent -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name ssh-agent -ErrorAction SilentlyContinue
        }
        & ssh-add $identityFile 2>&1 | Out-Null
    } finally {
        $ErrorActionPreference = $prevEa
    }
}

function Get-Port8080Listener {
    Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
        Select-Object -First 1
}

function Remove-PidFile {
    Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
}

function Wait-TunnelReady([System.Diagnostics.Process]$Process) {
    Start-Sleep -Milliseconds 500
    for ($i = 0; $i -lt 12; $i++) {
        if ($Process.HasExited) {
            return $false
        }

        $probe = Get-Port8080Listener
        if ($probe -and $probe.OwningProcess -eq $Process.Id) {
            return $true
        }

        Start-Sleep -Milliseconds 300
    }

    return $false
}

function Start-TunnelAttempt([string]$Target, [string[]]$TargetArgs, [string]$Description) {
    $sshArgs = $sshCommonArgs + $forwardArgs + $TargetArgs + @($Target)
    Write-Info "Starting LAB11 Kafka tunnel (UI + brokers) using $Description ..."
    $process = Start-Process -FilePath $sshCommand.Source -ArgumentList $sshArgs -PassThru -WindowStyle Hidden

    if (-not (Wait-TunnelReady -Process $process)) {
        if (-not $process.HasExited) {
            try {
                Stop-Process -Id $process.Id -ErrorAction Stop
            } catch {
                Write-WarnMsg "Failed to stop incomplete tunnel process PID $($process.Id): $($_.Exception.Message)"
            }
        }
        return $null
    }

    return $process
}

try {
    $sshCommand = Get-Command ssh -ErrorAction Stop
} catch {
    Write-ErrorMsg "ssh is not available in PATH. Install OpenSSH client and try again."
    exit 1
}

Ensure-KeyInAgent

$existingTunnel = Get-ManagedTunnelProcess
if ($existingTunnel) {
    Write-Info "Kafka UI tunnel already running (ssh pid: $($existingTunnel.ProcessId))."
    Write-Info "Opening $localUrl"
    Start-Process $localUrl
    exit 0
}

$listener = Get-Port8080Listener
if ($listener) {
    $busyPid = $listener.OwningProcess
    $busyProc = Get-Process -Id $busyPid -ErrorAction SilentlyContinue
    $busyName = if ($busyProc) { $busyProc.ProcessName } else { "PID $busyPid" }
    Write-ErrorMsg "Port 8080 is already in use by $busyName. Tunnel was not started."
    Write-WarnMsg "Stop that process (or free port 8080) and run the script again."
    exit 1
}

$sshProcess = Start-TunnelAttempt -Target $aliasTarget -TargetArgs @() -Description "SSH alias '$aliasTarget'"
if (-not $sshProcess) {
    Write-WarnMsg "Alias startup failed. Falling back to '$fallbackTarget' with explicit port and key."
    $fallbackArgs = @(
        "-p", "2315",
        "-i", $identityFile,
        "-o", "IdentitiesOnly=yes"
    )
    $sshProcess = Start-TunnelAttempt -Target $fallbackTarget -TargetArgs $fallbackArgs -Description "direct host '$fallbackTarget'"
}

if (-not $sshProcess) {
    Remove-PidFile
    Write-ErrorMsg "Could not start the Kafka tunnel (auth or network). Your key must be in ~/.ssh/authorized_keys on hl15 (port 2315)."
    Write-WarnMsg "One-time fix (password once): powershell -NoProfile -ExecutionPolicy Bypass -File .\zil\scripts\once-bootstrap-kafka-ssh-keys.ps1"
    Write-WarnMsg "Optional hl14: same script with -Hl14. Or ask the course admin to register your pubkey."
    exit 1
}

Set-Content -Path $pidFile -Value $sshProcess.Id -NoNewline
Write-Info "Tunnel is ready. Opening $localUrl"
Start-Process $localUrl
exit 0
