# API -> WebSocket -> Frontend 순서로 새 PowerShell 창에서 기동
param(
    [switch]$NoNewWindow,
    [switch]$FrontendOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\service-config.ps1')

# triumph_ai\env -> .env.proxy
& (Join-Path $PSScriptRoot 'sync-env.ps1') -strProfile local | Out-Host

if ($FrontendOnly) {
    $entry = $script:Services.GetEnumerator() | Where-Object { $_.Key -eq 'triumphserver' }
    $svc = $entry.Value
    if (-not $NoNewWindow) {
        Start-Process powershell -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $svc.strStartScript) | Out-Null
    }
    else { & $svc.strStartScript }
    Write-Host '프론트만 기동 (QA 원격 API 사용). http://127.0.0.1:3100'
    exit 0
}

foreach ($entry in Get-OrderedServices) {
    $svc = $entry.Value
    if (-not (Test-ServiceRepo -strRepoPath $svc.strRepoPath)) {
        Write-Error "repo 없음: $($svc.strRepoPath) — 먼저 .\scripts\clone-repos.ps1 실행"
    }
}

# .env 없으면 API/WS 창을 열지 않음
$arrSkip = @()
if (-not (Test-Path (Join-Path $script:RootDir 'repos\global-apiserver\.env'))) {
    $arrSkip += 'apiserver'
    Write-Warning '[start-all] apiserver .env 없음 — 스킵 (팀 Laravel .env 필요)'
}
if (-not (Test-Path (Join-Path $script:RootDir 'repos\global-renewal-websocket\.env'))) {
    $arrSkip += 'websocket'
    Write-Warning '[start-all] websocket .env 없음 — 스킵 (팀 Node .env 필요)'
}
if ($arrSkip.Count -eq 2) {
    Write-Host '[start-all] 프론트만 기동합니다 (QA 원격 API). -FrontendOnly 와 동일'
}

foreach ($entry in Get-OrderedServices) {
    $svc = $entry.Value
    if ($svc.strId -in $arrSkip) { continue }
    if ($svc.nStartDelaySec -gt 0) {
        Write-Host "[start-all] $($svc.strId) 대기 $($svc.nStartDelaySec)s..."
        Start-Sleep -Seconds $svc.nStartDelaySec
    }

    if (Test-PortListening -nPort $svc.nPort) {
        Write-Warning "[start-all] 포트 $($svc.nPort) 이미 사용 중 — $($svc.strId) 스킵"
        continue
    }

    Write-Host "[start-all] 기동: $($svc.strId) ($($svc.strStartScript))"

    if ($NoNewWindow) {
        Start-Job -Name $svc.strId -ScriptBlock {
            param($strScript)
            & $strScript
        } -ArgumentList $svc.strStartScript | Out-Null
    }
    else {
        Start-Process powershell -ArgumentList @(
            '-NoExit',
            '-ExecutionPolicy', 'Bypass',
            '-File', $svc.strStartScript
        ) -WindowStyle Normal
    }
}

Write-Host ''
Write-Host '기동 요청 완료.'
Write-Host '  API:        http://127.0.0.1:8000'
Write-Host '  WebSocket:  http://127.0.0.1:9603/health'
Write-Host '  Frontend:   http://127.0.0.1:3100'
Write-Host '종료: .\scripts\stop-all.ps1'
Write-Host '검증: .\scripts\verify-local.ps1'
