using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace SecurityKeyLocker
{
    /// <summary>
    /// Entry point. Uses the .NET generic host with the Windows Service
    /// lifetime. When launched from a console it simply runs interactively,
    /// which makes debugging easy; when started by the SCM it behaves as a
    /// Windows Service.
    /// </summary>
    internal static class Program
    {
        private static void Main(string[] args)
        {
            HostApplicationBuilder builder = Host.CreateApplicationBuilder(args);

            builder.Services.AddWindowsService(options =>
            {
                options.ServiceName = "SecurityKeyLocker";
            });

            builder.Services.AddHostedService<LockerWorker>();

            builder.Build().Run();
        }
    }
}
