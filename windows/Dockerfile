FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG PHP_VERSION=7.4
ARG VCREDIST_VERSION=14.50.35719
ARG VCREDIST_X64_SHA256=8995548DFFFCDE7C49987029C764355612BA6850EE09A7B6F0FDDC85BDC5C280
ARG VCREDIST_X86_SHA256=E7267C1BDF9237C0B4A28CF027C382B97AA909934F84F1C92D3FB9F04173B33E
ARG WIX_SHA256=2C1888D5D1DBA377FC7FA14444CF556963747FF9A0A289A3599CF09DA03B9E2E

ENV PHP_VERSION=${PHP_VERSION} \
    PHP_INI_SCAN_DIR=C:\\tools\\php \
    COMPOSER_ALLOW_SUPERUSER=1 \
    SERVER_NAME=localhost

WORKDIR C:/www
EXPOSE 80

# Install the PHP version selected by the local package's dependency range.
RUN Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { throw 'Chocolatey installation failed' }

# The redistributable installer hangs under Hyper-V isolation. Deploy its
# verified DLL payloads directly and provide matching local package metadata.
COPY Install-VCRuntime.ps1 C:/build/Install-VCRuntime.ps1
RUN C:/build/Install-VCRuntime.ps1

COPY farah-${PHP_VERSION}.nuspec C:/build/farah.nuspec
COPY vcredist140.nuspec C:/build/vcredist140.nuspec
RUN choco pack C:/build/vcredist140.nuspec --output-directory C:/build --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack vcredist140 failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco pack C:/build/farah.nuspec --output-directory C:/build --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install farah --yes --no-progress --limit-output --source 'C:/build;https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Recurse -Force C:/build

ARG FIREFOX_VERSION=145.0.2
ARG FIREFOX_SHA256=5947ae4611b873b724e72375d4445cc21337fadae90ab618d335de869d781637

# Extract the browser without installing shortcuts, services, or update tasks.
RUN $url = 'https://archive.mozilla.org/pub/firefox/releases/{0}/win64/en-US/Firefox%20Setup%20{0}.exe' -f $env:FIREFOX_VERSION; \
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile C:/firefox-installer.exe; \
    $actualHash = (Get-FileHash C:/firefox-installer.exe -Algorithm SHA256).Hash; \
    if ($actualHash -ne $env:FIREFOX_SHA256) { throw ('Firefox SHA-256 mismatch: {0}' -f $actualHash) }; \
    $process = Start-Process C:/firefox-installer.exe -ArgumentList '/ExtractDir=C:/Firefox' -Wait -PassThru; \
    if ($process.ExitCode -ne 0) { throw ('Firefox extraction failed with exit code {0}' -f $process.ExitCode) }; \
    Remove-Item -Force C:/firefox-installer.exe; \
    $actualVersion = (Get-Item C:/Firefox/core/firefox.exe).VersionInfo.ProductVersion; \
    if ($actualVersion -ne $env:FIREFOX_VERSION) { throw ('Expected Firefox {0}, found {1}' -f $env:FIREFOX_VERSION, $actualVersion) }; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ('C:/Firefox/core;' + $machinePath), 'Machine')

# Fonts required by browser-based rendering.
ADD FontsToAdd.tar C:/TMP/
RUN $fontRegistry = 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion/Fonts'; \
    Get-ChildItem C:/TMP/Fonts -File | ForEach-Object { \
        Copy-Item $_.FullName (Join-Path $env:WINDIR ('Fonts/' + $_.Name)) -Force; \
        New-ItemProperty -Path $fontRegistry -Name ($_.BaseName + ' (TrueType)') -Value $_.Name -PropertyType String -Force | Out-Null \
    }; \
    Remove-Item -Recurse -Force C:/TMP

# Apache
COPY apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
COPY mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
RUN $httpdConfig = 'C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf'; \
    $includes = [Environment]::NewLine + 'Include conf/extra/custom.conf' + [Environment]::NewLine + 'Include conf/extra/php.conf'; \
    for ($attempt = 1; $attempt -le 30; $attempt++) { \
        try { Add-Content -Path $httpdConfig -Value $includes; break } \
        catch { \
            if ($attempt -eq 30) { throw }; \
            Start-Sleep -Seconds 1 \
        } \
    }

# PHP extensions not supplied by the Chocolatey PHP package.
COPY ext-${PHP_VERSION}/ C:/tools/php/ext/
COPY php.ini C:/tools/php/custom.ini
RUN $phpDir = Split-Path (Get-Command php | Select-Object -ExpandProperty Source); \
    Copy-Item -Path C:/tools/php/ext/*.dll -Destination (Join-Path $phpDir 'ext') -Force; \
    Add-Content -Path C:/tools/php/custom.ini -Value (Get-Content C:/tools/php/ext/php.ini -Raw); \
    php -v; \
    if ($LASTEXITCODE -ne 0) { throw ('php -v failed with exit code {0}' -f $LASTEXITCODE) }; \
    php -m; \
    if ($LASTEXITCODE -ne 0) { throw ('php -m failed with exit code {0}' -f $LASTEXITCODE) }

# Farah
COPY farah C:/farah
RUN git config --global --add safe.directory *
CMD ["C:/farah/init.bat"]
