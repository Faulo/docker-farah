param(
    [Parameter(Mandatory)]
    [string] $Image,

    [Parameter(Mandatory)]
    [string] $DockerContext,

    [Parameter(Mandatory)]
    [ValidateSet('linux', 'windows')]
    [string] $ExpectedOs,

    [Parameter(Mandatory)]
    [string] $Variant,

    [Parameter(Mandatory)]
    [string[]] $Capabilities
)

Describe "Docker integration environment [$ExpectedOs, $Variant]" {
    It "targets a reachable $ExpectedOs Docker daemon" {
        $actualOs = & docker --context $DockerContext version --format '{{.Server.Os}}' 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "Docker context '$DockerContext' must be reachable"
        ($actualOs | Out-String).Trim() | Should -Be $ExpectedOs
    }

    It 'provides the image under test' {
        $output = & docker --context $DockerContext image inspect $Image 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "image '$Image' must exist on Docker context '$DockerContext': $($output | Out-String)"
    }
}
