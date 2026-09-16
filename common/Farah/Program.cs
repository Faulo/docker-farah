using System;

namespace DockerFarah;

static class Program {
    static int Main(string[] arguments) {
        try {
            var setup = new RuntimeSetup(PlatformInfo.current, new ProcessRunner(), Console.Out, Console.Error);
            if (arguments.Length == 0 || arguments is ["serve"]) {
                return setup.Run(Environment.GetEnvironmentVariable("COMPOSER_UPDATE"), Environment.GetEnvironmentVariable("SERVER_NAME"));
            }

            if (arguments is ["health"]) {
                return setup.CheckHealth();
            }

            Console.Error.WriteLine("Usage: farah <serve|health>");
            return 2;
        } catch (Exception exception) {
            Console.Error.WriteLine("docker-farah: " + exception.Message);
            return 1;
        }
    }
}
