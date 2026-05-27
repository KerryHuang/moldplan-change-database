using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingDeployViewModel : ObservableObject
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
        _jobOwner = "sa";
    }

    public ObservableCollection<DeployStep> Steps { get; } = new();

    [ObservableProperty] private string _targetDatabaseName;
    [ObservableProperty] private string _jobOwner;
    [ObservableProperty] private bool _schemaExists;
    [ObservableProperty] private int _tableCount;
    [ObservableProperty] private int _viewCount;
    [ObservableProperty] private int _procedureCount;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string? _errorMessage;

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

    [RelayCommand]
    private async Task DeployAllAsync()
    {
        Steps.Clear();
        IsBusy = true;
        try
        {
            var schema = await _deploy.DeploySchemaAsync();
            Steps.Add(schema);
            if (schema.Status != DeployStatus.Success) return;

            var tables = await _deploy.DeployTablesAsync();
            Steps.Add(tables);
            if (tables.Status != DeployStatus.Success) return;

            var views = await _deploy.DeployViewsAsync();
            Steps.Add(views);
            if (views.Status != DeployStatus.Success) return;

            var sp = await _deploy.DeployProceduresAsync();
            Steps.Add(sp);
        }
        finally { IsBusy = false; }
    }

    [RelayCommand]
    private async Task DeployDailyJobAsync()
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DeployJobAsync(5, TargetDatabaseName, JobOwner);
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
            var step = await _deploy.DeployJobAsync(6, TargetDatabaseName, JobOwner);
            Steps.Add(step);
        }
        finally { IsBusy = false; }
    }

    public async Task DropAllAsync(string confirmName)
    {
        IsBusy = true;
        try
        {
            var step = await _deploy.DropAllAsync(confirmName);
            Steps.Add(step);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; }
    }
}
