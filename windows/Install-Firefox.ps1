param(
    [Parameter(Mandatory = $true)]
    [string]$PackageToolsPath,

    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$checksumFile = Join-Path $PackageToolsPath 'LanguageChecksums.csv'
$checksumLine = Get-Content -LiteralPath $checksumFile |
    Where-Object { $_ -match '^en-US\|64\|' } |
    Select-Object -First 1
if (-not $checksumLine) {
    throw "Firefox $Version does not provide an en-US x64 checksum"
}

$expectedHash = ($checksumLine -split '\|')[-1]
$installerPath = 'C:/build/firefox-installer.exe'
$url = "https://download.mozilla.org/?product=firefox-$Version-ssl&os=win64&lang=en-US"
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $installerPath

$actualHash = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA512).Hash
if ($actualHash -ne $expectedHash) {
    throw "Firefox $Version SHA-512 mismatch: $actualHash"
}

7z.exe x $installerPath -oC:/Firefox -y | Out-Null
if ($LASTEXITCODE -notin 0, 1) {
    throw "Firefox $Version extraction failed with exit code $LASTEXITCODE"
}

$firefoxPath = 'C:/Firefox/core/firefox.exe'
$actualVersion = (Get-Item -LiteralPath $firefoxPath).VersionInfo.ProductVersion
if ($actualVersion -ne $Version) {
    throw "Expected Firefox $Version, found $actualVersion"
}

Remove-Item -LiteralPath $installerPath
