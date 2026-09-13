param(
    [Parameter(Mandatory)]
    [string] $Namespace,
    
    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [string] $Variant,
    
    [Parameter(Mandatory)]
    [string] $Context,
    
    [Parameter(Mandatory)]
    [string] $Image,

    [Parameter(Mandatory)]
    [string] $Os
)

Describe "Docker integration environment [$Context, $Image]" {
    It "reaches docker daemon $Context" {
        $output = & docker --context $Context info 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "Docker context '$Context' must be reachable: $($output | Out-String)"
    }

    It "has image $Image" {
        $output = & docker --context $Context image inspect $Image 2>&1
        $dockerExitCode = $LASTEXITCODE

        $dockerExitCode | Should -Be 0 -Because "image '$Image' must exist on Docker context '$Context': $($output | Out-String)"
    }
}
