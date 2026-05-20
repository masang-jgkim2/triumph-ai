# WebSocket (nodemon + ts-node) 로컬 기동
param(
    [int]$nPort = 9603
)

$ErrorActionPreference = 'Stop'
$strRepo = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'repos\global-renewal-websocket'
Set-Location $strRepo

if (-not (Test-Path '.env')) {
    Write-Warning '[websocket] .env 없음 — DATABASE_URL, REDIS_URL 등 팀 dev 값 필요.'
}

if (-not (Test-Path 'node_modules')) {
    Write-Host '[websocket] npm install 실행 중...'
    npm install
}

if (-not (Test-Path 'generated\prisma')) {
    Write-Host '[websocket] npx prisma generate 실행 중...'
    npx prisma generate
}

$env:PORT = "$nPort"
Write-Host "[websocket] npm run dev (PORT=$nPort)"
npm run dev
