using System;
using System.Collections.Generic;

namespace DockerFarah;

sealed class PlatformInfo {
    public static readonly PlatformInfo current = OperatingSystem.IsWindows()
        ? CreateWindows()
        : new PlatformInfo("/var/www", "apache2-foreground", [], true);

    public static PlatformInfo CreateWindows() {
        return new PlatformInfo(
            @"C:\www",
            @"C:\Users\ContainerAdministrator\AppData\Roaming\Apache24\bin\httpd.exe",
            ["-DFOREGROUND"],
            true);
    }

    public PlatformInfo(string composerWorkingDirectory, string serverExecutable, IReadOnlyList<string> serverArguments, bool forwardTerminationSignals) {
        this.composerWorkingDirectory = composerWorkingDirectory;
        this.serverExecutable = serverExecutable;
        this.serverArguments = serverArguments;
        this.forwardTerminationSignals = forwardTerminationSignals;
    }

    public string composerWorkingDirectory { get; }

    public bool forwardTerminationSignals { get; }

    public IReadOnlyList<string> serverArguments { get; }

    public string serverExecutable { get; }

    public IReadOnlyList<string> CreateServerArguments(string? serverName) {
        return !forwardTerminationSignals
            ? serverArguments
            : [.. serverArguments, "-DSERVER_NAME=" + (serverName ?? string.Empty)];
    }
}
