ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache
ARG PHP_VERSION=7.4
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# PHP extensions
RUN apt update \
 && apt install -y \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libzip-dev \
    unzip \
    libonig-dev \
    libpng-dev \
    libmagickwand-dev \
    imagemagick \
    git \
    libkrb5-dev \
 && apt upgrade -y \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

RUN pecl install \
    ds \
    imagick

RUN docker-php-ext-enable \
    opcache \
    ds \
    imagick

RUN docker-php-ext-configure \
    imap --with-kerberos --with-imap-ssl \
 && docker-php-ext-install \
    exif \
    xsl \
    gd \
    sockets \
    mysqli \
    intl \
    imap

# Farah
COPY --chmod=777 farah /usr/share/farah
RUN git config --global --add safe.directory *
CMD ["/usr/share/farah/init.sh"]

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Apache
ENV SERVER_NAME=localhost
EXPOSE 80
COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY apache.conf /etc/apache2/conf-available/custom.conf
RUN a2enconf custom
RUN php -v \
 && php -m