ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache
ARG PHP_VERSION=7.4
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# PHP extensions
RUN apt update
RUN apt install -y libcurl4-openssl-dev && \
	docker-php-ext-install curl
RUN apt install -y libxslt1-dev && \
    docker-php-ext-install xsl
RUN apt install -y libzip-dev unzip && \
	docker-php-ext-install zip
RUN apt install -y libonig-dev && \
    docker-php-ext-install mbstring
RUN apt install -y libpng-dev imagemagick && \
    docker-php-ext-install gd
RUN docker-php-ext-install fileinfo
RUN docker-php-ext-install sockets
RUN docker-php-ext-install exif
RUN docker-php-ext-install intl
RUN docker-php-ext-install dom
RUN docker-php-ext-install mysqli
RUN pecl install ds && docker-php-ext-enable ds
RUN apt upgrade -y

# Farah
COPY --chmod=777 farah /usr/share/farah
CMD ["/usr/share/farah/init.sh"]

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer require slothsoft/farah --update-no-dev

# Apache
COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY apache.conf /etc/apache2/conf-available/custom.conf
RUN a2enconf custom
RUN chmod 777 /var/www

ENV SERVER_NAME=localhost
EXPOSE 80

# Cleanup
RUN apt clean && rm -rf /var/lib/apt/lists/*