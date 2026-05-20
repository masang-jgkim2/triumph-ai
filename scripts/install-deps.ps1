# 3개 서비스 의존성 일괄 설치
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\service-config.ps1')

$strComposer = Join-Path $env:LOCALAPPDATA 'Programs\Composer\composer'
$strRoot = $script:RootDir

Write-Host '=== triumph_ai 의존성 설치 ===' -ForegroundColor Cyan

# PHP 확장 (8.2 API용)
& (Join-Path $PSScriptRoot 'setup-php.ps1') -strVersion 8.2

# API
$strApi = Join-Path $strRoot 'repos\global-apiserver'
if (-not $script:strPhpApi) { throw 'PHP 8.2 required for apiserver' }
Set-Location $strApi
if (-not (Test-Path 'vendor')) {
    Write-Host '[install] composer install (apiserver)...'
    & $script:strPhpApi $strComposer install --no-interaction --prefer-dist
}

# WebSocket
$strWs = Join-Path $strRoot 'repos\global-renewal-websocket'
Set-Location $strWs
if (-not (Test-Path 'node_modules')) {
    Write-Host '[install] npm install (websocket)...'
    npm install
}
Write-Host '[install] prisma generate (websocket)...'
npx prisma generate

# Frontend
$strFe = Join-Path $strRoot 'repos\global-triumphserver'
Set-Location $strFe
if (-not (Test-Path 'node_modules')) {
    Write-Host '[install] npm install (triumphserver)...'
    npm install
}

Set-Location $strRoot
Write-Host '[install] 완료' -ForegroundColor Green
