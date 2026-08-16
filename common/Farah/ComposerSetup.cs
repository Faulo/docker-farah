using System;
using System.Collections.Generic;

sealed record ComposerPlan(IReadOnlyList<string>? arguments, string? message, bool warning);

static class ComposerSetup {
    public static ComposerPlan Resolve(string? configuredMode) {
        string mode = string.IsNullOrEmpty(configuredMode) ? "install" : configuredMode;

        return mode switch {
            "skip" => new ComposerPlan(null, "Skipping composer update step.", false),
            "install" => Create("install", "--no-dev", "--optimize-autoloader", "--classmap-authoritative"),
            "install-dev" => Create("install"),
            "lowest" => Create("update", "--prefer-lowest", "--no-dev", "--optimize-autoloader", "--classmap-authoritative"),
            "lowest-dev" => Create("update", "--prefer-lowest"),
            "stable" => Create("update", "--prefer-stable", "--no-dev", "--optimize-autoloader", "--classmap-authoritative"),
            "stable-dev" => Create("update", "--prefer-stable"),
            _ => new ComposerPlan(null, "Unknown COMPOSER_UPDATE mode: '" + mode + "'; continuing without Composer.", true)
        };
    }

    static ComposerPlan Create(string command, params string[] options) {
        var arguments = new List<string> { command, "--no-interaction" };
        arguments.AddRange(options);
        return new ComposerPlan(arguments, null, false);
    }
}
