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
        string[] arguments = ["-DFOREGROUND", "-DSERVER_NAME=ignored.example"];
        var platform = PlatformInfo.CreateWindows();

        Assert.That(platform.CreateServerArguments("ignored.example"), Is.EqualTo(arguments));
        Assert.That(platform.forwardTerminationSignals, Is.True);
        Assert.That(platform.serverExecutable, Is.EqualTo(@"C:\Users\ContainerAdministrator\AppData\Roaming\Apache24\bin\httpd.exe"));
    }
}
