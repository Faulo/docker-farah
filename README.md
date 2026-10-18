# Docker Image: Farah Server

https://hub.docker.com/repository/docker/faulo/farah

Linux and Windows images provide Apache, PHP, Composer, Git, ImageMagick,
UnZip, 7-Zip, and Firefox. All Linux variants use Debian Trixie Slim and
install the selected PHP minor and its extensions from DEB.SURY.ORG. Linux
runtime packages use the newest versions offered by their configured APT
repositories at build time. Composer is declared in `farah-common.packages`
and installed through APT together with the selected PHP manifest.
PHP 7.4 uses Bullseye's archived Composer dependency stack, PHP 8.0 uses
Bookworm's stack, and PHP 8.1 and newer use Trixie's stack. These repository
preferences apply only to Composer and its PHP libraries; the Linux base and
native runtime packages remain Trixie, with PHP and its extensions from Sury.
The Windows runtime derives from `faulo/choco:windowsservercore-ltsc2019`.
One `choco-install` invocation installs the common and PHP-specific nuspecs
together with dependency planning and per-package retries, selecting the newest
compatible Chocolatey packages at build time. The base supplies Chocolatey, Visual C++
runtimes, and shared shell and installer compatibility fixes. Firefox uses its
normal Chocolatey installer and lives in `C:/Program Files/Mozilla Firefox`.
Composer belongs to `farah-common.nuspec`; the PHP-specific nuspecs declare
only their PHP dependency. Chocolatey installs Composer once. The Dockerfile
adds an executable shim for the installed
Composer command so it also works with direct `docker exec` and the launcher.
The self-contained .NET 9 launcher does not require .NET Framework 4.8; the
separate Nano Server SDK build stage remains unchanged.

Report native installer stalls or regressions to
[docker-choco](https://github.com/Faulo/docker-choco/issues), linking the report
from the downstream migration. Include the package ID/version, base tag/digest,
host Windows build and isolation, exact command/nuspec, relevant complete logs,
exit code or timeout, and a fresh-container reproduction without credentials.
Keep the affected migration blocked until the shared fix is validated; installer
extraction, skipped package scripts, fabricated records, and downstream
compatibility patches must not replace a failing normal installation.
Build variants support PHP 7.4 and PHP 8.0 through 8.5.
PHP 7.4 through 8.1 no longer receive upstream security updates.
The image includes a minimal Farah CMS application so the server starts without
an application mount; `/slothsoft@farah/phpinfo` exposes its PHP information page.
The Linux Dockerfile supports `linux/amd64` and `linux/arm64`. It does not include
Wine; applications running in the image must provide native Linux executables.
Linux runtime packages are declared in `linux/farah-common.packages` and the
matching `linux/farah-<PHP_VERSION>.packages` manifest.

## Published tags

`docker.json` configures `Faulo/workflows-docker@v3` using schema version 3.
The tracked `.env` supplies the publication namespace and image, independently
of the Docker Hub login. Seven PHP releases produce 21 native builds across
Linux amd64, Linux arm64, and Windows amd64 on Server Core LTSC 2019.
Every release publishes these tags (shown for PHP 8.5):

| Tag | Selected images |
| --- | --- |
| `8.5`, `latest` | All three platforms |
| `8.5-linux`, `latest-linux` | Linux amd64 and arm64 |
| `8.5-linux-amd64`, `latest-linux-amd64` | Linux amd64 |
| `8.5-linux-arm64`, `latest-linux-arm64` | Linux arm64 |
| `8.5-windows`, `latest-windows` | Windows amd64, Server Core LTSC 2019 |
| `8.5-windows-ltsc2019`, `latest-windows-ltsc2019` | Windows amd64, Server Core LTSC 2019 |

The same versioned tag structure applies to PHP 7.4 and 8.0 through 8.4.
For example, use `FROM faulo/farah:8.5-linux` or
`FROM faulo/farah:8.5-windows-ltsc2019` in a dependent Dockerfile.
Each prefix index includes its descendant images and associated attestations;
`latest` aliases have the same index digests as their `8.5` counterparts.
Windows indices retain OS-version metadata. The public `windows` series uses
Server Core; it does not include full Windows images or LTSC 2022.

GitHub owns image builds, caching, publication, manifest verification, and
run-specific staging-tag cleanup. Its Docker Hub token needs publication and
staging-tag deletion permissions. Historical tags remain untouched. Project
unit and integration tests run in Jenkins.

## Runtime startup

Both variants use the shared .NET 9 launcher: `/farah/farah` on Linux and
`C:/farah/farah.exe` on Windows. It is available as `farah` on `PATH`.
`farah serve` performs the normal startup. Before handing off to Apache, it
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

The image deliberately has no `ENTRYPOINT`. Its complete default command is
`["farah", "serve"]`, so supplying a command to `docker run` replaces Farah
startup completely. This guarantees compatibility with an unmodified Jenkins
Docker Pipeline `inside {}` block, whose `cat` or `cmd.exe` keeper command must
run directly. Use `farah serve` when explicitly overriding the image command.

The image healthcheck runs `farah health`, which probes the bundled Farah PHP
information endpoint without running Composer or changing server state.

## Local build and test

The launcher unit tests require a .NET 9 SDK but do not require Docker:

```text
dotnet test docker-farah.sln --configuration Release --logger junit
```

Release candidates use only the latest PHP variant and remain local to the
Linux daemon on Garl and the Windows daemon on Popo. Both Dockerfiles use the
repository root as their build context:

```text
docker --context garl build --pull --build-arg PHP_VERSION=8.5 --tag tmp/farah:latest --file linux/Dockerfile .
docker --context popo build --pull --build-arg PHP_VERSION=8.5 --tag tmp/farah:latest --file windows/Dockerfile .
pwsh ./.jenkins/Invoke-IntegrationTests.ps1 -Namespace tmp -Context garl
pwsh ./.jenkins/Invoke-IntegrationTests.ps1 -Namespace tmp -Context popo
```

Do not push or pull `tmp` images. To test the published `latest` image instead,
pull it on each daemon before running the suite:

```text
pwsh ./.jenkins/Invoke-IntegrationTests.ps1 -Pull -Context garl
pwsh ./.jenkins/Invoke-IntegrationTests.ps1 -Pull -Context popo
```

The integration runner installs missing PowerShell modules declared in
`.jenkins/RequiredModules.psd1`, then reads `DOCKER_NAMESPACE` and
`DOCKER_IMAGE` defaults from `.env`. It also adds `DOCKER_ARGS_LINUX` or
`DOCKER_ARGS_WINDOWS` to every `docker run` call according to the target
daemon's operating system. The published `latest` tag is the same PHP 8.5
variant as the published `8.5` tag. Jenkins tests every configured published
variant; local release-candidate testing intentionally covers only
`tmp/farah:latest`.

Rider exposes four shared run configurations under **Integration Tests** for
running the Garl or Popo suite against either the local `tmp` image or the
published production image. Production configurations pull the image before
testing it.

Only images in the disposable `tmp/` namespace should be used for local builds.

Jenkins runs `dotnet test --logger junit` in the .NET 9 SDK container on a
Linux agent and publishes `**/TestResults.xml` with its native `junit` step.
Each test project writes its report to `TestResults/TestResults.xml`.
Image integration tests continue to use the targets and variants configured
in `.jenkins/pesterProject.properties`.
