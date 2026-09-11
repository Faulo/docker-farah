param(
    [Parameter(Mandatory = $true)]
    [string]$PackageToolsPath,

    [Parameter(Mandatory = $true)]
    [string]$WixSha256
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version Latest

$root = 'C:/vc-runtime'
$wixArchive = Join-Path $root 'wix.zip'
$wixDirectory = Join-Path $root 'wix'
$dark = Join-Path $wixDirectory 'dark.exe'

function Get-VerifiedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$Sha256
    )

    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination
    $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
    if ($actualHash -ne $Sha256) {
        throw "SHA-256 mismatch for ${Uri}: ${actualHash}"
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "${FilePath} failed with exit code ${LASTEXITCODE}"
    }
}

function Get-DataValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Data -is [System.Collections.IDictionary] -and $Data.Contains($name)) {
            return $Data[$name]
        }

        $property = $Data.PSObject.Properties[$name]
        if ($null -ne $property) {
            return $property.Value
        }
    }

    throw "None of the expected vcredist140 fields exist: $($Names -join ', ')"
}

. (Join-Path $PackageToolsPath 'data.ps1')

New-Item -ItemType Directory -Path $root -Force | Out-Null
$wixUri = 'https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip'
Get-VerifiedFile -Uri $wixUri -Destination $wixArchive -Sha256 $WixSha256
Expand-Archive -LiteralPath $wixArchive -DestinationPath $wixDirectory

$architectures = @(
    @{
        Name = 'x64'
        PayloadSuffix = 'amd64'
        Destination = Join-Path $env:WINDIR 'System32'
        Uri = Get-DataValue -Data $installData64 -Names @('Url64', 'Url')
        Sha256 = Get-DataValue -Data $installData64 -Names @('Checksum64', 'Checksum')
    },
    @{
        Name = 'x86'
        PayloadSuffix = 'x86'
        Destination = Join-Path $env:WINDIR 'SysWOW64'
        Uri = Get-DataValue -Data $installData32 -Names @('Url', 'Url32')
        Sha256 = Get-DataValue -Data $installData32 -Names @('Checksum', 'Checksum32')
    }
)

foreach ($architecture in $architectures) {
    $name = $architecture.Name
    $bundle = Join-Path $root "vc_redist.${name}.exe"
    Get-VerifiedFile -Uri $architecture.Uri -Destination $bundle -Sha256 $architecture.Sha256

    $bundleDirectory = Join-Path $root $name
    Invoke-Native -FilePath $dark -Arguments @('-nologo', '-x', $bundleDirectory, $bundle)

    $packageRoot = Join-Path $bundleDirectory 'AttachedContainer/packages'
    $payloadSuffix = $architecture.PayloadSuffix
    foreach ($packageName in @("vcRuntimeMinimum_${payloadSuffix}", "vcRuntimeAdditional_${payloadSuffix}")) {
        $cabinet = Join-Path $packageRoot "${packageName}/cab1.cab"
        $expanded = Join-Path $root "expanded-${packageName}"
        New-Item -ItemType Directory -Path $expanded -Force | Out-Null
        Invoke-Native -FilePath 'expand.exe' -Arguments @('-F:*', $cabinet, $expanded)

        Get-ChildItem -Path $expanded -Filter "*.dll_${payloadSuffix}" | ForEach-Object {
            $destinationName = $_.Name -replace "_${payloadSuffix}$", ''
            Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $architecture.Destination $destinationName) -Force
        }
    }
}

$runtimeVersion = $otherData.ThreePartVersion.ToString()
foreach ($runtime in @(
    (Join-Path $env:WINDIR 'System32/vcruntime140.dll'),
    (Join-Path $env:WINDIR 'SysWOW64/vcruntime140.dll')
)) {
    $version = (Get-Item -LiteralPath $runtime).VersionInfo.ProductVersion
    if (-not $version.StartsWith($runtimeVersion)) {
        throw "Expected Visual C++ runtime ${runtimeVersion}, found ${version} at ${runtime}"
    }
}

Remove-Item -LiteralPath $root -Recurse -Force
