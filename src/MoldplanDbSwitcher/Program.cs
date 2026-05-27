using System.Linq;
using Avalonia;
using Microsoft.Extensions.DependencyInjection;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
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
        services.AddSingleton<IAppSettingsService, AppSettingsService>();
        services.AddSingleton<IUpdateCheckService>(_ => new UpdateCheckService());
        services.AddSingleton<IConnectionSourceService, ConnectionSourceService>();
        services.AddSingleton<IServerTxtService, ServerTxtService>();
        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddSingleton<IFeatureQueryService, FeatureQueryService>();
        services.AddSingleton<IFeatureReportService, FeatureReportService>();
        services.AddSingleton<IUsageQueryService, UsageQueryService>();
        services.AddSingleton<IUsageReportService, UsageReportService>();
        services.AddSingleton<IConnectionExportService, ConnectionExportService>();
        services.AddSingleton<IAnsibleSyncService, AnsibleSyncService>();
        services.AddSingleton<IAppSettingsDevService, AppSettingsDevService>();

        services.AddSingleton<IReportingScriptProvider>(sp =>
            new ReportingScriptProvider(sp.GetRequiredService<IAppSettingsService>().GetMoldPlanScriptsPath()));
        services.AddSingleton<ISqlBatchExecutor, SqlBatchExecutor>();

        services.AddTransient<Func<string, IReportingObjectService>>(_ => connStr => new ReportingObjectService(connStr));
        services.AddTransient<Func<string, IReportingQueryService>>(_ => connStr => new ReportingQueryService(connStr));
        services.AddTransient<Func<string, IReportingDeployService>>(sp => connStr =>
            new ReportingDeployService(connStr,
                sp.GetRequiredService<IReportingScriptProvider>(),
                sp.GetRequiredService<ISqlBatchExecutor>()));

        services.AddSingleton<ReportingQueryViewModel>(sp =>
        {
            var factory = sp.GetRequiredService<ISqlConnectionFactory>();
            var settings = sp.GetRequiredService<ISettingsService>();
            var profile = settings.LoadProfiles().FirstOrDefault();
            var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
            return new ReportingQueryViewModel(
                sp.GetRequiredService<Func<string, IReportingObjectService>>(),
                sp.GetRequiredService<Func<string, IReportingQueryService>>(),
                connStr);
        });

        services.AddSingleton<ReportingDeployViewModel>(sp =>
        {
            var factory = sp.GetRequiredService<ISqlConnectionFactory>();
            var settings = sp.GetRequiredService<ISettingsService>();
            var profile = settings.LoadProfiles().FirstOrDefault();
            var connStr = profile != null ? factory.Create(profile).ConnectionString : "";
            return new ReportingDeployViewModel(
                sp.GetRequiredService<Func<string, IReportingObjectService>>(),
                sp.GetRequiredService<Func<string, IReportingDeployService>>(),
                connStr,
                profile?.Database ?? "");
        });

        services.AddTransient<MainWindowViewModel>();
    }

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
