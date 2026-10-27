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
    [AllowEmptyCollection()]
    [string[]] $DockerRunArguments
)

BeforeAll {
    . (Join-Path $PSScriptRoot '../.jenkins/Docker.ps1')

    function Get-WebDriverValue {
        param(
            [Parameter(Mandatory)]
            [string] $Container,

            [Parameter(Mandatory)]
            [string] $Url,

            [string] $Method = 'Get',

            [object] $Body
        )

        $arguments = @('exec', $Container, 'curl', '--silent', '--show-error', '--fail-with-body', '--max-time', '60', '--request', $Method.ToUpperInvariant())
        if ($null -ne $Body) {
            $arguments += @('--header', 'Content-Type: application/json', '--data-raw', (ConvertTo-Json -InputObject $Body -Depth 10 -Compress))
        }
        $arguments += $Url

        $result = Get-DockerCommandResult -Context $Context -Arguments $arguments
        if ($result.ExitCode -ne 0) {
            throw "WebDriver $Method $Url failed: $($result.Output | Out-String)"
        }

        return (($result.Output | Out-String) | ConvertFrom-Json).value
    }

    $architecture = Invoke-DockerOutput -Context $Context -Arguments @('info', '--format', '{{.Architecture}}')
    $platform = if ($Os -eq 'windows') {
        'win64.zip'
    } elseif ($architecture -in @('x86_64', 'amd64')) {
        'linux64.tar.gz'
    } elseif ($architecture -in @('aarch64', 'arm64')) {
        'linux-aarch64.tar.gz'
    } else {
        throw "Unsupported Docker architecture: $architecture"
    }

    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/mozilla/geckodriver/releases/latest' -NoProxy
    $asset = @($release.assets | Where-Object { $_.name -eq "geckodriver-$($release.tag_name)-$platform" })
    if ($asset.Count -ne 1) {
        throw "Expected one geckodriver asset for $platform, found $($asset.Count)"
    }

    $driverDirectory = Join-Path ([IO.Path]::GetTempPath()) ("farah-geckodriver-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $driverDirectory | Out-Null
    $archive = Join-Path $driverDirectory $asset[0].name
    Invoke-WebRequest -Uri $asset[0].browser_download_url -OutFile $archive -NoProxy
    if ($Os -eq 'windows') {
        Expand-Archive -LiteralPath $archive -DestinationPath $driverDirectory
        $driver = Join-Path $driverDirectory 'geckodriver.exe'
        $containerDriver = 'C:/geckodriver.exe'
    } else {
        & tar -xzf $archive -C $driverDirectory
        if ($LASTEXITCODE -ne 0) { throw 'Extracting geckodriver failed' }
        $driver = Join-Path $driverDirectory 'geckodriver'
        $containerDriver = '/geckodriver'
    }
    if (-not (Test-Path -LiteralPath $driver)) {
        throw "geckodriver is missing from $archive"
    }

}

AfterAll {
    if ($driverDirectory -and (Test-Path -LiteralPath $driverDirectory)) {
        Remove-Item -LiteralPath $driverDirectory -Recurse -Force
    }
}

Describe "Firefox WebDriver [$Os, PHP $Variant]" {
    It 'opens the bundled PHP page and executes JavaScript in its first session' {
        $container = $null
        $sessionId = $null
        $driverUrl = $null

        try {
            $createArguments = @('create') + $DockerRunArguments + @($Image)
            $container = Invoke-DockerOutput -Context $Context -Arguments $createArguments
            Invoke-Docker -Context $Context -Arguments @('cp', $driver, "${container}:$containerDriver")
            Invoke-Docker -Context $Context -Arguments @('start', $container)

            $pageStatus = Invoke-DockerOutput -Context $Context -Arguments @(
                'exec', $container, 'curl', '--silent',
                '--retry', '30', '--retry-connrefused', '--retry-delay', '1',
                '--output', ($Os -eq 'windows' ? 'NUL' : '/dev/null'),
                '--write-out', '%{http_code}', 'http://localhost/slothsoft@farah/phpinfo'
            )
            $pageStatus | Should -Be '200'

            if ($Os -eq 'linux') {
                Invoke-Docker -Context $Context -Arguments @('exec', $container, 'chmod', '+x', $containerDriver)
            }
            Invoke-Docker -Context $Context -Arguments @('exec', '--detach', $container, $containerDriver, '--host', '127.0.0.1', '--port', '4444', '--log', 'trace')

            $driverUrl = 'http://localhost:4444'

            $ready = $false
            $lastStatusError = $null
            for ($attempt = 0; $attempt -lt 30; $attempt++) {
                try {
                    $status = Get-WebDriverValue -Container $container -Url "$driverUrl/status"
                    if ($status.ready) { $ready = $true; break }
                } catch {
                    $lastStatusError = $_.Exception.Message
                    Start-Sleep -Seconds 1
                }
            }
            if (-not $ready) { throw "geckodriver at $driverUrl did not become ready: $lastStatusError" }

            $session = Get-WebDriverValue -Container $container -Url "$driverUrl/session" -Method Post -Body @{
                capabilities = @{
                    alwaysMatch = @{
                        browserName = 'firefox'
                        'moz:firefoxOptions' = @{
                            args = @('--headless', '--window-size=1200,1100', '--no-deelevate', '--new-instance')
                        }
                    }
                }
            }
            $sessionId = $session.sessionId
            $sessionId | Should -Not -BeNullOrEmpty

            Get-WebDriverValue -Container $container -Url "$driverUrl/session/$sessionId/url" -Method Post -Body @{
                url = 'http://localhost/slothsoft@farah/phpinfo'
            } | Out-Null
            $title = Get-WebDriverValue -Container $container -Url "$driverUrl/session/$sessionId/title"
            $title | Should -Match '^PHP \d+\.\d+\.\d+ - phpinfo\(\)$'

            $result = Get-WebDriverValue -Container $container -Url "$driverUrl/session/$sessionId/execute/sync" -Method Post -Body @{
                script = 'return document.body.textContent.includes("PHP Version") && 2 + 3 === 5;'
                args = @()
            }
            $result | Should -BeTrue
        } finally {
            if ($sessionId -and $driverUrl) {
                try { Get-WebDriverValue -Container $container -Url "$driverUrl/session/$sessionId" -Method Delete | Out-Null }
                catch { Write-Verbose "Closing WebDriver session failed: $($_.Exception.Message)" }
            }
            if ($container) {
                Invoke-Docker -Context $Context -Arguments @('rm', '--force', '--volumes', $container)
            }
        }
    }
}
