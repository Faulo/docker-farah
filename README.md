# Docker Image: Farah Server

https://hub.docker.com/repository/docker/faulo/farah

Linux and Windows images provide Apache, PHP, Composer, Git, ImageMagick,
UnZip, 7-Zip, and Firefox 145.0.2. PHP and its curl extension use OpenSSL 3.
Composer's official release and snapshot verification keys are preconfigured.
Published tags support PHP 8.2 through 8.5.

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
docker --context linux build --pull --tag tmp/farah:latest --file linux/Dockerfile .
docker --context windows build --pull --tag tmp/farah:latest --file windows/Dockerfile .
```

Only images in the disposable `tmp/` namespace should be used for local builds.
