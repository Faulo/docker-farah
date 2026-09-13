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
    [string] $Os,

    [Parameter(Mandatory)]
    [string[]] $DockerRunArguments
)

BeforeAll {
    . (Join-Path $PSScriptRoot '../.jenkins/Docker.ps1')

    function Remove-TestContainer {
        param(
            [Parameter(Mandatory)]
            [string] $Container
        )

        $result = Get-DockerCommandResult -Context $Context -Arguments @('container', 'inspect', $Container)
        if ($result.ExitCode -eq 0) {
            Invoke-Docker -Context $Context -Arguments @('container', 'rm', '--force', '--volumes', $Container)
        }
    }

    function Install-TestApplication {
        param(
            [Parameter(Mandatory)]
            [string] $Container
        )

        $applicationDirectory = $Os -eq 'windows' ? 'C:/www/' : '/var/www/'
        $composer = $Os -eq 'windows' ? 'composer.exe' : 'composer'
        $fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../test-files/application'))

        Invoke-Docker -Context $Context -Arguments @('cp', (Join-Path $fixture '.'), "${Container}:${applicationDirectory}")
        Invoke-Docker -Context $Context -Arguments @('exec', $Container, $composer, 'dump-autoload', '--no-interaction', '--optimize')
    }

    function Get-ResponseStatus {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Path,

            [switch] $Retry
        )

        $nullDevice = $Os -eq 'windows' ? 'NUL' : '/dev/null'
        $arguments = @('exec', $Container, 'curl', '--silent')
        if ($Retry) {
            $arguments += @('--retry', '30', '--retry-connrefused', '--retry-delay', '1')
        } else {
            $arguments += '--show-error'
        }
        $arguments += @('--output', $nullDevice, '--write-out', '%{http_code}', "http://localhost$Path")
        return Invoke-DockerOutput -Context $Context -Arguments $arguments
    }

    function Get-ResponseBody {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Path
        )

        return Invoke-DockerOutput -Context $Context -Arguments @('exec', $Container, 'curl', '--fail', '--silent', '--show-error', "http://localhost$Path")
    }

    function Get-ResponseMediaType {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Path
        )

        $nullDevice = $Os -eq 'windows' ? 'NUL' : '/dev/null'
        $contentType = Invoke-DockerOutput -Context $Context -Arguments @(
            'exec', $Container, 'curl', '--fail', '--silent', '--show-error',
            '--output', $nullDevice, '--write-out', '%{content_type}', "http://localhost$Path"
        )
        return $contentType.Split(';', 2)[0].Trim()
    }
}

Describe "Farah runtime [$Os, PHP $Variant]" {
    It "provides PHP $Variant" {
        $expectedVariant = $Variant -eq 'latest' ? '8.5' : $Variant
        
        $version = Invoke-DockerOutput -Context $Context -RunArguments $DockerRunArguments -Arguments @(
            'run', '--rm', $Image,
            'php', '-r', "echo PHP_MAJOR_VERSION, '.', PHP_MINOR_VERSION;"
        )

        $version | Should -Be $expectedVariant
    }

    It 'satisfies the platform runtime contract' {
        if ($Os -eq 'linux') {
            Invoke-Docker -Context $Context -RunArguments $DockerRunArguments -Arguments @('run', '--rm', $Image, 'grep', '--fixed-strings', 'VERSION_CODENAME=trixie', '/etc/os-release')
        }
		
        if ($Os -eq 'windows') {
			$powerShellMajor = Invoke-DockerOutput -Context $Context -RunArguments $DockerRunArguments -Arguments @(
				'run', '--rm', $Image,
				'pwsh', '-NoLogo', '-NoProfile', '-Command', '(Get-Host).Version.Major'
			)
			$powerShellMajor | Should -Be '7'

			foreach ($package in @('powershell-core', 'firefox', 'vcredist140')) {
				$installed = Invoke-DockerOutput -Context $Context -RunArguments $DockerRunArguments -Arguments @(
					'run', '--rm', $Image,
					'choco', 'list', '--local-only', '--exact', $package, '--limit-output'
				)
				$installed.ToLowerInvariant() | Should -Match "^$([Regex]::Escape($package.ToLowerInvariant()))\|"
			}
		}
    }
}

Describe "Farah HTTP behavior [$Os, PHP $Variant]" {
    Context 'with FARAH_PAGE_TYPE=<PageType>' -ForEach @(
        @{ PageType = 'xml'; ExpectedMediaType = 'application/xhtml+xml' }
        @{ PageType = 'html'; ExpectedMediaType = 'text/html' }
    ) {
        BeforeAll {
            $container = $null
            $container = Invoke-DockerOutput -Context $Context -RunArguments $DockerRunArguments -Arguments @(
                'run', '--detach',
                '--env', 'COMPOSER_UPDATE=skip',
                '--env', "FARAH_PAGE_TYPE=$PageType",
                $Image
            )
            Install-TestApplication $container

            try {
                Get-ResponseStatus -Container $container -Path '/' -Retry | Out-Null
            } catch {
                $logs = Get-DockerCommandResult -Context $Context -Arguments @('logs', $container)
                Write-Host ($logs.Output | Out-String)
                throw "$Image did not start serving HTTP"
            }
        }

        AfterAll {
            if ($container) {
                Remove-TestContainer $container
            }
        }

        It 'serves <Path> with the configured media type' -ForEach @(
            @{ Path = '/phpinfo/' }
            @{ Path = '/consumer-sitemap/' }
        ) {
            Get-ResponseStatus -Container $container -Path $Path | Should -Be '200'
            Get-ResponseMediaType -Container $container -Path $Path | Should -Be $ExpectedMediaType
        }

        It 'serves PHP information' {
            $phpInfo = Get-ResponseBody -Container $container -Path '/phpinfo/'

            $phpInfo | Should -Match '<title>PHP'
            $phpInfo | Should -Match 'phpinfo\(\)'
        }

        It 'reports the expected application statuses' {
            Get-ResponseStatus -Container $container -Path '/' | Should -Be '501'
            Get-ResponseStatus -Container $container -Path '/AboutMe/' | Should -Be '410'
        }
    }
}
