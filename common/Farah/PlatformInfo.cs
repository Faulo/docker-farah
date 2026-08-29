using System;
using System.Collections.Generic;

namespace DockerFarah;

sealed class PlatformInfo {
    public static readonly PlatformInfo current = OperatingSystem.IsWindows()
        ? new PlatformInfo(
            @"C:\www",
            "powershell.exe",
            ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Get-Content -LiteralPath (Join-Path $env:APPDATA 'Apache24/logs/error.log') -Wait -Tail 10"],
            false)
        : new PlatformInfo("/var/www", "apache2-foreground", [], true);

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
        return !forwardTerminationSignals ? serverArguments : ["-DSERVER_NAME=" + (serverName ?? string.Empty)];
    }
}