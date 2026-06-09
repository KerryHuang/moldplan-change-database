using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public enum ConflictAction { Overwrite, Skip }

public class ImportResult
{
    public int Added { get; init; }
    public int Skipped { get; init; }
    public int Overwritten { get; init; }
}

public partial class ImportPreviewItem : ObservableObject
{
    public ConnectionProfile Profile { get; }
    public bool HasConflict { get; }
    public ConnectionProfile? ExistingProfile { get; }

    [ObservableProperty]
    private ConflictAction _conflictAction = ConflictAction.Skip;

    public ImportPreviewItem(ConnectionProfile profile, bool hasConflict, ConnectionProfile? existingProfile)
    {
        Profile = profile;
        HasConflict = hasConflict;
        ExistingProfile = existingProfile;
    }
}

public partial class ImportConnectionsViewModel : ObservableObject
{
    private readonly IConnectionExportService _exportService;
    private readonly ISettingsService _settingsService;
    private readonly IReadOnlyList<ConnectionProfile> _existingProfiles;
    private byte[] _rawData = [];

    [ObservableProperty]
    private bool _needsPassword;

    [ObservableProperty]
    private string _decryptPassword = string.Empty;

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    public ObservableCollection<ImportPreviewItem> ImportPreviews { get; } = [];

    public ImportConnectionsViewModel(
        IConnectionExportService exportService,
        ISettingsService settingsService,
        IReadOnlyList<ConnectionProfile> existingProfiles)
    {
        _exportService = exportService;
        _settingsService = settingsService;
        _existingProfiles = existingProfiles;
    }

    public void LoadImportData(byte[] data)
    {
        _rawData = data;
        if (_exportService.IsEncryptedFormat(data))
        {
            NeedsPassword = true;
            return;
        }
        var exportData = _exportService.ImportFromJson(data);
        PopulatePreviews(exportData);
    }

    public void DecryptAndLoad()
    {
        try
        {
            var exportData = _exportService.ImportFromEncryptedJson(_rawData, DecryptPassword);
            ErrorMessage = string.Empty;
            NeedsPassword = false;
            PopulatePreviews(exportData);
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
        }
    }

    private void PopulatePreviews(ConnectionExportData exportData)
    {
        ImportPreviews.Clear();
        foreach (var profile in exportData.Profiles)
        {
            var existing = _existingProfiles.FirstOrDefault(
                p => string.Equals(p.Name, profile.Name, StringComparison.OrdinalIgnoreCase));
            ImportPreviews.Add(new ImportPreviewItem(profile, existing is not null, existing));
        }
    }

    [RelayCommand]
    private void OverwriteAll()
    {
        foreach (var item in ImportPreviews.Where(p => p.HasConflict))
            item.ConflictAction = ConflictAction.Overwrite;
    }

    [RelayCommand]
    private void SkipAll()
    {
        foreach (var item in ImportPreviews.Where(p => p.HasConflict))
            item.ConflictAction = ConflictAction.Skip;
    }

    /// <summary>是否有選擇覆蓋且涉及 Production 環境的項目（供匯入前防呆）。</summary>
    public bool HasProductionOverwrite()
        => ImportPreviews.Any(item =>
            item.HasConflict
            && item.ConflictAction == ConflictAction.Overwrite
            && (item.Profile.Environment == DatabaseEnvironment.Production
                || item.ExistingProfile?.Environment == DatabaseEnvironment.Production));

    public ImportResult ExecuteImport()
    {
        var added = 0;
        var skipped = 0;
        var overwritten = 0;

        foreach (var item in ImportPreviews)
        {
            if (item.HasConflict)
            {
                if (item.ConflictAction == ConflictAction.Skip)
                {
                    skipped++;
                    continue;
                }
                item.Profile.Id = item.ExistingProfile!.Id;
                _settingsService.UpdateProfile(item.Profile);
                overwritten++;
            }
            else
            {
                _settingsService.AddProfile(item.Profile);
                added++;
            }
        }

        return new ImportResult { Added = added, Skipped = skipped, Overwritten = overwritten };
    }
}
