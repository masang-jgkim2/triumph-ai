# 서비스 경로·포트·기동 명령 중앙 정의
# Hungarian-style prefixes: str=string, n=number, arr=array, b=bool

$script:RootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Laravel lock 파일 호환: PHP 8.2 (winget)
$script:strPhpApi = (
    Get-Command php -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -match 'PHP\.PHP\.8\.2' } |
    Select-Object -First 1
).Source
if (-not $script:strPhpApi) {
    $script:strPhpApi = (Get-Command php -ErrorAction SilentlyContinue).Source
}

$script:Services = @{
    apiserver = @{
        strId           = 'apiserver'
        strName         = 'global-apiserver'
        strRepoPath     = Join-Path $RootDir 'repos\global-apiserver'
        nPort           = 8000
        strStartScript  = Join-Path $RootDir 'scripts\services\start-apiserver.ps1'
        arrProcessHints = @('php')
        nStartOrder     = 1
        nStartDelaySec  = 0
    }
    websocket = @{
        strId           = 'websocket'
        strName         = 'global-renewal-websocket'
        strRepoPath     = Join-Path $RootDir 'repos\global-renewal-websocket'
        nPort           = 9603
        strStartScript  = Join-Path $RootDir 'scripts\services\start-websocket.ps1'
        arrProcessHints = @('node')
        nStartOrder     = 2
        nStartDelaySec  = 3
    }
    triumphserver = @{
        strId           = 'triumphserver'
        strName         = 'global-triumphserver'
        strRepoPath     = Join-Path $RootDir 'repos\global-triumphserver'
        nPort           = 3100
        strStartScript  = Join-Path $RootDir 'scripts\services\start-triumphserver.ps1'
        arrProcessHints = @('node')
        nStartOrder     = 3
        nStartDelaySec  = 2
    }
}

function Test-ServiceRepo {
    param([string]$strRepoPath)
    return (Test-Path (Join-Path $strRepoPath '.git'))
}

function Get-OrderedServices {
    return $script:Services.GetEnumerator() | Sort-Object { $_.Value.nStartOrder }
}

function Get-PidsByPort {
    param([int]$nPort)
    $arrPids = @()
    try {
        $arrConns = Get-NetTCPConnection -LocalPort $nPort -State Listen -ErrorAction SilentlyContinue
        foreach ($conn in $arrConns) {
            if ($conn.OwningProcess -and $conn.OwningProcess -notin $arrPids) {
                $arrPids += $conn.OwningProcess
            }
        }
    }
    catch {
        # Get-NetTCPConnection 미지원 환경 fallback
        $strLine = netstat -ano | Select-String ":\s*$nPort\s" | Select-Object -First 5
        foreach ($line in $strLine) {
            if ($line -match '\s+(\d+)\s*$') {
                $arrPids += [int]$Matches[1]
            }
        }
    }
    return $arrPids | Select-Object -Unique
}

function Stop-PortListeners {
    param([int]$nPort, [string]$strLabel = '')
    $arrPids = Get-PidsByPort -nPort $nPort
    foreach ($nPid in $arrPids) {
        Write-Host "[stop] $strLabel port $nPort -> PID $nPid"
        Stop-Process -Id $nPid -Force -ErrorAction SilentlyContinue
    }
}

function Test-PortListening {
    param([int]$nPort)
    return (Get-PidsByPort -nPort $nPort).Count -gt 0
}

function Invoke-HttpHealth {
    param([string]$strUrl, [int]$nTimeoutSec = 5)
    try {
        $resp = Invoke-WebRequest -Uri $strUrl -UseBasicParsing -TimeoutSec $nTimeoutSec
        return @{ bOk = $true; nStatus = $resp.StatusCode; strBody = $resp.Content }
    }
    catch {
        return @{ bOk = $false; nStatus = 0; strBody = $_.Exception.Message }
    }
}
