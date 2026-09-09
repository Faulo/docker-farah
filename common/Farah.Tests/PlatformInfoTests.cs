using DockerFarah;
using NUnit.Framework;

namespace Farah.Tests;

public sealed class PlatformInfoTests {
    static readonly string[] linuxServerArguments = ["-DSERVER_NAME=example.test"];

    [Test]
    public void CreatesLinuxApacheCommand() {
        var platform = new PlatformInfo("/var/www", "apache2-foreground", [], true);

        Assert.That(platform.CreateServerArguments("example.test"), Is.EqualTo(linuxServerArguments));
        Assert.That(platform.forwardTerminationSignals, Is.True);
    }

    [Test]
    public void CreatesWindowsApacheCommand() {
        string[] arguments = ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[Environment]::SetEnvironmentVariable('SERVER_NAME', $env:SERVER_NAME, 'Machine'); [Environment]::SetEnvironmentVariable('FARAH_PAGE_TYPE', $env:FARAH_PAGE_TYPE, 'Machine'); Start-Service -Name Apache; Get-Content -LiteralPath (Join-Path $env:APPDATA 'Apache24/logs/error.log') -Wait -Tail 10"];
        var platform = PlatformInfo.CreateWindows();

        Assert.That(platform.CreateServerArguments("ignored.example"), Is.EqualTo(arguments));
        Assert.That(platform.forwardTerminationSignals, Is.False);
        Assert.That(platform.serverExecutable, Is.EqualTo("powershell.exe"));
    }
}
