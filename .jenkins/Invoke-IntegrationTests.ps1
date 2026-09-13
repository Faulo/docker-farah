[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Image,

    [Parameter(Mandatory)]
    [ValidateSet('linux', 'windows')]
    [string] $Os,

    [Parameter(Mandatory)]
    [string] $Variant,

    [string] $Capabilities = '',

    [Parameter(Mandatory)]
    [string] $ResultsPath,

    [Parameter(Mandatory)]
    [ValidateRange(1, [int]::MaxValue)]
    [int] $MajorVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$installedPester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version.Major -eq $MajorVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1
if ($null -eq $installedPester) {
    throw "Pester $MajorVersion.* is not installed"
}
Import-Module $installedPester.Path -ErrorAction Stop

$resolvedResultsPath = [IO.Path]::GetFullPath(
    $ResultsPath,
    (Get-Location).Path
)
$resultsDirectory = Split-Path -Parent $resolvedResultsPath
New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null

$resolvedCapabilities = @(
    $Capabilities -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

$testData = @{
    Image = $Image
    Os = $Os
    Variant = $Variant
    Capabilities = $resolvedCapabilities
}

$testsPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' $Path))
$testFiles = @(
    Get-ChildItem -LiteralPath $testsPath -Filter '*.Tests.ps1' -File |
        Sort-Object FullName
)
if ($testFiles.Count -eq 0) {
    throw "No Pester test files were found in $testsPath"
}

$containers = @(
    $testFiles | ForEach-Object {
        New-PesterContainer -Path $_.FullName -Data $testData
    }
)

$configuration = New-PesterConfiguration
$configuration.Run.Container = $containers
$configuration.Run.Exit = $false
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'JUnitXml'
$configuration.TestResult.OutputPath = $resolvedResultsPath
$configuration.TestResult.TestSuiteName = "Docker $($testData.Image) [$($testData.Os), $($testData.Variant)]"

$result = Invoke-Pester -Configuration $configuration

if ($null -eq $result) {
    throw 'Pester returned no result'
}
if ($result.TotalCount -eq 0) {
    throw 'Pester discovered no tests'
}
if ($result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0) {
    throw "Pester infrastructure failed: $($result.FailedContainersCount) container(s), $($result.FailedBlocksCount) block(s)"
}

# Test failures are represented by JUnit and make Jenkins unstable. Only
# infrastructure failures should make this process exit unsuccessfully.
exit 0
