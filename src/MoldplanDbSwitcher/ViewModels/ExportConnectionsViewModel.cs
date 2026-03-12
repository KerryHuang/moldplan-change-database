using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ProfileSelectionItem : ObservableObject
{
    public ConnectionProfile Profile { get; }

    [ObservableProperty]
    private bool _isSelected;

    public ProfileSelectionItem(ConnectionProfile profile)
    {
        Profile = profile;
    }
}

public partial class ExportConnectionsViewModel : ObservableObject
{
    private readonly IConnectionExportService _exportService;

    [ObservableProperty]
    private bool _useEncryption;

    [ObservableProperty]
    private bool _includePasswords;

    [ObservableProperty]
    private string _encryptionPassword = string.Empty;

    [ObservableProperty]
    private string _confirmPassword = string.Empty;

    public ObservableCollection<ProfileSelectionItem> ProfileSelections { get; }

    public string DefaultExtension => UseEncryption ? ".tsjson" : ".json";

    public ExportConnectionsViewModel(IReadOnlyList<ConnectionProfile> profiles, IConnectionExportService exportService)
    {
        _exportService = exportService;
        ProfileSelections = new ObservableCollection<ProfileSelectionItem>(
            profiles.Select(p => new ProfileSelectionItem(p)));
    }

    partial void OnUseEncryptionChanged(bool value)
    {
        IncludePasswords = value;
        OnPropertyChanged(nameof(DefaultExtension));
    }

    [RelayCommand]
    private void SelectAll()
    {
        foreach (var item in ProfileSelections)
            item.IsSelected = true;
    }

    [RelayCommand]
    private void DeselectAll()
    {
        foreach (var item in ProfileSelections)
            item.IsSelected = false;
    }

    public byte[] GetExportData()
    {
        var selected = ProfileSelections
            .Where(p => p.IsSelected)
            .Select(p => p.Profile)
            .ToList();

        if (UseEncryption)
            return _exportService.ExportToEncryptedJson(selected, EncryptionPassword, IncludePasswords);

        return _exportService.ExportToJson(selected, IncludePasswords);
    }
}
