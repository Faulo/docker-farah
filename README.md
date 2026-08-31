# Docker Image: Farah Server

https://hub.docker.com/repository/docker/faulo/farah

Linux and Windows images provide Apache, PHP, Composer, Git, ImageMagick,
UnZip, 7-Zip, and Firefox 145.0.2. PHP 7.4 and 8.0 use Debian Bullseye and
OpenSSL 1.1.1; newer variants use Debian Bookworm and OpenSSL 3.
Composer's official release and snapshot verification keys are preconfigured.
Build variants support PHP 7.4 and PHP 8.0 through 8.5.
The image includes a minimal Farah CMS application so the server starts without
an application mount; `/slothsoft@farah/phpinfo` exposes its PHP information page.
The Linux Dockerfile supports `linux/amd64` and `linux/arm64`. It does not include
Wine; applications running in the image must provide native Linux executables.

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
