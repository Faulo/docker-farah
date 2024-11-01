# Start with a Windows Server Core image with PHP pre-installed
ARG PHP_VERSION=7.4
FROM chocolatey/choco:latest-windows
SHELL ["powershell", "-Command"]

# curl
RUN choco install curl -y; \
    Remove-Item Alias:curl -Force; \
    curl --version

# Apache
RUN choco install apache-httpd -y
COPY apache.conf C:/tools/Apache24/conf/custom.conf
WORKDIR C:/tools/Apache24/htdocs
EXPOSE 80

# PHP
RUN choco install php -y
ENV PATH="C:\\tools\\php;${PATH}"

# PHP extensions
RUN php -m

# Farah
COPY farah C:/farah
CMD ["C:/farah/init.bat"]
