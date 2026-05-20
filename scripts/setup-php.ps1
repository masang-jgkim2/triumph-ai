# PHP (winget) 확장 활성화 — Laravel / Composer용
param(
    [ValidateSet('8.2', '8.3')]
    [string]$strVersion = '8.2'
)
$ErrorActionPreference = 'Stop'

$strPhpExe = (Get-Command php -All | Where-Object { $_.Source -match "PHP\.PHP\.$strVersion" } | Select-Object -First 1).Source
if (-not $strPhpExe) {
    throw "PHP $strVersion not found. winget install PHP.PHP.$strVersion"
}
$strPhpDir = Split-Path $strPhpExe -Parent
Write-Host "[setup-php] PHP $strVersion -> $strPhpDir"
$strIniDev = Join-Path $strPhpDir 'php.ini-development'
$strIni = Join-Path $strPhpDir 'php.ini'

if (-not (Test-Path $strIni)) {
    Copy-Item $strIniDev $strIni
    Write-Host "[setup-php] php.ini 생성: $strIni"
}

$arrExt = @(
    'curl',
    'fileinfo',
    'mbstring',
    'openssl',
    'pdo_mysql',
    'sodium',
    'zip'
)

$strExtDir = Join-Path $strPhpDir 'ext'
$arrLines = Get-Content $strIni
$bHasExtDir = $false
for ($i = 0; $i -lt $arrLines.Count; $i++) {
    if ($arrLines[$i] -match '^\s*;?\s*extension_dir\s*=') {
        $arrLines[$i] = "extension_dir = `"$strExtDir`""
        $bHasExtDir = $true
    }
    # setup-php가 깨뜨린 병합 라인 복구
    if ($arrLines[$i] -match 'extension-dirextension_dir') {
        $arrLines[$i] = '; https://php.net/extension-dir'
        $arrLines = $arrLines[0..$i] + "extension_dir = `"$strExtDir`"" + $arrLines[($i + 1)..($arrLines.Count - 1)]
        $bHasExtDir = $true
    }
}
if (-not $bHasExtDir) {
    $arrLines = @("extension_dir = `"$strExtDir`"") + $arrLines
}
$content = ($arrLines -join "`r`n") + "`r`n"

foreach ($strExt in $arrExt) {
    $content = $content -replace ";extension=$strExt", "extension=$strExt"
}

Set-Content -Path $strIni -Value $content -Encoding UTF8
Write-Host '[setup-php] 활성화 확장:' ($arrExt -join ', ')
php -m | Select-String -Pattern 'openssl|curl|mbstring|pdo_mysql'
