FROM mcr.microsoft.com/dotnet/framework/runtime:4.8-windowsservercore-ltsc2019

SHELL ["powershell", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop';"]

# Chocolatey
RUN [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

ARG PHP_VERSION=7.4
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR C:/www

# Apache
COPY farah-${PHP_VERSION}.nuspec farah.nuspec
RUN choco pack farah.nuspec; \
    choco install farah -y --source '.;https://community.chocolatey.org/api/v2/'; \
	Remove-Item -Force *.nuspec; \
	Remove-Item -Force *.nupkg

COPY apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
COPY mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
RUN Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/custom.conf'
RUN Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/php.conf'
ENV SERVER_NAME=localhost
ENV COMPOSER_ALLOW_SUPERUSER=1

# PHP
ENV PHP_INI_SCAN_DIR=C:\\tools\\php
COPY php.ini C:/tools/php/custom.ini
RUN php -m

# Farah
COPY farah C:/farah
RUN git config --global --add safe.directory *
CMD ["C:/farah/init.bat"]
EXPOSE 80
