using System;

static class Program {
    static int Main() {
        try {
            var setup = new RuntimeSetup(PlatformInfo.current, new ProcessRunner(), Console.Out, Console.Error);
            return setup.Run(Environment.GetEnvironmentVariable("COMPOSER_UPDATE"), Environment.GetEnvironmentVariable("SERVER_NAME"));
        } catch (Exception exception) {
            Console.Error.WriteLine("docker-farah: " + exception.Message);
            return 1;
        }
    }
}
