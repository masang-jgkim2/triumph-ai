# triumph_ai 루트 env 파일 -> 각 repo 설정 경로 복사
param(
    [ValidateSet('local', 'fullstack', 'qa', 'production')]
    [string]$strProfile = 'local'
)

$ErrorActionPreference = 'Stop'
$strRoot = Split-Path $PSScriptRoot -Parent

$htMap = @{
    local      = @{ strSrc = 'env'; strDstName = '.env.proxy' }
    fullstack  = @{ strSrc = 'env.local-fullstack'; strDstName = '.env.proxy' }
    qa         = @{ strSrc = 'env.qa'; strDstName = '.env.qa' }
    production = @{ strSrc = 'env.production'; strDstName = '.env.production' }
}

$entry = $htMap[$strProfile]
$strSrc = Join-Path $strRoot $entry.strSrc
if (-not (Test-Path $strSrc)) {
    throw "소스 없음: $strSrc"
}

$strFeRepo = Join-Path $strRoot 'repos\global-triumphserver'
$strDst = Join-Path $strFeRepo $entry.strDstName
Copy-Item $strSrc $strDst -Force
Write-Host "[sync-env] $strSrc -> $strDst"

# dev:proxy 는 .env.proxy 를 읽음
switch ($strProfile) {
    'local' {
        Write-Host '[sync-env] 모드 A: 프론트만 로컬 → QA API/WS (env)'
        Write-Host '  npm run dev:proxy  (또는 start-frontend.bat)'
    }
    'fullstack' {
        Write-Host '[sync-env] 모드 B: 풀스택 로컬 (env.local-fullstack → 127.0.0.1)'
        Write-Host '  .\scripts\start-all.ps1  (apiserver + websocket .env 필요)'
    }
}

# API / WebSocket .env 는 별도 (팀 Laravel/Node env)
$arrMissing = @()
foreach ($pair in @(
    @{ path = 'repos\global-apiserver\.env'; label = 'apiserver .env' },
    @{ path = 'repos\global-renewal-websocket\.env'; label = 'websocket .env' }
)) {
    if (-not (Test-Path (Join-Path $strRoot $pair.path))) {
        $arrMissing += $pair.label
    }
}
if ($arrMissing.Count -gt 0) {
    Write-Warning "[sync-env] 아직 없음 (로컬 API/WS 기동에 필요): $($arrMissing -join ', ')"
}
