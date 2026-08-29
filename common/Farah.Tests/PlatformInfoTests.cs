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
    public void PreservesWindowsPowerShellCommand() {
        string[] arguments = ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Get-Content -LiteralPath (Join-Path $env:APPDATA 'Apache24/logs/error.log') -Wait -Tail 10"];
        var platform = new PlatformInfo(@"C:\www", "powershell.exe", arguments, false);

        Assert.That(platform.CreateServerArguments("ignored.example"), Is.EqualTo(arguments));
        Assert.That(platform.forwardTerminationSignals, Is.False);
    }
}