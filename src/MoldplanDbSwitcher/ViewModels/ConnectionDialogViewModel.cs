using System;
using System.Collections.Generic;
using CommunityToolkit.Mvvm.ComponentModel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ConnectionDialogViewModel : ObservableObject
{
    [ObservableProperty]
    private string _name = string.Empty;

    [ObservableProperty]
    private string _server = string.Empty;

    [ObservableProperty]
    private string _database = string.Empty;

    [ObservableProperty]
    private string _dialogTitle = "新增自訂連線";

    [ObservableProperty]
    private DatabaseEnvironment _environment = DatabaseEnvironment.Staging;

    public static IReadOnlyList<DatabaseEnvironment> EnvironmentOptions { get; } =
        Enum.GetValues<DatabaseEnvironment>();

    public bool IsValid => !string.IsNullOrWhiteSpace(Name)
                        && !string.IsNullOrWhiteSpace(Server)
                        && !string.IsNullOrWhiteSpace(Database);
}
