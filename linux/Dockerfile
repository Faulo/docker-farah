ARG PHP_VERSION=8.2
ARG DEBIAN=bookworm

FROM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS farah-build

WORKDIR /source

COPY common/Farah/ .

RUN dotnet publish Farah.csproj \
        --configuration Release \
        --runtime linux-x64 \
        --self-contained true \
        --property:PublishSingleFile=true \
        --output /out

FROM php:${PHP_VERSION}-apache-${DEBIAN}
ARG PHP_VERSION
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# Runtime dependencies
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    imagemagick \
    p7zip-full \
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
    find /usr/local -type f \( -executable -o -name '*.so' \) -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u \
        | xargs -rt dpkg-query --search \
        | awk 'sub(":$", "", $1) { print $1 }' \
        | sort -u \
        | xargs -r apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /tmp/pear /var/lib/apt/lists/*

COPY linux/imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

# Farah
COPY --from=farah-build --chmod=755 /out/farah /usr/share/farah/farah.exe
COPY --chmod=777 linux/farah/index.php /usr/share/farah/index.php
RUN git config --global --add safe.directory *
CMD ["/usr/share/farah/farah.exe"]

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ARG COMPOSER_DEV_PUB_SHA256=2b2df89fb2581e669b4668b451097d4a03f4dc2d7a06df197554064494a90a31
ARG COMPOSER_TAGS_PUB_SHA256=d8f3e350437bf3b5342dbf046064ebd1f017ebc720955433194360a01cfd074f
RUN set -eux; \
    composerHome="$(composer config --global home)"; \
    curl --fail --location --retry 3 https://composer.github.io/snapshots.pub --output /tmp/keys.dev.pub; \
    curl --fail --location --retry 3 https://composer.github.io/releases.pub --output /tmp/keys.tags.pub; \
    echo "${COMPOSER_DEV_PUB_SHA256}  /tmp/keys.dev.pub" | sha256sum -c -; \
    echo "${COMPOSER_TAGS_PUB_SHA256}  /tmp/keys.tags.pub" | sha256sum -c -; \
    install -d -m 700 "$composerHome"; \
    install -m 600 /tmp/keys.dev.pub "$composerHome/keys.dev.pub"; \
    install -m 600 /tmp/keys.tags.pub "$composerHome/keys.tags.pub"; \
    rm -f /tmp/keys.dev.pub /tmp/keys.tags.pub

# Apache
ENV SERVER_NAME=localhost
EXPOSE 80
COPY linux/php.ini /usr/local/etc/php/conf.d/custom.ini
COPY linux/apache.conf /etc/apache2/conf-available/custom.conf
RUN a2enconf custom
RUN php -v \
 && php -m \
 && php --ri imap \
 && openssl version | grep -E '^OpenSSL 3\.' \
 && curl --version | grep -E 'OpenSSL/3\.'

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
