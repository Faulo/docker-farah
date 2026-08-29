using System;
using System.Collections.Generic;
using System.IO;

namespace DockerFarah;

sealed class RuntimeSetup {
    readonly TextWriter error;
    readonly TextWriter output;
    readonly PlatformInfo platform;
    readonly IProcessRunner processRunner;

    public RuntimeSetup(PlatformInfo platform, IProcessRunner processRunner, TextWriter output, TextWriter error) {
        this.platform = platform;
        this.processRunner = processRunner;
        this.output = output;
        this.error = error;
    }

    public int Run(string? composerUpdate, string? serverName) {
        var plan = ComposerSetup.Resolve(composerUpdate);
        if (plan.message is not null) {
            (plan.warning ? error : output).WriteLine(plan.message);
        }

        if (plan.arguments is not null) {
            RunComposer(plan.arguments);
        }

        return processRunner.Run(
            platform.serverExecutable,
            platform.CreateServerArguments(serverName),
            platform.composerWorkingDirectory,
            platform.forwardTerminationSignals);
    }

    void RunComposer(IEnumerable<string> arguments) {
        try {
            int exitCode = processRunner.Run("composer", arguments, platform.composerWorkingDirectory, false);
            if (exitCode != 0) {
                error.WriteLine("Composer exited with code " + exitCode + "; continuing startup.");
            }
        } catch (Exception exception) {
            error.WriteLine("Composer failed: " + exception.Message + "; continuing startup.");
        }
    }
}