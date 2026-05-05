# Stops SSH tunnel processes that forward localhost:8080 to Kafka UI.

$ErrorActionPreference = "Stop"
$pidFile = Join-Path $PSScriptRoot "kafka-ui-tunnel.pid"

function Write-Info([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-WarnMsg([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Remove-PidFile {
    Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $pidFile)) {
    Write-WarnMsg "No managed Kafka UI tunnel PID file found. Nothing to stop."
    exit 0
}

$pidRaw = (Get-Content -Path $pidFile -Raw).Trim()
if (-not $pidRaw -or -not ($pidRaw -as [int])) {
    Write-WarnMsg "PID file is invalid. Removing it."
    Remove-PidFile
    exit 0
}

$tunnelPid = [int]$pidRaw
$tunnelProcess = Get-CimInstance Win32_Process -Filter "Name='ssh.exe' AND ProcessId=$tunnelPid" -ErrorAction SilentlyContinue
if (-not $tunnelProcess) {
    Write-WarnMsg "Managed tunnel PID $tunnelPid is not running. Removing stale PID file."
    Remove-PidFile
    exit 0
}

if ($tunnelProcess.CommandLine -notmatch "-L\s*8080:127\.0\.0\.1:8080") {
    Write-WarnMsg "Process PID $tunnelPid is not a Kafka UI tunnel command. Refusing to stop unrelated ssh process."
    Remove-PidFile
    exit 1
}

try {
    Stop-Process -Id $tunnelPid -ErrorAction Stop
    Write-Info "Stopped managed ssh tunnel process PID $tunnelPid."
    Remove-PidFile
} catch {
    Write-WarnMsg "Could not stop PID ${tunnelPid}: $($_.Exception.Message)"
    exit 1
}

exit 0
