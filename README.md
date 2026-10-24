# Farah CMS server for Linux and Windows containers

[![Docker](https://github.com/Faulo/docker-farah/actions/workflows/docker.yml/badge.svg?branch=main)](https://github.com/Faulo/docker-farah/actions/workflows/docker.yml) [![Docker image updated](https://img.shields.io/docker/last-updated/faulo/farah/latest)](https://hub.docker.com/r/faulo/farah/tags?name=latest) [![License: MIT](https://img.shields.io/github/license/Faulo/docker-farah)](LICENSE) [![Platforms: Linux amd64 and arm64, Windows amd64](https://img.shields.io/badge/platforms-Linux%20amd64%20%7C%20arm64%20%7C%20Windows%20amd64-0078D4)](#available-images)

[`faulo/farah`](https://hub.docker.com/r/faulo/farah) runs Farah CMS applications
with Apache, PHP, and Composer on Linux and Windows. Choose a PHP release,
mount your application, and let the included launcher install its Composer
dependencies before starting the web server.

The image includes a minimal Farah application, a built-in HTTP health check,
and tools for image processing, browser automation, and archive handling.

[Docker Hub](https://hub.docker.com/r/faulo/farah) ·
[Image tags](https://hub.docker.com/r/faulo/farah/tags) ·
[Report an issue](https://github.com/Faulo/docker-farah/issues)

## Available images

PHP variants are available for `7.4`, `8.0`, `8.1`, `8.2`, `8.3`, `8.4`,
and `8.5`. The `latest` tag family currently aliases PHP `8.5`.

| Tag, shown for PHP 8.5 | Platform |
| --- | --- |
| `8.5`, `latest` | Linux amd64, Linux arm64, and Windows amd64 |
| `8.5-linux`, `latest-linux` | Linux amd64 and arm64 |
| `8.5-linux-amd64`, `latest-linux-amd64` | Linux amd64 |
| `8.5-linux-arm64`, `latest-linux-arm64` | Linux arm64 |
| `8.5-windows`, `latest-windows` | Windows amd64, Server Core LTSC 2019 |
| `8.5-windows-ltsc2019`, `latest-windows-ltsc2019` | Windows amd64, Server Core LTSC 2019 |

The same versioned tag structure applies to every PHP variant. Use `latest`
for automatic platform selection, a PHP tag to select a release line, or a
platform-specific tag when your deployment needs one. Use an image digest
when a deployment needs a fixed image revision.

Linux variants use Debian Trixie Slim. Windows variants use
`faulo/choco:windowsservercore-ltsc2019` and require a compatible Windows
container engine and isolation mode.

Legacy PHP variants remain available for compatibility. PHP 7.4 through 8.1
no longer receive upstream security updates; consult
[PHP's supported versions](https://www.php.net/supported-versions.php) when
choosing a release.

### PHP2Shell security status

Verified on **2026-10-24** against the images published by
[this build](https://github.com/Faulo/docker-farah/actions/runs/40089886123).
This matrix covers **CVE-2026-109618** and **CVE-2026-109619**, collectively
known as PHP2Shell; see the [PHP security advisory](https://www.php.net/archive/2026.php#2026-10-21-5).
`Included` and `Backport` mean both fixes are present; `Missing` means they
are absent.

| PHP branch | Linux amd64 | Linux arm64 | Windows amd64 (LTSC 2019) |
| --- | --- | --- | --- |
| 7.4 | Backport (`7.4.33-31`) | Backport (`7.4.33-31`) | Missing (`7.4.33`) |
| 8.0 | Backport (`8.0.30-25`) | Backport (`8.0.30-25`) | Missing (`8.0.30`) |
| 8.1 | Backport (`8.1.34-9`) | Missing (`8.1.34-8`) | Missing (`8.1.34`) |
| 8.2 | Included (`8.2.35`) | Missing (`8.2.34`) | Included (`8.2.35`) |
| 8.3 | Included (`8.3.36`) | Missing (`8.3.35`) | Included (`8.3.36`) |
| 8.4 | Included (`8.4.27`) | Included (`8.4.27`) | Included (`8.4.27`) |
| 8.5 | Included (`8.5.12`) | Missing (`8.5.11`) | Included (`8.5.12`) |

Legacy Linux versions above include the Debian package revision; package
epochs and distribution build suffixes are omitted. Sury supplies the
backports, so `php --version` alone cannot identify whether a legacy image
contains these fixes. Linux status was checked against both CLI and Apache
module packages; Windows status was checked against the installed PHP build.

The [upstream legacy backports](https://www.php.net/archive/2026.php#2026-10-21-5)
disable session upload progress and terminate the PHP worker on memory
exhaustion. PHP 7.4 through 8.1 remain end-of-life versions.

## Quick start

Start the bundled application:

```console
docker run --detach --name farah --publish 8080:80 faulo/farah:latest
```

Open [http://localhost:8080/slothsoft@farah/phpinfo](http://localhost:8080/slothsoft@farah/phpinfo)
to view the PHP information page. The bundled application provides this
endpoint without an application mount; a site homepage requires your own
application and sitemap.

Inspect startup output and run the health probe:

```console
docker logs --follow farah
docker exec farah farah health
```

The container listens on HTTP port 80. Its default command is
`farah serve`. Supplying another command replaces server startup completely:

```console
docker run --rm faulo/farah:latest php --version
docker run --rm faulo/farah:latest composer --version
```

## Run your application

Your application directory should contain its `composer.json`, optional
`composer.lock`, and public files under `html/`. Require `slothsoft/farah`
and register your sitemap from your application's Composer bootstrap, typically
with `Kernel::setCurrentSitemap()`. The image does not supply a site sitemap.

For a Linux container engine, save this as `compose.yaml` and place your
application in `./app`:

```yaml
services:
  farah:
    image: faulo/farah:latest-linux
    ports:
      - "8080:80"
    environment:
      SERVER_NAME: localhost
      COMPOSER_UPDATE: install
    volumes:
      - type: bind
        source: ./app
        target: /var/www
```

For a Windows container engine, use this configuration instead:

```yaml
services:
  farah:
    image: faulo/farah:latest-windows
    ports:
      - "8080:80"
    environment:
      SERVER_NAME: localhost
      COMPOSER_UPDATE: install
    volumes:
      - type: bind
        source: ./app
        target: c:/www
```

Start the server:

```console
docker compose up -d
docker compose logs --follow farah
```

The application mount replaces the bundled application. Startup runs Composer
in the application root, so the mount must allow dependency installation unless
you supply an existing `vendor/` directory and set `COMPOSER_UPDATE=skip`.
On Linux, Apache serves requests as `www-data`; give that user read access to
application files and write access to any application-managed data directories.

The [test application](test-files/application) demonstrates Composer bootstrap
and sitemap registration.

### Application paths

| Purpose | Linux | Windows |
| --- | --- | --- |
| Application root and Composer working directory | `/var/www` | `C:/www` |
| Public document root | `/var/www/html` | `C:/www/html` |
| Default Composer autoloader | `/var/www/vendor/autoload.php` | `C:/www/vendor/autoload.php` |

Apache routes requests without a matching public resource through the bundled
Farah front controller. The `/slothsoft@farah/phpinfo` route also provides
the endpoint used by the image's health check.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `SERVER_NAME` | `localhost` | Apache server name |
| `COMPOSER_UPDATE` | `install` | Composer startup mode, listed below |
| `FARAH_AUTOLOAD_FILE` | Platform-specific path above | Autoloader loaded by the Farah front controller |
| `FARAH_PAGE_TYPE` | Unset | Default stream for sitemap pages without an explicit stream, on PHP 8.2 and newer |

Set `FARAH_PAGE_TYPE=xml` for `application/xhtml+xml`, or
`FARAH_PAGE_TYPE=html` for `text/html`. Asset URLs do not inherit this
setting.

### Composer startup modes

`COMPOSER_UPDATE` is case-sensitive. Every Composer invocation uses
`--no-interaction`.

| Mode | Behavior |
| --- | --- |
| `skip` | Start Apache without running Composer |
| `install` | Install locked dependencies without development packages |
| `install-dev` | Install dependencies including development packages |
| `lowest` | Update with `--prefer-lowest`, without development packages |
| `lowest-dev` | Update with `--prefer-lowest`, including development packages |
| `stable` | Update with `--prefer-stable`, without development packages |
| `stable-dev` | Update with `--prefer-stable`, including development packages |

Modes without development packages also use `--optimize-autoloader` and
`--classmap-authoritative`. Unknown modes and Composer failures produce
warnings and allow Apache to start; inspect startup logs when dependencies
are missing. Use `skip` when dependencies are prepared during your own image
build.

### PHP and server defaults

The bundled PHP configuration enables error display and logging, allows up to
1 GiB per upload, and sets a 4 GiB memory limit. Review these settings and access
to the PHP information endpoint for your deployment. Configuration sources are
[`linux/php.ini`](linux/php.ini), [`windows/php.ini`](windows/php.ini),
[`linux/apache.conf`](linux/apache.conf), and
[`windows/apache.conf`](windows/apache.conf).

## Included tools

| Tools | Purpose |
| --- | --- |
| Apache and the selected PHP release | HTTP serving and PHP execution |
| Farah CMS and Composer | Application runtime and dependency management |
| Native `farah` launcher | Server startup and HTTP health probe |
| Git and curl | Source retrieval and HTTP requests |
| ImageMagick | Image processing |
| Firefox | Browser automation; Firefox ESR on Linux |
| UnZip and 7-Zip | Archive handling |
| PowerShell on Windows | Windows automation |

Linux PHP packages include curl, DS, GD, Imagick, IMAP, Intl, Mbstring, MySQL,
XML, and Zip extensions. Exact package and extension declarations are maintained
in [`linux/`](linux) and [`windows/`](windows), including a manifest for
each PHP release. Linux applications must use native Linux executables; Wine
is not included.

## Development and tests

The native launcher and its NUnit tests live in [`common/`](common).
With the .NET 9 SDK installed, run the launcher tests without Docker:

```console
dotnet test docker-farah.sln --configuration Release --logger junit
```

The Pester integration tests in [`tests/`](tests) cover installed tools,
PHP versions and extensions, Composer, Firefox, server startup, command
overrides, HTTP responses, page media types, and the health probe.

Both Dockerfiles use the repository root as their build context.
`PHP_VERSION` defaults to `8.2` in local builds; pass it explicitly to
match a published PHP variant. Build with a container engine matching the
selected platform:

```console
docker build --build-arg PHP_VERSION=8.5 --tag tmp/farah:latest --file linux/Dockerfile .
```

```console
docker build --build-arg PHP_VERSION=8.5 --tag tmp/farah:latest --file windows/Dockerfile .
```

Images are rebuilt on a monthly schedule and when changes are published.
The shared [Docker publication workflow](https://github.com/Faulo/workflows-docker)
reads [`docker.json`](docker.json) for PHP variants, native builds, public tags,
and Docker Hub metadata.

## Support and contributions

Report bugs and feature requests through
[GitHub issues](https://github.com/Faulo/docker-farah/issues). Include the image
tag or digest, PHP version, container OS and architecture, Docker version, and
a minimal reproduction with credentials removed. For Windows issues, include
the isolation mode where relevant.

Contributions are welcome. Add tests for behavior changes, keep shared launcher
code in `common/`, and maintain platform packaging in `linux/` or `windows/`.

## License

The repository's code and documentation are licensed under the
[MIT License](LICENSE). Bundled applications, libraries, and tools retain their
respective licenses.
