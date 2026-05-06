# One-time: append your id_ed25519.pub to ~/.ssh/authorized_keys on hl15 (and optionally hl14).
# Use when ssh zil-hl15 works with password but BatchMode tunnel fails (key not on VM yet).
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\zil\scripts\once-bootstrap-kafka-ssh-keys.ps1
#   powershell ... -File .\zil\scripts\once-bootstrap-kafka-ssh-keys.ps1 -Hl14

param(
    [switch] $Hl14
)

$ErrorActionPreference = "Stop"

$pub = Join-Path $env:USERPROFILE ".ssh\id_ed25519.pub"
if (-not (Test-Path -LiteralPath $pub)) {
    Write-Host "Missing $pub — generate a key first (ssh-keygen) or fix the path." -ForegroundColor Red
    exit 1
}

$sshOpts = @("-o", "StrictHostKeyChecking=accept-new")
$remoteShell = 'umask 077; mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'

function Install-Key([string]$label) {
    Write-Host "`nAppending public key on $label (enter password if asked once)...`n" -ForegroundColor Cyan
    Get-Content -LiteralPath $pub | & ssh @sshOpts $label $remoteShell
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed for $label (exit $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "OK: $label" -ForegroundColor Green
}

Install-Key "zil-hl15"
if ($Hl14) {
    Install-Key "zil-hl14"
}

Write-Host "`nVerify (should print hostname, no password):" -ForegroundColor Cyan
& ssh -o BatchMode=yes -o ConnectTimeout=10 zil-hl15 "hostname -f"
exit $LASTEXITCODE
