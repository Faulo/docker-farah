ARG PHP_VERSION=7.4
ARG DEBIAN=bullseye
FROM php:${PHP_VERSION}-apache-${DEBIAN}
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
    libc-client-dev \
    libkrb5-dev \
    wget \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    pecl install ds imagick; \
    if dpkg --compare-versions "$PHP_VERSION" ge "8.4"; then \
        pecl install imap; \
        docker-php-ext-enable imap; \
    else \
        docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
        docker-php-ext-install imap; \
    fi; \
    if dpkg --compare-versions "$PHP_VERSION" ge "8.5"; then \
        docker-php-ext-enable ds imagick; \
    else \
        docker-php-ext-enable opcache ds imagick; \
    fi; \
    docker-php-ext-install \
        exif \
        xsl \
        gd \
        sockets \
        mysqli \
        intl \
        zip

COPY imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

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

# Wine
RUN dpkg --add-architecture i386 \
 && apt update \
 && apt install -y \
    wine32 \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*
 
# Firefox
ARG FIREFOX_VERSION=145.0.2

RUN set -eux; \
    apt-get update; \
    wget "https://ftp.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.deb" -O /tmp/firefox.deb; \
    apt-get install -y /tmp/firefox.deb; \
    rm -f /tmp/firefox.deb; \
    rm -rf /var/lib/apt/lists/*