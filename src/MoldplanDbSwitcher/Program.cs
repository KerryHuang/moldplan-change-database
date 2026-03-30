using Avalonia;
using Microsoft.Extensions.DependencyInjection;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher;

class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        var services = new ServiceCollection();
        ConfigureServices(services);
        App.Services = services.BuildServiceProvider();

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<ISettingsService, SettingsService>();
        services.AddSingleton<IConnectionSourceService, ConnectionSourceService>();
        services.AddSingleton<IServerTxtService, ServerTxtService>();
        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddSingleton<IFeatureQueryService, FeatureQueryService>();
        services.AddSingleton<IFeatureReportService, FeatureReportService>();
        services.AddSingleton<IUsageQueryService, UsageQueryService>();
        services.AddSingleton<IUsageReportService, UsageReportService>();
        services.AddSingleton<IConnectionExportService, ConnectionExportService>();
        services.AddTransient<MainWindowViewModel>();
    }

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
