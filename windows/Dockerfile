# Start with a Windows image with Chocolatey pre-installed
FROM chocolatey/choco:latest-windows
SHELL ["powershell", "-Command"]
ARG PHP_VERSION=7.4
ENV PHP_VERSION=${PHP_VERSION}

# Farah
COPY farah C:/farah
CMD ["C:/farah/init.bat"]

# Apache
WORKDIR C:/farah
RUN choco pack farah-$env:PHP_VERSION.nuspec; \
    choco install farah -y --source '.;https://community.chocolatey.org/api/v2/'; \
	Remove-Item -Force *.nuspec; \
	Remove-Item -Force *.nupkg
	
COPY apache.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/custom.conf
COPY php-${PHP_VERSION}.conf C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/extra/php.conf
COPY mod_fcgid.so C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/modules/mod_fcgid.so
RUN Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/custom.conf'
RUN Add-Content -Path C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/conf/httpd.conf -Value 'Include conf/extra/php.conf'
ENV SERVER_NAME=localhost
EXPOSE 80

# PHP
ENV PHP_INI_SCAN_DIR=C:\\tools\\php
COPY php.ini C:/tools/php/custom.ini
RUN php -m

# Composer
WORKDIR C:/www
ENV COMPOSER_ALLOW_SUPERUSER=1

# Cleanup
RUN net stop Apache; \
    Remove-Item -Recurse -Force C:/Users/ContainerAdministrator/AppData/Roaming/Apache24/logs/*