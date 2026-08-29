using NUnit.Framework;

public sealed class ComposerSetupTests {
    [TestCase(null)]
    [TestCase("")]
    public void DefaultsToInstall(string? configuredMode) {
        var plan = ComposerSetup.Resolve(configuredMode);

        Assert.That(plan.arguments, Is.EqualTo(new[] { "install", "--no-interaction", "--no-dev", "--optimize-autoloader", "--classmap-authoritative" }));
        Assert.That(plan.message, Is.Null);
    }

    [TestCase("install", new[] { "install", "--no-interaction", "--no-dev", "--optimize-autoloader", "--classmap-authoritative" })]
    [TestCase("install-dev", new[] { "install", "--no-interaction" })]
    [TestCase("lowest", new[] { "update", "--no-interaction", "--prefer-lowest", "--no-dev", "--optimize-autoloader", "--classmap-authoritative" })]
    [TestCase("lowest-dev", new[] { "update", "--no-interaction", "--prefer-lowest" })]
    [TestCase("stable", new[] { "update", "--no-interaction", "--prefer-stable", "--no-dev", "--optimize-autoloader", "--classmap-authoritative" })]
    [TestCase("stable-dev", new[] { "update", "--no-interaction", "--prefer-stable" })]
    public void ResolvesKnownMode(string configuredMode, string[] expectedArguments) {
        var plan = ComposerSetup.Resolve(configuredMode);

        Assert.That(plan.arguments, Is.EqualTo(expectedArguments));
        Assert.That(plan.message, Is.Null);
    }

    [Test]
    public void SkipsComposer() {
        var plan = ComposerSetup.Resolve("skip");

        Assert.That(plan.arguments, Is.Null);
        Assert.That(plan.message, Is.EqualTo("Skipping composer update step."));
        Assert.That(plan.warning, Is.False);
    }

    [Test]
    public void MatchesModesCaseSensitively() {
        var plan = ComposerSetup.Resolve("INSTALL");

        Assert.That(plan.arguments, Is.Null);
        Assert.That(plan.message, Does.StartWith("Unknown COMPOSER_UPDATE mode"));
        Assert.That(plan.warning, Is.True);
    }
}