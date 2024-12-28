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
    imagemagick \
  && pecl install \
    ds \
  && docker-php-ext-install \
    curl \
    xsl \
    zip \
    mbstring \
    gd \
    fileinfo \
    sockets \
    exif \
    intl \
    mysqli \
    dom \
  && docker-php-ext-enable \
    ds \
  && apt upgrade -y

# Farah
COPY --chmod=777 farah /usr/share/farah
CMD ["/usr/share/farah/init.sh"]

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

# Apache
COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY apache.conf /etc/apache2/conf-available/custom.conf
RUN a2enconf custom

ENV SERVER_NAME=localhost
EXPOSE 80

# Cleanup
RUN apt clean && rm -rf /var/lib/apt/lists/*