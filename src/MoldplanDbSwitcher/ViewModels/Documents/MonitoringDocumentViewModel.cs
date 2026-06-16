using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels.Documents;

public partial class MonitoringDocumentViewModel : DocumentViewModel
{
    public const string DailyJobName = "Reporting_DailyRefresh_MoldPlan";
    public const string HourlyJobName = "Reporting_HourlyRefresh_MoldPlan";

    private readonly Func<string, IJobMonitorService> _monitorFactory;
    private IJobMonitorService _monitor;

    public MonitoringDocumentViewModel(Func<string, IJobMonitorService> monitorFactory, string initialConnectionString)
    {
        _monitorFactory = monitorFactory;
        _monitor = monitorFactory(initialConnectionString);
        Title = "Reporting 監控";
    }

    public override string DocumentType => "ReportingMonitor";

    public ObservableCollection<AgentJobStatus> Jobs { get; } = new();
    public ObservableCollection<RefreshLogEntry> RefreshLog { get; } = new();

    [ObservableProperty] private MonitorSummary _summary = new(0, 0, 0, 0);
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;
    [ObservableProperty] private bool _autoRefreshEnabled = true;
    [ObservableProperty] private int _refreshIntervalSeconds = 30;

    public override async Task UseConnectionAsync(ActiveConnection connection)
    {
        _monitor = _monitorFactory(connection.ConnectionString);
        await RefreshAsync();
    }

    [RelayCommand]
    private async Task RefreshAsync()
    {
        try
        {
            IsBusy = true; ErrorMessage = null;
            var jobs = await _monitor.ListJobsAsync();
            Jobs.Clear();
            foreach (var j in jobs) Jobs.Add(j);
            Summary = MonitorSummary.FromJobs(jobs);

            var log = await _monitor.GetRefreshLogAsync();
            RefreshLog.Clear();
            foreach (var e in log) RefreshLog.Add(e);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private Task TriggerDailyJobAsync() => TriggerAsync(DailyJobName);

    [RelayCommand]
    private Task TriggerHourlyJobAsync() => TriggerAsync(HourlyJobName);

    private async Task TriggerAsync(string jobName)
    {
        try
        {
            IsBusy = true; ErrorMessage = null;
            await _monitor.TriggerJobAsync(jobName);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
