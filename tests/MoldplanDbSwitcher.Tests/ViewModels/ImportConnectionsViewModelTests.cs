using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ImportConnectionsViewModelTests
{
    private readonly IConnectionExportService _exportService;
    private readonly ISettingsService _settingsService;
    private readonly List<ConnectionProfile> _existingProfiles;

    public ImportConnectionsViewModelTests()
    {
        _exportService = Substitute.For<IConnectionExportService>();
        _settingsService = Substitute.For<ISettingsService>();
        _existingProfiles = new List<ConnectionProfile>
        {
            new() { Id = "1", Name = "dev", Server = "127.0.0.1", Database = "mis" }
        };
        _settingsService.LoadProfiles().Returns(_existingProfiles);
    }

    private ImportConnectionsViewModel CreateVm() => new(_exportService, _settingsService, _existingProfiles);

    [Fact]
    public void LoadImportData_PlainText_SetsNeedsPasswordFalse()
    {
        var data = new byte[] { 1, 2, 3 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        Assert.False(vm.NeedsPassword);
        Assert.Single(vm.ImportPreviews);
    }

    [Fact]
    public void LoadImportData_Encrypted_SetsNeedsPasswordTrue()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);
        var vm = CreateVm();
        vm.LoadImportData(data);
        Assert.True(vm.NeedsPassword);
        Assert.Empty(vm.ImportPreviews);
    }

    [Fact]
    public void LoadImportData_ConflictDetection_MatchesByNameIgnoreCase()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "DEV", Server = "new-server", Database = "newdb" },
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        Assert.Equal(2, vm.ImportPreviews.Count);
        Assert.True(vm.ImportPreviews[0].HasConflict);
        Assert.False(vm.ImportPreviews[1].HasConflict);
    }

    [Fact]
    public void DecryptAndLoad_Success_PopulatesPreviews()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);
        _exportService.ImportFromEncryptedJson(data, "pass").Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.DecryptPassword = "pass";
        vm.DecryptAndLoad();
        Assert.False(vm.NeedsPassword);
        Assert.Single(vm.ImportPreviews);
        Assert.Empty(vm.ErrorMessage);
    }

    [Fact]
    public void DecryptAndLoad_WrongPassword_SetsErrorMessage()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);
        _exportService.ImportFromEncryptedJson(data, "wrong")
            .Returns(x => throw new InvalidOperationException("密碼不正確"));
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.DecryptPassword = "wrong";
        vm.DecryptAndLoad();
        Assert.True(vm.NeedsPassword);
        Assert.Contains("密碼不正確", vm.ErrorMessage);
    }

    [Fact]
    public void OverwriteAll_SetsAllConflictsToOverwrite()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new", Database = "new" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.OverwriteAllCommand.Execute(null);
        Assert.All(vm.ImportPreviews.Where(p => p.HasConflict),
            p => Assert.Equal(ConflictAction.Overwrite, p.ConflictAction));
    }

    [Fact]
    public void SkipAll_SetsAllConflictsToSkip()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new", Database = "new" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.SkipAllCommand.Execute(null);
        Assert.All(vm.ImportPreviews.Where(p => p.HasConflict),
            p => Assert.Equal(ConflictAction.Skip, p.ConflictAction));
    }

    [Fact]
    public void ExecuteImport_AddsNewAndHandlesConflicts()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new-server", Database = "newdb" },
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.ImportPreviews[0].ConflictAction = ConflictAction.Overwrite;
        var result = vm.ExecuteImport();
        Assert.Equal(1, result.Added);
        Assert.Equal(1, result.Overwritten);
        Assert.Equal(0, result.Skipped);
        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(p => p.Name == "staging"));
        _settingsService.Received(1).UpdateProfile(Arg.Is<ConnectionProfile>(p => p.Name == "dev"));
    }

    [Fact]
    public void HasProductionOverwrite_有Production覆蓋時為True()
    {
        var existing = new List<ConnectionProfile>
        {
            new() { Id = "1", Name = "prod", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, Source = "Custom" }
        };
        var vm = new ImportConnectionsViewModel(
            Substitute.For<IConnectionExportService>(), Substitute.For<ISettingsService>(), existing);
        var incoming = new ConnectionProfile { Name = "prod", Server = "s2", Database = "d2", Environment = DatabaseEnvironment.Production };
        vm.ImportPreviews.Add(new ImportPreviewItem(incoming, hasConflict: true, existingProfile: existing[0])
        {
            ConflictAction = ConflictAction.Overwrite
        });

        Assert.True(vm.HasProductionOverwrite());
    }

    [Fact]
    public void HasProductionOverwrite_跳過或非Production時為False()
    {
        var existing = new List<ConnectionProfile>
        {
            new() { Id = "1", Name = "dev", Server = "s", Database = "d", Environment = DatabaseEnvironment.Development, Source = "Custom" }
        };
        var vm = new ImportConnectionsViewModel(
            Substitute.For<IConnectionExportService>(), Substitute.For<ISettingsService>(), existing);
        var incoming = new ConnectionProfile { Name = "dev", Server = "s2", Database = "d2", Environment = DatabaseEnvironment.Development };
        vm.ImportPreviews.Add(new ImportPreviewItem(incoming, hasConflict: true, existingProfile: existing[0])
        {
            ConflictAction = ConflictAction.Skip
        });

        Assert.False(vm.HasProductionOverwrite());
    }

    [Fact]
    public void ExecuteImport_SkipConflict_DoesNotUpdate()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new-server", Database = "newdb" }
            }
        });
        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.ImportPreviews[0].ConflictAction = ConflictAction.Skip;
        var result = vm.ExecuteImport();
        Assert.Equal(0, result.Added);
        Assert.Equal(0, result.Overwritten);
        Assert.Equal(1, result.Skipped);
        _settingsService.DidNotReceive().UpdateProfile(Arg.Any<ConnectionProfile>());
    }
}
