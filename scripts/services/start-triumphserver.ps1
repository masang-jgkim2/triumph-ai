# Vue 프론트엔드 로컬 기동 (proxy 모드 — 로컬 API 연동)
param(
    [ValidateSet('proxy', 'dev', 'qa')]
    [string]$strMode = 'proxy'
)

$ErrorActionPreference = 'Stop'
$strRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$strRepo = Join-Path $strRoot 'repos\global-triumphserver'
$strLocalEnv = Join-Path $strRoot 'config\local.env'

Set-Location $strRepo

# triumph_ai config/local.env -> Vite 환경 변수 주입 (있을 때)
if (Test-Path $strLocalEnv) {
    Get-Content $strLocalEnv | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { return }
        $strKey = $Matches[1].Trim()
        $strVal = $Matches[2].Trim()
        Set-Item -Path "env:$strKey" -Value $strVal
    }
    Write-Host "[triumphserver] config/local.env 로드됨"
}

$strEnvProxy = Join-Path $strRepo '.env.proxy'
if ($strMode -eq 'proxy' -and -not (Test-Path $strEnvProxy)) {
    Write-Warning '[triumphserver] .env.proxy 없음 — VITE_* 로컬 URL을 설정하세요.'
}

if (-not (Test-Path 'node_modules')) {
    Write-Host '[triumphserver] npm install 실행 중...'
    npm install
}

switch ($strMode) {
    'dev'  { Write-Host '[triumphserver] npm run dev'; npm run dev }
    'qa'   { Write-Host '[triumphserver] npm run dev:qa'; npm run dev:qa }
    default { Write-Host '[triumphserver] npm run dev:proxy'; npm run dev:proxy }
}
