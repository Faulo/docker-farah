FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell", "-NonInteractive", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Chocolatey
RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

ARG PHP_VERSION=7.4
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR C:/www

# Apache
ENV SERVER_NAME=localhost
EXPOSE 80
COPY farah-${PHP_VERSION}.nuspec farah.nuspec
RUN choco pack farah.nuspec; \
    choco install --no-progress farah -y --source '.;https://community.chocolatey.org/api/v2/'; \
	Remove-Item -Force *.nuspec; \
	Remove-Item -Force *.nupkg

COPY apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
COPY mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
# We need to pass some time for apache to release its grip on httpd.conf, so let's ping it!
RUN ping localhost; \
    Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/custom.conf'; \
    Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/php.conf'
ENV COMPOSER_ALLOW_SUPERUSER=1

# PHP
COPY ext-${PHP_VERSION}/* C:/tools/php/ext/
RUN $phpPath = (Get-Command php | Select-Object -ExpandProperty Source); \
    $phpDir = Split-Path $phpPath; \
    $extDir = Join-Path $phpDir 'ext'; \
    Copy-Item -Path 'C:/tools/php/ext/*' -Destination $extDir -Force; \
    dir $extDir
COPY php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
ENV PHP_INI_SCAN_DIR=C:\\tools\\php
COPY php.ini C:/tools/php/custom.ini
RUN Add-Content -Path C:/tools/php/custom.ini -Value (Get-Content C:/tools/php/ext/php.ini -Raw)
RUN php -v; \
    php -m

# Farah
COPY farah C:/farah
RUN git config --global --add safe.directory *
CMD ["C:/farah/init.bat"]
