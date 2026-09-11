ARG PHP_VERSION=8.2

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0-bookworm-slim AS build

ARG TARGETARCH

WORKDIR /solution

COPY . .

RUN case "$TARGETARCH" in \
        amd64) runtimeArchitecture=x64 ;; \
        arm64) runtimeArchitecture=arm64 ;; \
        *) echo "Unsupported Linux architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && dotnet publish docker-farah.sln \
        --configuration Release \
        --runtime "linux-${runtimeArchitecture}" \
        --self-contained true \
        --property:PublishSingleFile=true \
        --property:UseAppHost=true \
        --property:DebugType=None

FROM debian:trixie-slim

ARG PHP_VERSION
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=${PHP_VERSION}
WORKDIR /var/www

# Package sources
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ADD https://packages.sury.org/debsuryorg-archive-keyring.deb /tmp/debsuryorg-archive-keyring.deb

RUN dpkg -i /tmp/debsuryorg-archive-keyring.deb \
 && echo 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ trixie main' \
      > /etc/apt/sources.list.d/php.list \
 && rm -f /tmp/debsuryorg-archive-keyring.deb

# Runtime tools
COPY linux/farah-common.packages /tmp/farah-common.packages

RUN apt-get update \
 && xargs apt-get install -y --no-install-recommends < /tmp/farah-common.packages \
 && rm -f /tmp/farah-common.packages \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY linux/farah-${PHP_VERSION}.packages /tmp/farah.packages

RUN apt-get update \
 && xargs apt-get install -y --no-install-recommends < /tmp/farah.packages \
 && rm -f /tmp/farah.packages \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY linux/imagemagick-policy.xml /etc/ImageMagick-7/policy.xml

# Farah
COPY --from=build --chmod=755 /solution/common/Farah/bin/Release/net9.0/linux-*/publish/farah /farah/farah
COPY --chmod=777 linux/farah/index.php /farah/index.php
RUN git config --global --add safe.directory '*'
ENV FARAH_AUTOLOAD_FILE="/var/www/vendor/autoload.php"
CMD ["/farah/farah"]

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

# Default application
RUN composer require slothsoft/farah --no-interaction --prefer-dist --optimize-autoloader \
 && composer config license proprietary \
 && install -d -o www-data -g www-data /var/www/html \
 && rm -f /var/www/html/index.html \
 && test -f /var/www/vendor/autoload.php \
 && test "$(php -r 'echo PHP_MAJOR_VERSION, ".", PHP_MINOR_VERSION;')" = "$PHP_VERSION" \
 && ! dpkg-query --show --showformat='${binary:Package}\t${db:Status-Abbrev}\n' 'php[0-9]*' 2> /dev/null \
        | awk '$2 == "ii" { print $1 }' \
        | grep -Ev "^php${PHP_VERSION}(-|$)" \
 && composer --version \
 && firefox --version \
 && git --version \
 && 7z --help > /dev/null \
 && unzip -v > /dev/null \
 && chown -R www-data:www-data /var/www

# Apache
ENV SERVER_NAME=localhost
EXPOSE 80
COPY linux/php.ini /etc/php/${PHP_VERSION}/apache2/conf.d/99-farah.ini
COPY linux/apache.conf /etc/apache2/conf-available/custom.conf
COPY --chmod=755 linux/apache2-foreground /usr/local/bin/apache2-foreground
RUN a2enconf custom \
 && php -v \
 && php -m \
 && php --ri imap \
 && php --ri imagick \
 && php -m | grep -Fx 'Zend OPcache' \
 && openssl version | grep -E '^OpenSSL 3\.' \
 && curl --version | grep -E 'OpenSSL/3\.'
