ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache
WORKDIR /var/www

# PHP extensions
RUN apt update
RUN apt install -y libcurl4-openssl-dev && \
	docker-php-ext-install curl && \
	docker-php-ext-enable curl
RUN apt install -y libxslt1-dev && \
    docker-php-ext-install xsl && \
	docker-php-ext-enable xsl
RUN apt install -y libzip-dev unzip && \
	docker-php-ext-install zip && \
	docker-php-ext-enable zip
RUN apt install -y libonig-dev && \
    docker-php-ext-install mbstring && \
	docker-php-ext-enable mbstring
RUN apt install -y libpng-dev imagemagick && \
    docker-php-ext-install gd && \
	docker-php-ext-enable gd
RUN docker-php-ext-install fileinfo && \
	docker-php-ext-enable fileinfo
RUN docker-php-ext-install sockets && \
	docker-php-ext-enable sockets
RUN docker-php-ext-install exif && \
	docker-php-ext-enable exif
RUN docker-php-ext-install intl && \
	docker-php-ext-enable intl
RUN docker-php-ext-install dom && \
	docker-php-ext-enable dom
RUN apt upgrade -y

# Farah
COPY --chmod=777 farah /usr/share/farah
CMD ["/usr/share/farah/init.sh"]

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ARG COMPOSER_ALLOW_SUPERUSER=1
RUN composer require slothsoft/farah --update-no-dev

# Apache
COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY apache.conf /etc/apache2/conf-available/custom.conf
RUN a2enconf custom

EXPOSE 80