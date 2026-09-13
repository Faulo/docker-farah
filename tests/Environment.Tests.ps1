param(
    [Parameter(Mandatory)]
    [string] $Image,

    [Parameter(Mandatory)]
    [ValidateSet('linux', 'windows')]
    [string] $Os,

    [Parameter(Mandatory)]
    [string] $Variant,

    [Parameter(Mandatory)]
    [string[]] $Capabilities
)

Describe "Docker integration environment [$Os, $Variant]" {
    It "targets a reachable $Os Docker daemon" {
        $actualOs = & docker version --format '{{.Server.Os}}' 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "Docker must be reachable"
        ($actualOs | Out-String).Trim() | Should -Be $Os
    }

    It 'provides the image under test' {
        $output = & docker image inspect $Image 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "image '$Image' must exist on Docker: $($output | Out-String)"
    }
}
