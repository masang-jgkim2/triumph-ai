# 3개 서비스 repo 클론/업데이트
param(
    [string]$Branch = 'main',
    [switch]$CheckoutLock,
    [switch]$UseSubmodule
)

# git stderr(Already on 'main' 등)는 Stop으로 처리하지 않음
$ErrorActionPreference = 'Continue'
$strRoot = Split-Path $PSScriptRoot -Parent
$strReposDir = Join-Path $strRoot 'repos'
$strLockFile = Join-Path $strRoot 'repos.lock.json'

if (-not (Test-Path $strReposDir)) {
    New-Item -ItemType Directory -Path $strReposDir -Force | Out-Null
}

$htLock = $null
if (Test-Path $strLockFile) {
    $htLock = Get-Content $strLockFile -Raw | ConvertFrom-Json
}

function Sync-Repo {
    param(
        [string]$strFolder,
        [string]$strUrl,
        [string]$strBranch,
        [string]$strSha = ''
    )

    $strPath = Join-Path $strReposDir $strFolder
    if (Test-Path (Join-Path $strPath '.git')) {
        Write-Host "[clone] pull: $strFolder"
        Push-Location $strPath
        & git fetch origin 2>&1 | Out-Null
        if ($CheckoutLock -and $strSha) {
            & git checkout $strSha 2>&1 | Out-Null
        }
        else {
            & git checkout $strBranch 2>&1 | Out-Null
            & git pull origin $strBranch 2>&1 | Out-Null
        }
        if ($LASTEXITCODE -gt 1) {
            Write-Warning "[clone] git warning in $strFolder (exit $LASTEXITCODE)"
        }
        Pop-Location
    }
    else {
        if (Test-Path $strPath) {
            Remove-Item $strPath -Recurse -Force
        }
        Write-Host "[clone] clone: $strFolder ($strBranch)"
        if ($CheckoutLock -and $strSha) {
            git clone --depth 1 $strUrl $strPath
            Push-Location $strPath
            git fetch --depth 1 origin $strSha 2>$null
            git checkout $strSha
            Pop-Location
        }
        else {
            git clone --branch $strBranch --depth 1 $strUrl $strPath
        }
    }
}

if ($UseSubmodule) {
    Set-Location $strRoot
    if (-not (Test-Path '.git')) {
        git init
    }
    git submodule update --init --recursive
    Write-Host '[clone] submodule update 완료'
    exit 0
}

foreach ($strKey in @('global-triumphserver', 'global-renewal-websocket', 'global-apiserver')) {
    $objRepo = $htLock.repos.$strKey
    $strUrl = $objRepo.url
    $strSha = if ($CheckoutLock) { $objRepo.sha } else { '' }
    $strBr = if ($objRepo.branch) { $objRepo.branch } else { $Branch }
    Sync-Repo -strFolder $strKey -strUrl $strUrl -strBranch $strBr -strSha $strSha
}

Write-Host '[clone] 완료. repos.lock.json SHA:'
foreach ($strKey in @('global-triumphserver', 'global-renewal-websocket', 'global-apiserver')) {
    $strPath = Join-Path $strReposDir $strKey
    if (Test-Path (Join-Path $strPath '.git')) {
        Push-Location $strPath
        $strRev = git rev-parse HEAD
        Write-Host "  $strKey : $strRev"
        Pop-Location
    }
}
