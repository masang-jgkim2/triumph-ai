# 로컬 통합 환경 스모크 검증 (기동 없이 / -Start 후 health 확인)
param(
    [switch]$StartServices,
    [int]$nHealthWaitSec = 15
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib\service-config.ps1')

$nFail = 0

function Write-Check {
    param([bool]$bOk, [string]$strMsg)
    if ($bOk) { Write-Host "[OK] $strMsg" -ForegroundColor Green }
    else { Write-Host "[FAIL] $strMsg" -ForegroundColor Red; $script:nFail++ }
}

Write-Host '=== triumph_ai 로컬 검증 ===' -ForegroundColor Cyan

# 도구
Write-Check ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) 'git'
Write-Check ($null -ne (Get-Command node -ErrorAction SilentlyContinue)) 'node'
Write-Check ($null -ne (Get-Command npm -ErrorAction SilentlyContinue)) 'npm'
Write-Check ($null -ne (Get-Command php -ErrorAction SilentlyContinue)) 'php'
$strPhp82 = (
    Get-Command php -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -match 'PHP\.PHP\.8\.2' } |
    Select-Object -First 1
).Source
Write-Check ($null -ne $strPhp82) 'php 8.2 (apiserver)'
$strComposer = Join-Path $env:LOCALAPPDATA 'Programs\Composer\composer'
Write-Check (Test-Path $strComposer) 'composer (php script)'
if ($strPhp82 -and (Test-Path $strComposer)) {
    $strVer = (& $strPhp82 $strComposer -V 2>$null | Select-Object -First 1) -replace 'PHP Warning:.*', ''
    if ($strVer) { Write-Host "  $strVer" }
}

# repo
foreach ($entry in Get-OrderedServices) {
    $svc = $entry.Value
    Write-Check (Test-ServiceRepo -strRepoPath $svc.strRepoPath) "repo: $($svc.strName)"
}

if ($StartServices) {
    & (Join-Path $PSScriptRoot 'start-all.ps1')
    Write-Host "health 대기 ${nHealthWaitSec}s..."
    Start-Sleep -Seconds $nHealthWaitSec
}

# 포트 / health
$svcApi = $script:Services.apiserver
$svcWs = $script:Services.websocket
$svcFe = $script:Services.triumphserver

$bApiListen = Test-PortListening -nPort $svcApi.nPort
Write-Check $bApiListen "API 포트 $($svcApi.nPort) LISTEN"

if ($bApiListen) {
    $r = Invoke-HttpHealth -strUrl "http://127.0.0.1:$($svcApi.nPort)"
    Write-Check $r.bOk "API HTTP ($($r.nStatus))"
}

$bWsListen = Test-PortListening -nPort $svcWs.nPort
Write-Check $bWsListen "WebSocket 포트 $($svcWs.nPort) LISTEN"

if ($bWsListen) {
    $r = Invoke-HttpHealth -strUrl "http://127.0.0.1:$($svcWs.nPort)/health"
    $bHealth = $r.bOk -and $r.nStatus -eq 200
    Write-Check $bHealth "WebSocket /health ($($r.nStatus))"
    if (-not $bHealth -and $r.strBody) {
        Write-Host "  body: $($r.strBody.Substring(0, [Math]::Min(200, $r.strBody.Length)))"
    }
}

$bFeListen = Test-PortListening -nPort $svcFe.nPort
Write-Check $bFeListen "Frontend 포트 $($svcFe.nPort) LISTEN"

if ($bFeListen) {
    $r = Invoke-HttpHealth -strUrl "http://127.0.0.1:$($svcFe.nPort)"
    Write-Check $r.bOk "Frontend HTTP ($($r.nStatus))"
}

Write-Host ''
if ($nFail -eq 0) {
    Write-Host '검증 통과' -ForegroundColor Green
    exit 0
}
else {
    Write-Host "검증 실패 ($nFail 건) — docs/local-dev.md 참고" -ForegroundColor Yellow
    exit 1
}
