# Interactive SSH to second Kafka node (course gateway port 2314 -> hl14).
# Prefer Host zil-hl14 in %USERPROFILE%\.ssh\config — see LAB11 §0.3 / LAB12 §1.3.

$ErrorActionPreference = "Stop"

try {
    $null = Get-Command ssh -ErrorAction Stop
} catch {
    Write-Host "ssh is not available in PATH. Install OpenSSH Client and retry." -ForegroundColor Red
    exit 1
}

$aliasTarget = "zil-hl14"
$fallbackTarget = "hl@hlssh.zil.digital"

& ssh @($aliasTarget) @args
if ($LASTEXITCODE -eq 0) {
    exit 0
}

Write-Host "`nAlias '$aliasTarget' failed (exit $LASTEXITCODE). Trying direct: ssh -p 2314 $fallbackTarget …" `
    -ForegroundColor Yellow
Write-Host "(Add Host $aliasTarget to your .ssh\config to avoid this fallback.)`n" -ForegroundColor Yellow

& ssh -p 2314 $fallbackTarget @args
exit $LASTEXITCODE
