[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$requiredEnvironment = @(
    'PESTER_IMAGE'
    'PESTER_OS'
    'PESTER_VARIANT'
    'PESTER_RESULTS_PATH'
)

foreach ($name in $requiredEnvironment) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable $name is missing or empty"
    }
}

$installedPester = Get-Module -ListAvailable -Name Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1
if ($null -eq $installedPester) {
    throw "Pester is not installed"
}
Import-Module $installedPester.Path -ErrorAction Stop

$resultsPath = [IO.Path]::GetFullPath(
    [Environment]::GetEnvironmentVariable('PESTER_RESULTS_PATH'),
    (Get-Location).Path
)
$resultsDirectory = Split-Path -Parent $resultsPath
New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null

$capabilitiesValue = [Environment]::GetEnvironmentVariable('PESTER_CAPABILITIES')
$capabilities = @(
    $capabilitiesValue -split ',' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

$testData = @{
    Image = [Environment]::GetEnvironmentVariable('PESTER_IMAGE')
    Os = [Environment]::GetEnvironmentVariable('PESTER_OS')
    Variant = [Environment]::GetEnvironmentVariable('PESTER_VARIANT')
    Capabilities = $capabilities
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
$configuration.Run.Exit = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'JUnitXml'
$configuration.TestResult.OutputPath = $resultsPath
$configuration.TestResult.TestSuiteName = "Docker $($testData.Image) [$($testData.Os), $($testData.Variant)]"

Invoke-Pester -Configuration $configuration
