using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingDeployViewModel : DocumentViewModel
{
    private readonly Func<string, IReportingObjectService> _objectsFactory;
    private readonly Func<string, IReportingDeployService> _deployFactory;
    private IReportingObjectService _objects;
    private IReportingDeployService _deploy;

    public ReportingDeployViewModel(
        Func<string, IReportingObjectService> objectsFactory,
        Func<string, IReportingDeployService> deployFactory,
        string initialConnectionString,
        string initialDatabaseName)
    {
        _objectsFactory = objectsFactory;
        _deployFactory = deployFactory;
        _objects = objectsFactory(initialConnectionString);
        _deploy = deployFactory(initialConnectionString);
        _targetDatabaseName = initialDatabaseName;
        _sourceDatabaseName = string.Empty;
        _jobOwner = "sa";
        Title = "Reporting 部署";
    }

    public override string DocumentType => "ReportingDeploy";

    public override Task UseConnectionAsync(ActiveConnection connection)
        => UseConnectionAsync(connection.ConnectionString, connection.Database);

    public ObservableCollection<DeployStep> Steps { get; } = new();

    [ObservableProperty] private string _targetDatabaseName;
    [ObservableProperty] private string _sourceDatabaseName;
    [ObservableProperty] private string _jobOwner;
    [ObservableProperty] private bool _schemaExists;
    [ObservableProperty] private int _tableCount;
    [ObservableProperty] private int _viewCount;
    [ObservableProperty] private int _procedureCount;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

    public const int ExpectedTableCount = 14;
    public const int ExpectedViewCount = 13;
    public const int ExpectedProcedureCount = 13;

    public bool IsFullyDeployed =>
        SchemaExists && TableCount >= ExpectedTableCount
                     && ViewCount >= ExpectedViewCount
                     && ProcedureCount >= ExpectedProcedureCount;

    public bool CanDeployAll => !IsBusy && !IsFullyDeployed;
    public bool CanDropAll => !IsBusy && (SchemaExists || TableCount > 0 || ViewCount > 0 || ProcedureCount > 0);

    partial void OnSchemaExistsChanged(bool value) => NotifyDeployStateChanged();
    partial void OnTableCountChanged(int value) => NotifyDeployStateChanged();
    partial void OnViewCountChanged(int value) => NotifyDeployStateChanged();
    partial void OnProcedureCountChanged(int value) => NotifyDeployStateChanged();
    partial void OnIsBusyChanged(bool value) => NotifyDeployStateChanged();

    private void NotifyDeployStateChanged()
    {
        OnPropertyChanged(nameof(IsFullyDeployed));
        OnPropertyChanged(nameof(CanDeployAll));
        OnPropertyChanged(nameof(CanDropAll));
    }

    public async Task UseConnectionAsync(string connectionString, string databaseName)
    {
        _objects = _objectsFactory(connectionString);
        _deploy = _deployFactory(connectionString);
        TargetDatabaseName = databaseName;
        await ScanEnvironmentAsync();
    }

    [RelayCommand]
    private async Task ScanEnvironmentAsync()
    {
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            SchemaExists = await _objects.SchemaExistsAsync();
            TableCount = (await _objects.ListTablesAsync()).Count;
            ViewCount = (await _objects.ListViewsAsync()).Count;
            ProcedureCount = (await _objects.ListProceduresAsync()).Count;
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }

    private ReportingDeployParameters BuildParameters() =>
        new(TargetDatabaseName, SourceDatabaseName, JobOwner);

    [RelayCommand]
    private async Task DeployAllAsync()
    {
        Steps.Clear();
        IsBusy = true;
        try
        {
            var progress = new Progress<DeployStep>(step =>
            {
                // 只在最終狀態（非 Running）才加入清單，或以最新狀態更新
            });
            var steps = await _deploy.DeployAllAsync(BuildParameters(), progress);
            foreach (var step in steps)
                Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployDailyJobAsync()
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DeployJobAsync(6, BuildParameters());
            Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployHourlyJobAsync()
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DeployJobAsync(7, BuildParameters());
            Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    public async Task DropAllAsync(string confirmName)
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DropAllAsync(BuildParameters(), confirmName);
            Steps.Add(step);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
