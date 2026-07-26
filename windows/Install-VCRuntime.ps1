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
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $Destination,

        [Parameter(Mandatory = $true)]
        [string] $Sha256
    )

    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Destination
    $actualHash = (Get-FileHash $Destination -Algorithm SHA256).Hash
    if ($actualHash -ne $Sha256) {
        throw "SHA-256 mismatch for ${Uri}: ${actualHash}"
    }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string] $FilePath,

        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "${FilePath} failed with exit code ${LASTEXITCODE}"
    }
}

New-Item -ItemType Directory -Path $root -Force | Out-Null

$wixUri = "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip"
Get-VerifiedFile -Uri $wixUri -Destination $wixArchive -Sha256 $env:WIX_SHA256
Expand-Archive -Path $wixArchive -DestinationPath $wixDirectory

$architectures = @(
    @{
        Name = 'x64'
        PayloadSuffix = 'amd64'
        Destination = Join-Path $env:WINDIR 'System32'
        Sha256 = $env:VCREDIST_X64_SHA256
    },
    @{
        Name = 'x86'
        PayloadSuffix = 'x86'
        Destination = Join-Path $env:WINDIR 'SysWOW64'
        Sha256 = $env:VCREDIST_X86_SHA256
    }
)

foreach ($architecture in $architectures) {
    $name = $architecture.Name
    $bundle = Join-Path $root "vc_redist.${name}.exe"
    $bundleUri = "https://aka.ms/vs/18/release/$($env:VCREDIST_VERSION)/VC_redist.${name}.exe"
    Get-VerifiedFile -Uri $bundleUri -Destination $bundle -Sha256 $architecture.Sha256

    $bundleDirectory = Join-Path $root $name
    Invoke-Native -FilePath $dark -Arguments @('-nologo', '-x', $bundleDirectory, $bundle)

    $packageRoot = Join-Path $bundleDirectory 'AttachedContainer/packages'
    $payloadSuffix = $architecture.PayloadSuffix
    $packageNames = @(
        "vcRuntimeMinimum_${payloadSuffix}",
        "vcRuntimeAdditional_${payloadSuffix}"
    )

    foreach ($packageName in $packageNames) {
        $cabinet = Join-Path $packageRoot "${packageName}/cab1.cab"
        $expanded = Join-Path $root "expanded-${packageName}"
        New-Item -ItemType Directory -Path $expanded -Force | Out-Null
        Invoke-Native -FilePath 'expand.exe' -Arguments @('-F:*', $cabinet, $expanded)

        Get-ChildItem -Path $expanded -Filter "*.dll_${payloadSuffix}" | ForEach-Object {
            $destinationName = $_.Name -replace "_${payloadSuffix}$", ''
            Copy-Item -Path $_.FullName -Destination (Join-Path $architecture.Destination $destinationName) -Force
        }
    }
}

foreach ($runtime in @(
    (Join-Path $env:WINDIR 'System32/vcruntime140.dll'),
    (Join-Path $env:WINDIR 'SysWOW64/vcruntime140.dll')
)) {
    $version = (Get-Item $runtime).VersionInfo.ProductVersion
    if (-not $version.StartsWith($env:VCREDIST_VERSION)) {
        throw "Expected Visual C++ runtime $($env:VCREDIST_VERSION), found ${version} at ${runtime}"
    }
}

Remove-Item -Path $root -Recurse -Force
