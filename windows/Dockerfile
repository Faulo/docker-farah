FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG PHP_VERSION=7.4

ENV PHP_VERSION=${PHP_VERSION} \
    PHP_INI_SCAN_DIR=C:\\tools\\php \
    COMPOSER_ALLOW_SUPERUSER=1 \
    SERVER_NAME=localhost

WORKDIR C:/www
EXPOSE 80

# Install the PHP version selected by the local package's dependency range.
RUN Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { throw 'Chocolatey installation failed' }

COPY farah-${PHP_VERSION}.nuspec C:/build/farah.nuspec
RUN choco pack C:/build/farah.nuspec --output-directory C:/build --limit-output; \
    if ($LASTEXITCODE -ne 0) { throw ('choco pack failed with exit code {0}' -f $LASTEXITCODE) }; \
    choco install farah --yes --no-progress --limit-output --source 'C:/build;https://community.chocolatey.org/api/v2/'; \
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw ('choco install failed with exit code {0}' -f $LASTEXITCODE) }; \
    Remove-Item -Recurse -Force C:/build; \
    Get-ChildItem $env:TEMP -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

ARG FIREFOX_VERSION=145.0.2
ARG FIREFOX_SHA256=5947ae4611b873b724e72375d4445cc21337fadae90ab618d335de869d781637

# The native installer works on Server Core and registers Firefox for geckodriver.
RUN $url = 'https://archive.mozilla.org/pub/firefox/releases/{0}/win64/en-US/Firefox%20Setup%20{0}.exe' -f $env:FIREFOX_VERSION; \
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile C:/firefox-installer.exe; \
    $actualHash = (Get-FileHash C:/firefox-installer.exe -Algorithm SHA256).Hash; \
    if ($actualHash -ne $env:FIREFOX_SHA256) { throw ('Firefox SHA-256 mismatch: {0}' -f $actualHash) }; \
    $arguments = '/S', '/InstallDirectoryPath=C:/Firefox', '/TaskbarShortcut=false', '/DesktopShortcut=false', '/StartMenuShortcut=false', '/PrivateBrowsingShortcut=false', '/MaintenanceService=false', '/RegisterDefaultAgent=false', '/PreventRebootRequired=true', '/OptionalExtensions=false'; \
    $process = Start-Process C:/firefox-installer.exe -ArgumentList $arguments -Wait -PassThru; \
    if ($process.ExitCode -ne 0) { throw ('Firefox installation failed with exit code {0}' -f $process.ExitCode) }; \
    Remove-Item -Force C:/firefox-installer.exe; \
    $actualVersion = (Get-Item C:/Firefox/firefox.exe).VersionInfo.ProductVersion; \
    if ($actualVersion -ne $env:FIREFOX_VERSION) { throw ('Expected Firefox {0}, found {1}' -f $env:FIREFOX_VERSION, $actualVersion) }; \
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine'); \
    [Environment]::SetEnvironmentVariable('Path', ('C:/Firefox;' + $machinePath), 'Machine'); \
    & C:/Firefox/firefox.exe --version; \
    if ($LASTEXITCODE -ne 0) { throw ('Firefox smoke check failed with exit code {0}' -f $LASTEXITCODE) }

# Fonts required by browser-based rendering.
ADD FontsToAdd.tar C:/TMP/
RUN C:/TMP/Add-Font.ps1 C:/TMP/Fonts; \
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
