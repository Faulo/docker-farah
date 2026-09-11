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

ARG WIX_SHA256=2C1888D5D1DBA377FC7FA14444CF556963747FF9A0A289A3599CF09DA03B9E2E

RUN Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { throw 'Chocolatey installation failed' }

COPY windows/Install-Firefox.ps1 C:/build/Install-Firefox.ps1
COPY windows/Install-VCRuntime.ps1 C:/build/Install-VCRuntime.ps1

# These installers are not reliable under container isolation. Register the
# newest Chocolatey packages without their scripts, then extract verified payloads.
RUN choco install 7zip --yes --no-progress --limit-output --source 'https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install 7zip failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install firefox --yes --no-progress --limit-output --skip-powershell --source 'https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco register firefox failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install vcredist140 --yes --no-progress --limit-output --skip-powershell --source 'https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco register vcredist140 failed with exit code {0}' -f $LASTEXITCODE) }; \
    $firefoxPackage = @(choco list --local-only --exact firefox --limit-output); \
    if ($LASTEXITCODE -ne 0 -or $firefoxPackage.Count -ne 1) { throw 'Expected exactly one Chocolatey Firefox package' }; \
    $firefoxVersion = ($firefoxPackage[0] -split '\|')[1]; \
    C:/build/Install-Firefox.ps1 -PackageToolsPath C:/ProgramData/chocolatey/lib/firefox/tools -Version $firefoxVersion; \
    C:/build/Install-VCRuntime.ps1 -PackageToolsPath C:/ProgramData/chocolatey/lib/vcredist140/tools -WixSha256 $env:WIX_SHA256

COPY windows/farah-common.nuspec C:/package/farah-common.nuspec
RUN choco pack C:/package/farah-common.nuspec --output-directory C:/package --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack farah-common failed with exit code {0}' -f $LASTEXITCODE) }; \
    [xml]$commonManifest = Get-Content C:/package/farah-common.nuspec -Raw; \
    $commonDependencies = $commonManifest.package.metadata.dependencies.dependency.id; \
    foreach ($dependency in $commonDependencies) { \
        choco install $dependency --yes --no-progress --limit-output --source 'https://community.chocolatey.org/api/v2/'; \
        if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install {0} failed with exit code {1}' -f $dependency, $LASTEXITCODE) } \
    }; \
    choco install farah-common --yes --no-progress --limit-output --ignore-dependencies --source C:/package; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install farah-common failed with exit code {0}' -f $LASTEXITCODE) }; \
    $firefoxDirectory = 'C:/Firefox/core'; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ($firefoxDirectory + ';' + $machinePath), 'Machine'); \
    Remove-Item -Recurse -Force C:/build,C:/package

RUN $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User'); \
    C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/bin/httpd.exe -v; if ($LASTEXITCODE -ne 0) { throw 'Apache smoke check failed' }; \
    pwsh.exe -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'; if ($LASTEXITCODE -ne 0) { throw 'PowerShell smoke check failed' }; \
    firefox.exe --version; if ($LASTEXITCODE -ne 0) { throw 'Firefox smoke check failed' }; \
    git.exe --version; if ($LASTEXITCODE -ne 0) { throw 'Git smoke check failed' }; \
    curl.exe --version; if ($LASTEXITCODE -ne 0) { throw 'curl smoke check failed' }; \
    magick.exe -version; if ($LASTEXITCODE -ne 0) { throw 'ImageMagick smoke check failed' }; \
    7z.exe i | Out-Null; if ($LASTEXITCODE -ne 0) { throw '7-Zip smoke check failed' }; \
    unzip.exe -v | Out-Null; if ($LASTEXITCODE -ne 0) { throw 'UnZip smoke check failed' }

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
    choco install farah --yes --no-progress --limit-output --source 'C:/build;https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install farah failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Recurse -Force C:/build

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
COPY windows/php.conf C:/build/php.conf
COPY windows/mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
RUN $httpdConfig = 'C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf'; \
    $phpConfig = 'C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf'; \
    $phpVersionPath = $env:PHP_VERSION.Replace('.', ''); \
    (Get-Content C:/build/php.conf -Raw).Replace('{PHP_VERSION_PATH}', $phpVersionPath) | Set-Content $phpConfig; \
    Remove-Item -Recurse -Force C:/build; \
    $includes = [Environment]::NewLine + 'Include conf/extra/custom.conf' + [Environment]::NewLine + 'Include conf/extra/php.conf'; \
    for ($attempt = 1; $attempt -le 30; $attempt++) { \
        try { Add-Content -Path $httpdConfig -Value $includes; break } \
        catch { \
            if ($attempt -eq 30) { throw }; \
            Start-Sleep -Seconds 1 \
        } \
    }; \
    Set-Service -Name Apache -StartupType Manual; \
    New-Item -ItemType Directory -Path C:/www/html -Force | Out-Null; \
    C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/bin/httpd.exe -t; \
    if ($LASTEXITCODE -ne 0) { throw ('Apache configuration check failed with exit code {0}' -f $LASTEXITCODE) }

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
    $phpPackage = @(choco list --local-only --exact php --limit-output); \
    if ($LASTEXITCODE -ne 0 -or $phpPackage.Count -ne 1) { throw 'Expected exactly one Chocolatey PHP package' }; \
    $installedPhpVersion = [version](($phpPackage[0] -split '\|')[1]); \
    if (('{0}.{1}' -f $installedPhpVersion.Major, $installedPhpVersion.Minor) -ne $env:PHP_VERSION) { throw ('Expected Chocolatey PHP {0}, found {1}' -f $env:PHP_VERSION, $installedPhpVersion) }; \
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
    if ($LASTEXITCODE -ne 0) { throw ('composer require failed with exit code {0}' -f $LASTEXITCODE) }; \
    composer config license proprietary; \
    if ($LASTEXITCODE -ne 0) { throw ('composer config failed with exit code {0}' -f $LASTEXITCODE) }

# Farah
COPY --from=build C:/solution/common/Farah/bin/Release/net9.0/win-x64/publish/ C:/farah/
COPY windows/farah/index.php C:/farah/index.php
RUN git config --global --add safe.directory *
ENV FARAH_AUTOLOAD_FILE="C:/www/vendor/autoload.php"
CMD ["C:/farah/farah.exe"]
