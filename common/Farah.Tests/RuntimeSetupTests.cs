using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using DockerFarah;
using NUnit.Framework;

namespace Farah.Tests;

public sealed class RuntimeSetupTests {
    static readonly string[] apacheExecutables = ["apache2-foreground"];
    static readonly string[] composerAndApacheExecutables = ["composer", "apache2-foreground"];
    static readonly string[] serverArguments = ["-DSERVER_NAME=example.test"];
    static readonly string[] stableComposerArguments = ["update", "--no-interaction", "--prefer-stable"];

    [Test]
    public void RunsComposerBeforeServer() {
        var runner = new FakeProcessRunner();
        var setup = CreateSetup(runner, out _, out _);

        int exitCode = setup.Run("stable-dev", "example.test");

        Assert.That(exitCode, Is.Zero);
        Assert.That(runner.calls.Select(call => call.executable), Is.EqualTo(composerAndApacheExecutables));
        Assert.That(runner.calls[0].arguments, Is.EqualTo(stableComposerArguments));
        Assert.That(runner.calls[0].workingDirectory, Is.EqualTo("/var/www"));
        Assert.That(runner.calls[0].forwardTerminationSignals, Is.False);
        Assert.That(runner.calls[1].arguments, Is.EqualTo(serverArguments));
        Assert.That(runner.calls[1].workingDirectory, Is.EqualTo("/var/www"));
        Assert.That(runner.calls[1].forwardTerminationSignals, Is.True);
    }

    [Test]
    public void UnknownModeWarnsAndContinuesWithServer() {
        var runner = new FakeProcessRunner();
        var setup = CreateSetup(runner, out _, out var error);

        setup.Run("INSTALL", "localhost");

        Assert.That(runner.calls.Select(call => call.executable), Is.EqualTo(apacheExecutables));
        Assert.That(error.ToString(), Does.Contain("Unknown COMPOSER_UPDATE mode: 'INSTALL'"));
    }

    [Test]
    public void ComposerExitFailureWarnsAndContinuesWithServer() {
        var runner = new FakeProcessRunner(7, 0);
        var setup = CreateSetup(runner, out _, out var error);

        int exitCode = setup.Run("install", "localhost");

        Assert.That(exitCode, Is.Zero);
        Assert.That(runner.calls.Select(call => call.executable), Is.EqualTo(composerAndApacheExecutables));
        Assert.That(error.ToString(), Does.Contain("Composer exited with code 7; continuing startup."));
    }

    [Test]
    public void ComposerStartFailureWarnsAndContinuesWithServer() {
        var runner = new FakeProcessRunner(new InvalidOperationException("missing composer"));
        var setup = CreateSetup(runner, out _, out var error);

        int exitCode = setup.Run("install", "localhost");

        Assert.That(exitCode, Is.Zero);
        Assert.That(runner.calls.Select(call => call.executable), Is.EqualTo(composerAndApacheExecutables));
        Assert.That(error.ToString(), Does.Contain("Composer failed: missing composer; continuing startup."));
    }

    [Test]
    public void SkipLogsMessageAndContinuesWithServer() {
        var runner = new FakeProcessRunner();
        var setup = CreateSetup(runner, out var output, out _);

        setup.Run("skip", "localhost");

        Assert.That(runner.calls.Select(call => call.executable), Is.EqualTo(apacheExecutables));
        Assert.That(output.ToString(), Does.Contain("Skipping composer update step."));
    }

    static RuntimeSetup CreateSetup(FakeProcessRunner runner, out StringWriter output, out StringWriter error) {
        output = new StringWriter();
        error = new StringWriter();
        var platform = new PlatformInfo("/var/www", "apache2-foreground", [], true);
        return new RuntimeSetup(platform, runner, output, error);
    }

    sealed record ProcessCall(string executable, string[] arguments, string workingDirectory, bool forwardTerminationSignals);

    sealed class FakeProcessRunner : IProcessRunner {
        readonly Queue<object> results;

        public FakeProcessRunner(params object[] results) => this.results = new Queue<object>(results);

        public List<ProcessCall> calls { get; } = [];

        public int Run(string executable, IEnumerable<string> arguments, string workingDirectory, bool forwardTerminationSignals) {
            calls.Add(new ProcessCall(executable, [.. arguments], workingDirectory, forwardTerminationSignals));
            if (results.Count == 0) {
                return 0;
            }

            object result = results.Dequeue();
            if (result is Exception exception) {
                throw exception;
            }

            return (int)result;
        }
    }
}