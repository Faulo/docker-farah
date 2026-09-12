[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$requiredEnvironment = @(
    'PESTER_IMAGE'
    'PESTER_DOCKER_CONTEXT'
    'PESTER_EXPECTED_OS'
    'PESTER_VARIANT'
    'PESTER_RESULTS_PATH'
)

foreach ($name in $requiredEnvironment) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment variable $name is missing or empty"
    }
}

$pesterMajorVersion = [Environment]::GetEnvironmentVariable('PESTER_MAJOR_VERSION')
if ([string]::IsNullOrWhiteSpace($pesterMajorVersion)) {
    throw 'Required environment variable PESTER_MAJOR_VERSION is missing or empty'
}

$installedPester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version.Major -eq [int] $pesterMajorVersion } |
    Sort-Object Version -Descending |
    Select-Object -First 1
if ($null -eq $installedPester) {
    throw "Pester $pesterMajorVersion.* is not installed"
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
    DockerContext = [Environment]::GetEnvironmentVariable('PESTER_DOCKER_CONTEXT')
    ExpectedOs = [Environment]::GetEnvironmentVariable('PESTER_EXPECTED_OS')
    Variant = [Environment]::GetEnvironmentVariable('PESTER_VARIANT')
    Capabilities = $capabilities
}

$testFiles = @(
    Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' -File |
        Sort-Object FullName
)
if ($testFiles.Count -eq 0) {
    throw "No Pester test files were found below $PSScriptRoot"
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
$configuration.TestResult.TestSuiteName = "Docker $($testData.Image) [$($testData.ExpectedOs), $($testData.Variant)]"

Invoke-Pester -Configuration $configuration
