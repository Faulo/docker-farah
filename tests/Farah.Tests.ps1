param(
    [Parameter(Mandatory)]
    [string] $Image,

    [Parameter(Mandatory)]
    [ValidateSet('linux', 'windows')]
    [string] $Os,

    [Parameter(Mandatory)]
    [string] $Variant,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [string[]] $Capabilities
)

BeforeAll {
    function Invoke-Docker {
        param(
            [Parameter(Mandatory)]
            [string[]] $Arguments
        )

        & docker @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed with exit code ${LASTEXITCODE}: docker $($Arguments -join ' ')"
        }
    }

    function Invoke-DockerOutput {
        param(
            [Parameter(Mandatory)]
            [string[]] $Arguments
        )

        $output = & docker @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed with exit code ${LASTEXITCODE}: docker $($Arguments -join ' ')`n$($output | Out-String)"
        }
        return ($output | Out-String).Trim()
    }

    function Remove-TestContainer {
        param(
            [Parameter(Mandatory)]
            [string] $Container
        )

        $null = & docker container inspect $Container 2>$null
        if ($LASTEXITCODE -eq 0) {
            & docker container rm --force --volumes $Container | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to remove test container $Container"
            }
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

        Invoke-Docker @('cp', (Join-Path $fixture '.'), "${Container}:${applicationDirectory}")
        Invoke-Docker @('exec', $Container, $composer, 'dump-autoload', '--no-interaction', '--optimize')
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
        return Invoke-DockerOutput $arguments
    }

    function Get-ResponseBody {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Path
        )

        return Invoke-DockerOutput @('exec', $Container, 'curl', '--fail', '--silent', '--show-error', "http://localhost$Path")
    }

    function Get-ResponseMediaType {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Path
        )

        $nullDevice = $Os -eq 'windows' ? 'NUL' : '/dev/null'
        $contentType = Invoke-DockerOutput @(
            'exec', $Container, 'curl', '--fail', '--silent', '--show-error',
            '--output', $nullDevice, '--write-out', '%{content_type}', "http://localhost$Path"
        )
        return $contentType.Split(';', 2)[0].Trim()
    }
}

Describe "Farah runtime [$Os, PHP $Variant]" {
    It "provides PHP $Variant" {
        $version = Invoke-DockerOutput @(
            'run', '--rm', $Image,
            'php', '-r', "echo PHP_MAJOR_VERSION, '.', PHP_MINOR_VERSION;"
        )

        $version | Should -Be $Variant
    }

    It 'satisfies the platform runtime contract' {
        if ($Os -eq 'linux') {
            Invoke-Docker @('run', '--rm', $Image, 'grep', '--fixed-strings', 'VERSION_CODENAME=bullseye', '/etc/os-release')
        }
		
        if ($Os -eq 'windows') {
			$powerShellMajor = Invoke-DockerOutput @(
				'run', '--rm', $Image,
				'pwsh', '-NoLogo', '-NoProfile', '-Command', '(Get-Host).Version.Major'
			)
			$powerShellMajor | Should -Be '7'

			foreach ($package in @('powershell-core', 'firefuchs', 'vcredist140')) {
				$installed = Invoke-DockerOutput @(
					'run', '--rm', $Image,
					'choco', 'list', '--local-only', '--exact', $package, '--limit-output'
				)
				$installed.ToLowerInvariant() | Should -Match "^$([Regex]::Escape($package.ToLowerInvariant()))\\|"
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
            $container = Invoke-DockerOutput @(
                'run', '--detach',
                '--env', 'COMPOSER_UPDATE=skip',
                '--env', "FARAH_PAGE_TYPE=$PageType",
                $Image
            )
            Install-TestApplication $container

            try {
                Get-ResponseStatus -Container $container -Path '/' -Retry | Out-Null
            } catch {
                & docker logs $container
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
