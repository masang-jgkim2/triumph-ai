# Laravel API 로컬 기동
param(
    [string]$strHost = '127.0.0.1',
    [int]$nPort = 8000
)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib\service-config.ps1')
$strRepo = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'repos\global-apiserver'
$strPhp = $script:strPhpApi
if (-not $strPhp) { throw 'PHP 8.2 not found. Run scripts\setup-php.ps1 -strVersion 8.2' }
Set-Location $strRepo

if (-not (Test-Path '.env')) {
    Write-Warning '[apiserver] .env 없음 — 팀 dev .env를 repos\global-apiserver\.env 에 복사하세요.'
    if (Test-Path '.env.example') {
        Copy-Item '.env.example' '.env'
        Write-Host '[apiserver] .env.example -> .env 복사함. php artisan key:generate 실행 권장.'
    }
}

$strComposer = Join-Path $env:LOCALAPPDATA 'Programs\Composer\composer'
if (-not (Test-Path 'vendor')) {
    Write-Host '[apiserver] composer install 실행 중...'
    & $strPhp $strComposer install --no-interaction --prefer-dist
}

Write-Host "[apiserver] $strPhp artisan serve --host=$strHost --port=$nPort"
& $strPhp artisan serve --host=$strHost --port=$nPort
