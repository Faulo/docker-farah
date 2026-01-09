ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-apache-bullseye
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
    imap \
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
RUN install -d -m 0755 /etc/apt/keyrings \
 && wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null \
 && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null \
 && apt update \
 && apt install -y \
    firefox=145.0.2~build1 \
 && apt clean \
 && rm -rf /var/lib/apt/lists/*