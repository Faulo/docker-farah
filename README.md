# Docker Image: Farah Server

https://hub.docker.com/repository/docker/faulo/farah

Linux and Windows images provide Apache, PHP, Composer, Git, ImageMagick,
UnZip, 7-Zip, and Firefox. All Linux variants use Debian Trixie Slim and
install the selected PHP minor and its extensions from DEB.SURY.ORG. Linux
runtime packages use the newest versions offered by their configured APT
repositories at build time. Composer remains the current Composer 2 executable
because Trixie's Composer dependencies cannot run on the oldest supported PHP
minors.
Composer's official release and snapshot verification keys are preconfigured.
Windows runtime tools use the newest versions offered by Chocolatey at build
time. Firefox is registered from Chocolatey's newest package and extracted
from that package's checksum-verified installer because the Firefox installer
still hangs in a Windows container.
Build variants support PHP 7.4 and PHP 8.0 through 8.5.
PHP 7.4 through 8.1 no longer receive upstream security updates.
The image includes a minimal Farah CMS application so the server starts without
an application mount; `/slothsoft@farah/phpinfo` exposes its PHP information page.
The Linux Dockerfile supports `linux/amd64` and `linux/arm64`. It does not include
Wine; applications running in the image must provide native Linux executables.
Linux runtime packages are declared in `linux/farah-common.packages` and the
matching `linux/farah-<PHP_VERSION>.packages` manifest.

## Runtime startup

Both variants use the shared .NET 9 launcher: `/farah/farah` on Linux and
`C:/farah/farah.exe` on Windows. Before handing off to Apache, the launcher
reads the case-sensitive `COMPOSER_UPDATE` environment variable. It defaults
to `install` and supports these modes:

- `skip`
- `install`
- `install-dev`
- `lowest`
- `lowest-dev`
- `stable`
- `stable-dev`

Unknown modes and Composer failures produce warnings but do not prevent Apache
from starting. Linux forwards `SERVER_NAME` to `apache2-foreground`. Windows
keeps the container attached to Apache's error log after Composer finishes.

On PHP 8.2 and newer, `FARAH_PAGE_TYPE` selects how sitemap pages without an
explicit stream are serialized. Set it to `xml` for `application/xhtml+xml` or
to `html` for `text/html`. Asset URLs do not inherit this setting. The consuming
application must register its sitemap, typically from its Composer bootstrap via
`Kernel::setCurrentSitemap()`; the image does not provide one.

The launcher is the image's default `CMD`, so supplying a command to
`docker run` overrides startup normally.

## Local build and test

The launcher unit tests require a .NET 9 SDK but do not require Docker:

```text
dotnet test docker-farah.sln --configuration Release
```

Both Dockerfiles use the repository root as build context and require explicit
Docker contexts:

```text
docker --context linux build --pull --platform linux/amd64 --tag tmp/farah:latest --file linux/Dockerfile .
docker --context linux build --pull --platform linux/arm64 --tag tmp/farah:latest --file linux/Dockerfile .
docker --context windows build --pull --tag tmp/farah:latest --file windows/Dockerfile .
```

Only images in the disposable `tmp/` namespace should be used for local builds.
