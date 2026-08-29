using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;

interface IProcessRunner {
    int Run(string executable, IEnumerable<string> arguments, string workingDirectory, bool forwardTerminationSignals);
}

sealed class ProcessRunner : IProcessRunner {
    public int Run(string executable, IEnumerable<string> arguments, string workingDirectory, bool forwardTerminationSignals) {
        using var process = Process.Start(CreateStartInfo(executable, arguments, workingDirectory)) ?? throw new InvalidOperationException("failed to start " + executable);
        using var signals = forwardTerminationSignals ? new SignalForwarder(process) : null;

        process.WaitForExit();
        return process.ExitCode;
    }

    internal static ProcessStartInfo CreateStartInfo(string executable, IEnumerable<string> arguments, string workingDirectory) {
        var start = new ProcessStartInfo { FileName = executable, UseShellExecute = false, WorkingDirectory = workingDirectory };
        foreach (string argument in arguments) {
            start.ArgumentList.Add(argument);
        }

        return start;
    }

    sealed class SignalForwarder : IDisposable {
        readonly PosixSignalRegistration interrupt;
        readonly Process process;
        readonly PosixSignalRegistration quit;
        readonly PosixSignalRegistration terminate;

        public SignalForwarder(Process process) {
            this.process = process;
            interrupt = PosixSignalRegistration.Create(PosixSignal.SIGINT, context => Forward(context, 2));
            quit = PosixSignalRegistration.Create(PosixSignal.SIGQUIT, context => Forward(context, 3));
            terminate = PosixSignalRegistration.Create(PosixSignal.SIGTERM, context => Forward(context, 15));
        }

        public void Dispose() {
            interrupt.Dispose();
            quit.Dispose();
            terminate.Dispose();
        }

        void Forward(PosixSignalContext context, int signal) {
            context.Cancel = true;
            try {
                if (!process.HasExited) {
                    NativeMethods.Kill(process.Id, signal);
                }
            } catch (InvalidOperationException) {
                // The child exited between the signal and the status check.
            }
        }
    }

    static class NativeMethods {
        [DllImport("libc", EntryPoint = "kill", SetLastError = true)]
        internal static extern int Kill(int processId, int signal);
    }
}