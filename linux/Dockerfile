ARG PHP_VERSION=7.4
ARG DEBIAN=bullseye
FROM php:${PHP_VERSION}-apache-${DEBIAN}
ARG PHP_VERSION
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# Runtime dependencies
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    imagemagick \
    unzip \
 && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        libc-client-dev \
        libicu-dev \
        libkrb5-dev \
        libmagickwand-dev \
        libpng-dev \
        libxslt1-dev \
        libzip-dev; \
    pecl channel-update pecl.php.net; \
    if dpkg --compare-versions "$PHP_VERSION" ge "8.2"; then \
        pecl install ds; \
        docker-php-ext-enable ds; \
    fi; \
    if dpkg --compare-versions "$PHP_VERSION" ge "8.4"; then \
        pecl install imap; \
        docker-php-ext-enable imap; \
    else \
        docker-php-ext-configure imap --with-kerberos --with-imap-ssl; \
        docker-php-ext-install imap; \
    fi; \
    pecl install imagick; \
    if dpkg --compare-versions "$PHP_VERSION" ge "8.5"; then \
        docker-php-ext-enable imagick; \
    else \
        docker-php-ext-enable imagick opcache; \
    fi; \
    docker-php-ext-install \
        exif \
        xsl \
        gd \
        sockets \
        mysqli \
        intl \
        zip; \
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -rt dpkg-query --search \
        | awk 'sub(":$", "", $1) { print $1 }' \
        | sort -u \
        | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /tmp/pear /var/lib/apt/lists/*

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
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    wine \
    wine32 \
 && rm -rf /var/lib/apt/lists/*

# Firefox
ARG FIREFOX_VERSION=145.0.2
ARG FIREFOX_SHA256=b35e92aec8cbcf627fa3dcf4e865b0de977cc66e1a3593d91b6e5ae945d1f0b9

RUN set -eux; \
    curl --fail --location --retry 3 \
        "https://ftp.mozilla.org/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.deb" \
        --output /tmp/firefox.deb; \
    echo "${FIREFOX_SHA256}  /tmp/firefox.deb" | sha256sum -c -; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /tmp/firefox.deb; \
    rm -f /tmp/firefox.deb; \
    rm -rf /var/lib/apt/lists/*
