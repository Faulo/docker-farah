using System;
using NUnit.Framework;

public sealed class PlatformInfoTests {
    [Test]
    public void CreatesLinuxApacheCommand() {
        var platform = new PlatformInfo("/var/www", "apache2-foreground", Array.Empty<string>(), true);

        Assert.That(platform.CreateServerArguments("example.test"), Is.EqualTo(new[] { "-DSERVER_NAME=example.test" }));
        Assert.That(platform.forwardTerminationSignals, Is.True);
    }

    [Test]
    public void PreservesWindowsPowerShellCommand() {
        string[] arguments = { "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Get-Content -LiteralPath (Join-Path $env:APPDATA 'Apache24/logs/error.log') -Wait -Tail 10" };
        var platform = new PlatformInfo(@"C:\www", "powershell.exe", arguments, false);

        Assert.That(platform.CreateServerArguments("ignored.example"), Is.EqualTo(arguments));
        Assert.That(platform.forwardTerminationSignals, Is.False);
    }
}