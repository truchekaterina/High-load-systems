# Interactive SSH to Kafka manager side (course gateway port 2315 -> hl15).
# Prefer Host zil-hl15 in %USERPROFILE%\.ssh\config — see LAB11 §0.3 / LAB12 §1.3.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File .\zil\scripts\ssh-zil-hl15.ps1
#        ... same script with extra ssh args forwarded: .\ssh-zil-hl15.ps1 docker node ls

$ErrorActionPreference = "Stop"

try {
    $null = Get-Command ssh -ErrorAction Stop
} catch {
    Write-Host "ssh is not available in PATH. Install OpenSSH Client and retry." -ForegroundColor Red
    exit 1
}

$aliasTarget = "zil-hl15"
$fallbackTarget = "hl@hlssh.zil.digital"

& ssh @($aliasTarget) @args
if ($LASTEXITCODE -eq 0) {
    exit 0
}

Write-Host "`nAlias '$aliasTarget' failed (exit $LASTEXITCODE). Trying direct: ssh -p 2315 $fallbackTarget …" `
    -ForegroundColor Yellow
Write-Host "(Add Host $aliasTarget to your .ssh\config to avoid this fallback.)`n" -ForegroundColor Yellow

& ssh -p 2315 $fallbackTarget @args
exit $LASTEXITCODE
