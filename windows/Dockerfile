FROM mcr.microsoft.com/dotnet/sdk:9.0-nanoserver-1809 AS build

WORKDIR C:/solution

ENV NUGET_PACKAGES=C:/nuget/packages

COPY . .

RUN dotnet publish --runtime win-x64

FROM faulo/choco:windowsservercore-ltsc2019

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG PHP_VERSION=8.2
ENV PHP_VERSION=${PHP_VERSION} \
    PHP_INI_SCAN_DIR=C:\\tools\\php \
    COMPOSER_ALLOW_SUPERUSER=1 \
    SERVER_NAME=localhost

WORKDIR C:/www
EXPOSE 80

COPY windows/farah-common.nuspec C:/package/farah-common.nuspec
COPY windows/farah-${PHP_VERSION}.nuspec C:/package/farah.nuspec
# hadolint shell=powershell
RUN choco-install C:/package/farah-common.nuspec C:/package/farah.nuspec; \
    if ($LASTEXITCODE -ne 0) { throw ('choco-install Farah manifests failed with exit code {0}' -f $LASTEXITCODE) }; \
    $firefoxDirectory = 'C:/Program Files/Mozilla Firefox'; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ($firefoxDirectory + ';' + $machinePath), 'Machine'); \
    Remove-Item -Recurse -Force C:/package

# hadolint shell=powershell
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
# hadolint shell=powershell
RUN $fontRegistry = 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion/Fonts'; \
    Get-ChildItem C:/TMP/Fonts -File | ForEach-Object { \
        Copy-Item $_.FullName (Join-Path $env:WINDIR ('Fonts/' + $_.Name)) -Force; \
        New-ItemProperty -Path $fontRegistry -Name ($_.BaseName + ' (TrueType)') -Value $_.Name -PropertyType String -Force | Out-Null \
    }; \
    Remove-Item -Recurse -Force C:/TMP

# Apache
COPY windows/apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY windows/php.conf C:/build/php.conf
COPY windows/mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
# hadolint shell=powershell
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
# hadolint shell=powershell
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
# hadolint shell=powershell
RUN New-Item -ItemType Directory -Path C:/www/html -Force | Out-Null; \
    composer require slothsoft/farah --no-interaction --prefer-dist --optimize-autoloader; \
    if ($LASTEXITCODE -ne 0) { throw ('composer require failed with exit code {0}' -f $LASTEXITCODE) }; \
    composer config license proprietary; \
    if ($LASTEXITCODE -ne 0) { throw ('composer config failed with exit code {0}' -f $LASTEXITCODE) }

# Farah
COPY --from=build C:/solution/common/Farah/bin/Release/net9.0/win-x64/publish/ C:/farah/
COPY windows/farah/index.php C:/farah/index.php
# hadolint shell=powershell
RUN git config --global --add safe.directory *; \
    C:/ProgramData/chocolatey/tools/shimgen.exe --output=C:/ProgramData/chocolatey/bin/farah.exe --path=C:/farah/farah.exe; \
    if ($LASTEXITCODE -ne 0) { throw ('Creating farah.exe failed with exit code {0}' -f $LASTEXITCODE) }
ENV FARAH_AUTOLOAD_FILE="C:/www/vendor/autoload.php"
HEALTHCHECK CMD ["farah", "health"]
CMD ["farah", "serve"]
