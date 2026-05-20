# Composer 실행 헬퍼 (Windows: composer는 php 스크립트)
function Invoke-Composer {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$arrArgs
    )
    $strComposer = Join-Path $env:LOCALAPPDATA 'Programs\Composer\composer'
    if (-not (Test-Path $strComposer)) {
        throw "Composer not found. Run scripts\setup-php.ps1 and install Composer first."
    }
    & php $strComposer @arrArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
