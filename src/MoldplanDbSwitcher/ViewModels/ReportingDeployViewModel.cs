using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ReportingDeployViewModel : DocumentViewModel
{
    private readonly Func<string, IReportingDeployService> _deployFactory;
    private IReportingDeployService _deploy;

    public ReportingDeployViewModel(
        Func<string, IReportingDeployService> deployFactory,
        string initialConnectionString,
        string initialDatabaseName)
    {
        _deployFactory = deployFactory;
        _deploy = deployFactory(initialConnectionString);
        _sourceDatabaseName = initialDatabaseName;
        _targetDatabaseName = "MoldPlan-Reporting";
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

    /// <summary>檔案儲存對話框回呼，參數為 SQL 內容，回傳儲存路徑（取消時為 null）。</summary>
    public Func<string, Task<string?>>? SaveExportSqlCallback { get; set; }

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
        _deploy = _deployFactory(connectionString);
        SourceDatabaseName = databaseName;
        if (string.IsNullOrWhiteSpace(TargetDatabaseName)) TargetDatabaseName = "MoldPlan-Reporting";
        await ScanEnvironmentAsync();
    }

    [RelayCommand]
    private async Task ScanEnvironmentAsync()
    {
        try
        {
            IsBusy = true;
            ErrorMessage = null;
            var st = await _deploy.ScanInstallStatusAsync();
            SchemaExists = st.SchemaExists;
            TableCount = st.TableCount;
            ViewCount = st.ViewCount;
            ProcedureCount = st.ProcedureCount;
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
            var result = await _deploy.DeployAllAsync(BuildParameters());
            Steps.Clear();
            foreach (var s in result) Steps.Add(s);
        }
        catch (Exception ex) { ErrorMessage = ex.Message; }
        finally { IsBusy = false; await ScanEnvironmentAsync(); }
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

    [RelayCommand]
    private async Task ExportSqlAsync()
    {
        if (SaveExportSqlCallback is null) return;
        var sql = _deploy.GenerateExportSql(BuildParameters());
        await SaveExportSqlCallback(sql);
    }

}
