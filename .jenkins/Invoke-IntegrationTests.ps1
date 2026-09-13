[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Namespace,
    
    [Parameter(Mandatory)]
    [string] $Name,

    [string] $Variant = 'latest',
    
    [string] $Context = 'default',
    
    [string] $TestsPath = 'tests',

    [string] $ResultsPath = '.reports/report.xml'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$installedPester = Get-Module -ListAvailable -Name Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1
Import-Module $installedPester.Path -ErrorAction Stop

$resolvedResultsPath = [IO.Path]::GetFullPath(
    $ResultsPath,
    (Get-Location).Path
)
$resultsDirectory = Split-Path -Parent $resolvedResultsPath
New-Item -ItemType Directory -Path $resultsDirectory -Force | Out-Null

$testData = @{
    Context = $Context
    Namespace = $Namespace
    Name = $Name
    Variant = $Variant
    Image = $Namespace + "/" + $Name + ":" + $Variant
    Os = & docker --context $Context version --format '{{.Server.Os}}'
}

$testsPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' $TestsPath))
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
$configuration.TestResult.TestSuiteName = "Docker $($testData.Image) [$($testData.Context), $($testData.Variant)]"

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
