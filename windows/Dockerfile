FROM mcr.microsoft.com/dotnet/sdk:9.0-nanoserver-1809 AS build

WORKDIR C:/solution

ENV NUGET_PACKAGES=C:/nuget/packages

COPY . .

RUN dotnet publish docker-farah.sln \
        --configuration Release \
        --runtime win-x64 \
        --self-contained true \
        --property:PublishSingleFile=true \
        --property:UseAppHost=true \
        --property:DebugType=None

FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG VCREDIST_VERSION=14.50.35719
ARG VCREDIST_X64_SHA256=8995548DFFFCDE7C49987029C764355612BA6850EE09A7B6F0FDDC85BDC5C280
ARG VCREDIST_X86_SHA256=E7267C1BDF9237C0B4A28CF027C382B97AA909934F84F1C92D3FB9F04173B33E
ARG WIX_SHA256=2C1888D5D1DBA377FC7FA14444CF556963747FF9A0A289A3599CF09DA03B9E2E
ARG FIREFOX_VERSION=145.0.2
ARG FIREFOX_SHA256=5947ae4611b873b724e72375d4445cc21337fadae90ab618d335de869d781637

RUN Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { throw 'Chocolatey installation failed' }

# The redistributable installer hangs under Hyper-V isolation. Deploy its
# verified DLL payloads directly and provide matching local package metadata.
COPY windows/Install-VCRuntime.ps1 C:/build/Install-VCRuntime.ps1
RUN C:/build/Install-VCRuntime.ps1

COPY windows/vcredist140.nuspec C:/build/vcredist140.nuspec
COPY windows/farah-common.nuspec C:/build/farah-common.nuspec
RUN New-Item -ItemType Directory -Path C:/packages -Force | Out-Null; \
    choco pack C:/build/vcredist140.nuspec --output-directory C:/packages --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack vcredist140 failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco pack C:/build/farah-common.nuspec --output-directory C:/build --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack farah-common failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install farah-common --yes --no-progress --limit-output --source 'C:/packages;C:/build;https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install farah-common failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Recurse -Force C:/build

# Extract the browser without running its installer.
RUN $url = 'https://archive.mozilla.org/pub/firefox/releases/{0}/win64/en-US/Firefox%20Setup%20{0}.exe' -f $env:FIREFOX_VERSION; \
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile C:/firefox-installer.exe; \
    $actualHash = (Get-FileHash C:/firefox-installer.exe -Algorithm SHA256).Hash; \
    if ($actualHash -ne $env:FIREFOX_SHA256) { throw ('Firefox SHA-256 mismatch: {0}' -f $actualHash) }; \
    7z x C:/firefox-installer.exe -oC:/Firefox -y | Out-Null; \
    if ($LASTEXITCODE -notin 0, 1) { throw ('Firefox extraction failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Force C:/firefox-installer.exe; \
    $actualVersion = (Get-Item C:/Firefox/core/firefox.exe).VersionInfo.ProductVersion; \
    if ($actualVersion -ne $env:FIREFOX_VERSION) { throw ('Expected Firefox {0}, found {1}' -f $env:FIREFOX_VERSION, $actualVersion) }; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ('C:/Firefox/core;' + $machinePath), 'Machine')

# Fonts required by browser-based rendering.
ADD windows/FontsToAdd.tar C:/TMP/
RUN $fontRegistry = 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion/Fonts'; \
    Get-ChildItem C:/TMP/Fonts -File | ForEach-Object { \
        Copy-Item $_.FullName (Join-Path $env:WINDIR ('Fonts/' + $_.Name)) -Force; \
        New-ItemProperty -Path $fontRegistry -Name ($_.BaseName + ' (TrueType)') -Value $_.Name -PropertyType String -Force | Out-Null \
    }; \
    Remove-Item -Recurse -Force C:/TMP

# Install only the selected PHP version after the shared layers are cached.
ARG PHP_VERSION=8.2
ENV PHP_VERSION=${PHP_VERSION} \
    PHP_INI_SCAN_DIR=C:\\tools\\php \
    COMPOSER_ALLOW_SUPERUSER=1 \
    SERVER_NAME=localhost

WORKDIR C:/www
EXPOSE 80

COPY windows/farah-${PHP_VERSION}.nuspec C:/build/farah.nuspec
RUN choco pack C:/build/farah.nuspec --output-directory C:/build --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack farah failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install farah --yes --no-progress --limit-output --source 'C:/packages;C:/build;https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install farah failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Recurse -Force C:/packages, C:/build

# Composer's key update is interactive, so install the verified official keys.
ARG COMPOSER_DEV_PUB_SHA256=2B2DF89FB2581E669B4668B451097D4A03F4DC2D7A06DF197554064494A90A31
ARG COMPOSER_TAGS_PUB_SHA256=D8F3E350437BF3B5342DBF046064EBD1F017EBC720955433194360A01CFD074F
RUN $composerHome = (composer config --global home).Trim(); \
    if ($LASTEXITCODE -ne 0) { throw ('composer config failed with exit code {0}' -f $LASTEXITCODE) }; \
    New-Item -ItemType Directory -Path $composerHome -Force | Out-Null; \
    Invoke-WebRequest -UseBasicParsing -Uri https://composer.github.io/snapshots.pub -OutFile (Join-Path $composerHome 'keys.dev.pub'); \
    Invoke-WebRequest -UseBasicParsing -Uri https://composer.github.io/releases.pub -OutFile (Join-Path $composerHome 'keys.tags.pub'); \
    $devKeyHash = (Get-FileHash (Join-Path $composerHome 'keys.dev.pub') -Algorithm SHA256).Hash; \
    if ($devKeyHash -ne $env:COMPOSER_DEV_PUB_SHA256) { throw ('Composer dev key SHA-256 mismatch: {0}' -f $devKeyHash) }; \
    $tagsKeyHash = (Get-FileHash (Join-Path $composerHome 'keys.tags.pub') -Algorithm SHA256).Hash; \
    if ($tagsKeyHash -ne $env:COMPOSER_TAGS_PUB_SHA256) { throw ('Composer tags key SHA-256 mismatch: {0}' -f $tagsKeyHash) }

# Apache
COPY windows/apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY windows/php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
COPY windows/mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
RUN $httpdConfig = 'C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf'; \
    $includes = [Environment]::NewLine + 'Include conf/extra/custom.conf' + [Environment]::NewLine + 'Include conf/extra/php.conf'; \
    for ($attempt = 1; $attempt -le 30; $attempt++) { \
        try { Add-Content -Path $httpdConfig -Value $includes; break } \
        catch { \
            if ($attempt -eq 30) { throw }; \
            Start-Sleep -Seconds 1 \
        } \
    }; \
    Set-Service -Name Apache -StartupType Manual

# PHP extensions not supplied by the Chocolatey PHP package.
COPY windows/ext-${PHP_VERSION}/ C:/tools/php/ext/
COPY windows/php.ini C:/tools/php/custom.ini
RUN $phpDir = Split-Path (Get-Command php | Select-Object -ExpandProperty Source); \
    Copy-Item -Path C:/tools/php/ext/*.dll -Destination (Join-Path $phpDir 'ext') -Force; \
    Add-Content -Path C:/tools/php/custom.ini -Value (Get-Content C:/tools/php/ext/php.ini -Raw); \
    $composerDir = Split-Path (Get-Command composer | Select-Object -ExpandProperty Source); \
    $composerShim = Join-Path $composerDir 'composer.exe'; \
    $shimOutputArg = '--output=' + $composerShim; \
    $shimPathArg = '--path=' + (Join-Path $phpDir 'php.exe'); \
    $shimCommandArg = '--command=' + (Join-Path $composerDir 'composer.phar'); \
    C:/ProgramData/chocolatey/tools/shimgen.exe $shimOutputArg $shimPathArg $shimCommandArg; \
    if ($LASTEXITCODE -ne 0) { throw ('Creating composer.exe failed with exit code {0}' -f $LASTEXITCODE) }; \
    php -v; \
    if ($LASTEXITCODE -ne 0) { throw ('php -v failed with exit code {0}' -f $LASTEXITCODE) }; \
    php -m; \
    if ($LASTEXITCODE -ne 0) { throw ('php -m failed with exit code {0}' -f $LASTEXITCODE) }; \
    $phpInfo = php -i; \
    if ($LASTEXITCODE -ne 0) { throw ('php -i failed with exit code {0}' -f $LASTEXITCODE) }; \
    $openSslPattern = if ([version]$env:PHP_VERSION -lt [version]'8.2') { '1\.1\.1' } else { '3\.' }; \
    if (-not ($phpInfo -match ('^OpenSSL Library Version => OpenSSL ' + $openSslPattern))) { throw ('PHP {0} is using an unexpected OpenSSL version' -f $env:PHP_VERSION) }; \
    if (-not ($phpInfo -match ('^SSL Version => OpenSSL/' + $openSslPattern))) { throw ('PHP {0} curl is using an unexpected OpenSSL version' -f $env:PHP_VERSION) }; \
    & $composerShim --version; \
    if ($LASTEXITCODE -ne 0) { throw ('composer.exe failed with exit code {0}' -f $LASTEXITCODE) }

# Default application
RUN New-Item -ItemType Directory -Path C:/www/html -Force | Out-Null; \
    composer require slothsoft/farah --no-interaction --prefer-dist --optimize-autoloader; \
    if ($LASTEXITCODE -ne 0) { throw ('composer require failed with exit code {0}' -f $LASTEXITCODE) }

# Farah
COPY --from=build C:/solution/common/Farah/bin/Release/net9.0/win-x64/publish/ C:/farah/
COPY windows/farah/index.php C:/farah/index.php
RUN git config --global --add safe.directory *
ENV FARAH_AUTOLOAD_FILE="/var/www/vendor/autoload.php"
CMD ["C:/farah/farah.exe"]

# PowerShell
ARG POWERSHELL_MAJOR=7

ADD https://github.com/PowerShell/PowerShell/releases.atom C:/powershell-releases.atom

RUN $feed = Get-Content C:/powershell-releases.atom -Raw; \
    $versionPattern = 'releases/tag/v(' + [regex]::Escape($env:POWERSHELL_MAJOR) + '\.\d+\.\d+)"'; \
    $powershellVersions = [regex]::Matches($feed, $versionPattern) | \
      ForEach-Object { [version]$_.Groups[1].Value } | \
      Sort-Object -Unique -Descending; \
    foreach ($candidate in $powershellVersions) { \
        $candidateVersion = $candidate.ToString(); \
        $candidateArchive = 'PowerShell-' + $candidateVersion + '-win-x64.zip'; \
        $candidateUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v' + $candidateVersion; \
        curl.exe --fail --location --silent --show-error ($candidateUrl + '/hashes.sha256') -o C:/powershell-hashes; \
        if ($LASTEXITCODE -eq 0) { \
            $hashLine = Get-Content C:/powershell-hashes | Where-Object { $_ -match ('\*' + [regex]::Escape($candidateArchive) + '$') }; \
            if ($hashLine) { \
                $powershellVersion = $candidateVersion; \
                $archiveName = $candidateArchive; \
                $powershellUrl = $candidateUrl; \
                break; \
            } \
        } \
    }; \
    if (-not $powershellVersion) { throw ('No complete stable PowerShell ' + $env:POWERSHELL_MAJOR + ' release found') }; \
    $archive = 'C:/' + $archiveName; \
    $archiveUrl = $powershellUrl + '/' + $archiveName; \
    curl.exe --fail --location --retry 5 --retry-all-errors $archiveUrl -o $archive; \
    if ($LASTEXITCODE -ne 0) { throw ('Failed to download ' + $archiveUrl) }; \
    $expectedHash = ($hashLine -split '\s+')[0]; \
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash; \
    if ($actualHash -ne $expectedHash) { throw ('Checksum verification failed for ' + $archiveName) }; \
    $destination = 'C:/Program Files/PowerShell/7'; \
    New-Item -ItemType Directory -Force $destination | Out-Null; \
    Expand-Archive -LiteralPath $archive -DestinationPath $destination; \
    Remove-Item -LiteralPath $archive,C:/powershell-hashes,C:/powershell-releases.atom; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ($destination + ';' + $machinePath), 'Machine'); \
    $env:Path = $destination + ';' + $env:Path; \
    pwsh -NoLogo -NoProfile -Command \
        'if ($PSVersionTable.PSVersion.Major -ne [int]$env:POWERSHELL_MAJOR) { exit 1 }'; \
    if ($LASTEXITCODE -ne 0) { throw 'PowerShell smoke check failed' }
