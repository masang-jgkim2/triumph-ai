# 로컬 통합 서비스 포트 기준 종료
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib\service-config.ps1')

Write-Host '[stop-all] triumph 로컬 서비스 종료 중...'

foreach ($entry in ($script:Services.GetEnumerator() | Sort-Object { $_.Value.nStartOrder } -Descending)) {
    $svc = $entry.Value
    Stop-PortListeners -nPort $svc.nPort -strLabel $svc.strId
}

# vite/php 자식 프로세스 정리 (선택)
$arrNames = @('node', 'php')
foreach ($strName in $arrNames) {
    Get-Process -Name $strName -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match 'triumph|artisan|vite|nodemon' } |
        ForEach-Object {
            Write-Host "[stop-all] 프로세스 종료: $($_.ProcessName) PID $($_.Id)"
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
}

Write-Host '[stop-all] 완료'
