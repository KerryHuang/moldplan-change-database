# appsettings.Development.json 套用功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增「套用開發」功能，讓使用者選擇目錄後，一鍵更新該目錄下所有 appsettings.Development.json 的 MSSQL 連線設定。

**Architecture:** 新增 `AppSettingsDevService` 負責掃描與更新 JSON 檔，`AppSettings` 模型加 `DevDirectory`，主視窗新增「套用開發」按鈕開啟 `ApplyDevDialog`（勾選式檔案清單）。

**Tech Stack:** .NET 9, Avalonia 11.3, CommunityToolkit.Mvvm, System.Text.Json.Nodes, xUnit, NSubstitute

---

## 檔案結構

| 動作 | 路徑 |
|------|------|
| 修改 | `src/MoldplanDbSwitcher/Models/AppSettings.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/IAppSettingsDevService.cs` |
| 新增 | `src/MoldplanDbSwitcher/Services/AppSettingsDevService.cs` |
| 修改 | `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` |
| 修改 | `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml` |
| 修改 | `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs` |
| 新增 | `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml` |
| 新增 | `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml.cs` |
| 修改 | `src/MoldplanDbSwitcher/Views/MainWindow.axaml` |
| 修改 | `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` |
| 修改 | `src/MoldplanDbSwitcher/Program.cs` |
| 新增 | `tests/MoldplanDbSwitcher.Tests/Services/AppSettingsDevServiceTests.cs` |

---

## Task 1：AppSettings 模型加 DevDirectory

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/AppSettings.cs`

- [ ] **Step 1：在 AppSettings 加入 DevDirectory 屬性**

將 `AppSettings.cs` 改為：

```csharp
namespace MoldplanDbSwitcher.Models;

public class AppSettings
{
    public string AnsibleRepoPath { get; set; } = string.Empty;

    public string VaultPasswordFile { get; set; } =
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".ansible-vault-pass");

    public string DevDirectory { get; set; } = string.Empty;
}
```

- [ ] **Step 2：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 3：Commit**

```
git add src/MoldplanDbSwitcher/Models/AppSettings.cs
git commit -m "feat: AppSettings 新增 DevDirectory 屬性"
```

---

## Task 2：AppSettingsDevService（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IAppSettingsDevService.cs`
- Create: `src/MoldplanDbSwitcher/Services/AppSettingsDevService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/AppSettingsDevServiceTests.cs`

- [ ] **Step 1：建立 interface**

新增 `src/MoldplanDbSwitcher/Services/IAppSettingsDevService.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IAppSettingsDevService
{
    IReadOnlyList<string> FindFiles(string directory);
    bool Apply(string filePath, ConnectionProfile profile);
}
```

- [ ] **Step 2：建立 stub 實作（讓測試能編譯）**

新增 `src/MoldplanDbSwitcher/Services/AppSettingsDevService.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class AppSettingsDevService : IAppSettingsDevService
{
    public IReadOnlyList<string> FindFiles(string directory) => [];
    public bool Apply(string filePath, ConnectionProfile profile) => false;
}
```

- [ ] **Step 3：寫失敗測試**

新增 `tests/MoldplanDbSwitcher.Tests/Services/AppSettingsDevServiceTests.cs`：

```csharp
using System.Text.Json;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class AppSettingsDevServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly AppSettingsDevService _sut;

    public AppSettingsDevServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_tempDir);
        _sut = new AppSettingsDevService();
    }

    public void Dispose() => Directory.Delete(_tempDir, recursive: true);

    [Fact]
    public void FindFiles_EmptyDirectory_ReturnsEmptyList()
    {
        var result = _sut.FindFiles(_tempDir);
        Assert.Empty(result);
    }

    [Fact]
    public void FindFiles_NonExistentDirectory_ReturnsEmptyList()
    {
        var result = _sut.FindFiles(Path.Combine(_tempDir, "nonexistent"));
        Assert.Empty(result);
    }

    [Fact]
    public void FindFiles_WithNestedFiles_ReturnsAllPaths()
    {
        var sub = Path.Combine(_tempDir, "projectA", "src");
        Directory.CreateDirectory(sub);
        var file1 = Path.Combine(_tempDir, "appsettings.Development.json");
        var file2 = Path.Combine(sub, "appsettings.Development.json");
        File.WriteAllText(file1, "{}");
        File.WriteAllText(file2, "{}");

        var result = _sut.FindFiles(_tempDir);

        Assert.Equal(2, result.Count);
        Assert.Contains(file1, result);
        Assert.Contains(file2, result);
    }

    [Fact]
    public void FindFiles_IgnoresOtherJsonFiles()
    {
        File.WriteAllText(Path.Combine(_tempDir, "appsettings.json"), "{}");
        File.WriteAllText(Path.Combine(_tempDir, "appsettings.Production.json"), "{}");

        var result = _sut.FindFiles(_tempDir);

        Assert.Empty(result);
    }

    [Fact]
    public void Apply_UpdatesMssqlFields_LeavesOtherFieldsIntact()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old-host",
            "Port": "1433",
            "UserId": "old-user",
            "Password": "old-pass",
            "ApplicationDatabase": "old-db",
            "LocalizationDatabase": "loc-db",
            "QuartzJobDatabase": "quartz-db"
          },
          "OtherSection": { "Key": "value" }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.1.100",
            Database = "new-app-db",
            Username = "mis",
            Password = "secret"
        };

        var result = _sut.Apply(filePath, profile);

        Assert.True(result);
        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.1.100", mssql.GetProperty("Host").GetString());
        Assert.Equal("1433", mssql.GetProperty("Port").GetString());
        Assert.Equal("mis", mssql.GetProperty("UserId").GetString());
        Assert.Equal("secret", mssql.GetProperty("Password").GetString());
        Assert.Equal("new-app-db", mssql.GetProperty("ApplicationDatabase").GetString());
        // 保留不動
        Assert.Equal("loc-db", mssql.GetProperty("LocalizationDatabase").GetString());
        Assert.Equal("quartz-db", mssql.GetProperty("QuartzJobDatabase").GetString());
        Assert.Equal("value", json.RootElement.GetProperty("OtherSection").GetProperty("Key").GetString());
    }

    [Fact]
    public void Apply_ServerWithPort_SplitsCorrectly()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old",
            "Port": "1433",
            "UserId": "u",
            "Password": "p",
            "ApplicationDatabase": "db"
          }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.21.1,1430",
            Database = "mydb",
            Username = "mis",
            Password = "pass"
        };

        _sut.Apply(filePath, profile);

        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.21.1", mssql.GetProperty("Host").GetString());
        Assert.Equal("1430", mssql.GetProperty("Port").GetString());
    }

    [Fact]
    public void Apply_ServerWithoutPort_DefaultsTo1433()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """
        {
          "MSSQL": {
            "Host": "old",
            "Port": "9999",
            "UserId": "u",
            "Password": "p",
            "ApplicationDatabase": "db"
          }
        }
        """);

        var profile = new ConnectionProfile
        {
            Server = "192.168.1.1",
            Database = "mydb",
            Username = "mis",
            Password = "pass"
        };

        _sut.Apply(filePath, profile);

        var json = JsonDocument.Parse(File.ReadAllText(filePath));
        var mssql = json.RootElement.GetProperty("MSSQL");
        Assert.Equal("192.168.1.1", mssql.GetProperty("Host").GetString());
        Assert.Equal("1433", mssql.GetProperty("Port").GetString());
    }

    [Fact]
    public void Apply_MissingMssqlSection_ReturnsFalse()
    {
        var filePath = Path.Combine(_tempDir, "appsettings.Development.json");
        File.WriteAllText(filePath, """{ "Other": {} }""");

        var profile = new ConnectionProfile { Server = "1.1.1.1", Database = "db" };

        var result = _sut.Apply(filePath, profile);

        Assert.False(result);
    }
}
```

- [ ] **Step 4：確認測試失敗**

```
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsDevServiceTests"
```

Expected: 多個測試 FAIL（stub 實作回傳空值）

- [ ] **Step 5：實作 AppSettingsDevService**

將 `src/MoldplanDbSwitcher/Services/AppSettingsDevService.cs` 改為：

```csharp
using System.Text.Json.Nodes;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class AppSettingsDevService : IAppSettingsDevService
{
    public IReadOnlyList<string> FindFiles(string directory)
    {
        if (!Directory.Exists(directory))
            return [];

        return Directory.EnumerateFiles(directory, "appsettings.Development.json",
            SearchOption.AllDirectories).ToList();
    }

    public bool Apply(string filePath, ConnectionProfile profile)
    {
        var text = File.ReadAllText(filePath);
        var root = JsonNode.Parse(text);
        if (root is not JsonObject rootObj)
            return false;

        if (rootObj["MSSQL"] is not JsonObject mssql)
            return false;

        var (host, port) = SplitServer(profile.Server);
        mssql["Host"] = host;
        mssql["Port"] = port;
        mssql["UserId"] = profile.Username;
        mssql["Password"] = profile.Password;
        mssql["ApplicationDatabase"] = profile.Database;

        File.WriteAllText(filePath, root.ToJsonString(new System.Text.Json.JsonSerializerOptions
        {
            WriteIndented = true
        }));
        return true;
    }

    private static (string host, string port) SplitServer(string server)
    {
        var idx = server.IndexOf(',');
        if (idx >= 0)
            return (server[..idx], server[(idx + 1)..]);
        return (server, "1433");
    }
}
```

- [ ] **Step 6：確認測試全通過**

```
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsDevServiceTests"
```

Expected: 全部 PASS

- [ ] **Step 7：Commit**

```
git add src/MoldplanDbSwitcher/Services/IAppSettingsDevService.cs \
        src/MoldplanDbSwitcher/Services/AppSettingsDevService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/AppSettingsDevServiceTests.cs
git commit -m "feat: 新增 AppSettingsDevService，掃描並更新 appsettings.Development.json"
```

---

## Task 3：DI 註冊

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

- [ ] **Step 1：註冊 AppSettingsDevService**

在 `Program.cs` 的 `ConfigureServices` 中，於 `AddSingleton<IAnsibleSyncService>` 之後加入：

```csharp
services.AddSingleton<IAppSettingsDevService, AppSettingsDevService>();
```

- [ ] **Step 2：加入 using（如需要）**

確認 `Program.cs` 頂部有：

```csharp
using MoldplanDbSwitcher.Services;
```

（此行通常已存在，確認即可。）

- [ ] **Step 3：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 4：Commit**

```
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "feat: 註冊 AppSettingsDevService 至 DI 容器"
```

---

## Task 4：SettingsDialog 新增開發目錄欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs`

- [ ] **Step 1：在 axaml 新增開發目錄區塊**

在 `SettingsDialog.axaml` 的 `</StackPanel>` 結尾（第 36 行，Ansible 設定 StackPanel 的最後一個子項目之後）加入：

```xml
      <StackPanel Spacing="4">
        <TextBlock Text="開發目錄：" />
        <DockPanel>
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseDevDirectoryClick" Margin="8,0,0,0" />
          <TextBox x:Name="DevDirectoryBox" Watermark="例：C:\Users\alice\repos" />
        </DockPanel>
      </StackPanel>
```

完整 axaml 結果（`<StackPanel Spacing="12">` 區塊的最終狀態）：

```xml
    <StackPanel Spacing="12">
      <TextBlock Text="Ansible 連線設定" FontWeight="Bold" FontSize="14" />

      <StackPanel Spacing="4">
        <TextBlock Text="deploy-ansible Repo 路徑：" />
        <DockPanel>
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseRepoClick" Margin="8,0,0,0" />
          <TextBox x:Name="AnsibleRepoPathBox" Watermark="例：/Users/alice/repos/deploy-ansible" />
        </DockPanel>
      </StackPanel>

      <StackPanel Spacing="4">
        <TextBlock Text="Vault 密碼檔案路徑：" />
        <DockPanel>
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseVaultPassClick" Margin="8,0,0,0" />
          <TextBox x:Name="VaultPasswordFileBox" Watermark="預設：~/.ansible-vault-pass" />
        </DockPanel>
      </StackPanel>

      <StackPanel Spacing="4">
        <TextBlock Text="開發目錄：" />
        <DockPanel>
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseDevDirectoryClick" Margin="8,0,0,0" />
          <TextBox x:Name="DevDirectoryBox" Watermark="例：C:\Users\alice\repos" />
        </DockPanel>
      </StackPanel>
    </StackPanel>
```

- [ ] **Step 2：更新 code-behind**

將 `SettingsDialog.axaml.cs` 改為：

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Views;

public partial class SettingsDialog : Window
{
    private readonly IAppSettingsService _appSettingsService;

    public SettingsDialog(IAppSettingsService appSettingsService)
    {
        InitializeComponent();
        _appSettingsService = appSettingsService;

        var settings = _appSettingsService.Load();
        AnsibleRepoPathBox.Text = settings.AnsibleRepoPath;
        VaultPasswordFileBox.Text = settings.VaultPasswordFile;
        DevDirectoryBox.Text = settings.DevDirectory;
    }

    private void OnSaveClick(object? sender, RoutedEventArgs e)
    {
        _appSettingsService.Save(new AppSettings
        {
            AnsibleRepoPath = AnsibleRepoPathBox.Text ?? string.Empty,
            VaultPasswordFile = VaultPasswordFileBox.Text ?? string.Empty,
            DevDirectory = DevDirectoryBox.Text ?? string.Empty
        });
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();

    private async void OnBrowseRepoClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇 deploy-ansible 目錄",
            AllowMultiple = false
        });
        if (folders.Count > 0)
            AnsibleRepoPathBox.Text = folders[0].Path.LocalPath;
    }

    private async void OnBrowseVaultPassClick(object? sender, RoutedEventArgs e)
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            Title = "選擇 Vault 密碼檔案",
            AllowMultiple = false
        });
        if (files.Count > 0)
            VaultPasswordFileBox.Text = files[0].Path.LocalPath;
    }

    private async void OnBrowseDevDirectoryClick(object? sender, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "選擇開發目錄",
            AllowMultiple = false
        });
        if (folders.Count > 0)
            DevDirectoryBox.Text = folders[0].Path.LocalPath;
    }
}
```

- [ ] **Step 3：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 4：Commit**

```
git add src/MoldplanDbSwitcher/Views/SettingsDialog.axaml \
        src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs
git commit -m "feat: 設定視窗新增開發目錄欄位"
```

---

## Task 5：ApplyDevDialog（新增對話框）

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml.cs`

- [ ] **Step 1：建立 axaml**

新增 `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml`：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MoldplanDbSwitcher.Views.ApplyDevDialog"
        Title="套用開發設定"
        Width="600"
        Height="400"
        WindowStartupLocation="CenterOwner"
        CanResize="True">

  <DockPanel Margin="16">

    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal"
                HorizontalAlignment="Right" Spacing="8" Margin="0,12,0,0">
      <Button Content="全選" Click="OnSelectAllClick" />
      <Button Content="取消全選" Click="OnDeselectAllClick" />
      <Button Content="確認" Click="OnConfirmClick" Classes="accent" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>

    <StackPanel DockPanel.Dock="Top" Margin="0,0,0,8">
      <TextBlock x:Name="NoFilesText" Text="找不到 appsettings.Development.json" IsVisible="False" />
    </StackPanel>

    <ScrollViewer>
      <ItemsControl x:Name="FileList">
        <ItemsControl.ItemTemplate>
          <DataTemplate>
            <CheckBox Content="{Binding Path}"
                      IsChecked="{Binding IsChecked}"
                      Margin="0,2" />
          </DataTemplate>
        </ItemsControl.ItemTemplate>
      </ItemsControl>
    </ScrollViewer>

  </DockPanel>
</Window>
```

- [ ] **Step 2：建立 code-behind**

新增 `src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml.cs`：

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher.Views;

public partial class ApplyDevDialog : Window
{
    private readonly List<FileItem> _items;

    public ApplyDevDialog(IReadOnlyList<string> files)
    {
        InitializeComponent();
        _items = files.Select(f => new FileItem { Path = f, IsChecked = true }).ToList();

        if (_items.Count == 0)
        {
            NoFilesText.IsVisible = true;
        }
        else
        {
            FileList.ItemsSource = _items;
        }
    }

    private void OnSelectAllClick(object? sender, RoutedEventArgs e)
    {
        foreach (var item in _items) item.IsChecked = true;
    }

    private void OnDeselectAllClick(object? sender, RoutedEventArgs e)
    {
        foreach (var item in _items) item.IsChecked = false;
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        Close(_items.Where(i => i.IsChecked).Select(i => i.Path).ToList());
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close(null);
}

public partial class FileItem : ObservableObject
{
    public string Path { get; set; } = string.Empty;

    [ObservableProperty]
    private bool _isChecked;
}
```

- [ ] **Step 3：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 4：Commit**

```
git add src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml \
        src/MoldplanDbSwitcher/Views/ApplyDevDialog.axaml.cs
git commit -m "feat: 新增 ApplyDevDialog 勾選檔案對話框"
```

---

## Task 6：MainWindowViewModel 加入套用開發命令

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 1：在建構式加入 IAppSettingsDevService 依賴**

在 `MainWindowViewModel.cs` 中：

1. 在私有欄位區（第 20 行附近）加入：

```csharp
private readonly IAppSettingsDevService _appSettingsDevService;
```

2. 建構式參數加入 `IAppSettingsDevService appSettingsDevService`，並在建構式本體賦值：

```csharp
_appSettingsDevService = appSettingsDevService;
```

建構式簽名更新為：

```csharp
public MainWindowViewModel(
    IConnectionSourceService connectionSource,
    IServerTxtService serverTxtService,
    ISettingsService settingsService,
    IFeatureReportService featureReportService,
    IConnectionExportService connectionExportService,
    IUsageReportService usageReportService,
    IAnsibleSyncService ansibleSyncService,
    IAppSettingsService appSettingsService,
    IAppSettingsDevService appSettingsDevService)
```

- [ ] **Step 2：新增 HasDevDirectory 屬性與 ApplyDevCommand**

在 `CanSyncAnsible` 屬性（第 52 行附近）之後加入：

```csharp
public bool HasDevDirectory =>
    !string.IsNullOrWhiteSpace(_appSettingsService.Load().DevDirectory);

public void NotifyHasDevDirectoryChanged() => OnPropertyChanged(nameof(HasDevDirectory));

public Func<IReadOnlyList<string>, Task<IReadOnlyList<string>?>>? ApplyDevDialogCallback { get; set; }

[RelayCommand]
private async Task ApplyDevAsync()
{
    var devDir = _appSettingsService.Load().DevDirectory;
    var files = _appSettingsDevService.FindFiles(devDir);

    if (ApplyDevDialogCallback is null) return;
    var selected = await ApplyDevDialogCallback(files);
    if (selected is null || SelectedConnection is null) return;

    var success = 0;
    var fail = 0;
    foreach (var path in selected)
    {
        if (_appSettingsDevService.Apply(path, SelectedConnection))
            success++;
        else
            fail++;
    }

    StatusMessage = fail == 0
        ? $"套用完成：已更新 {success} 個檔案"
        : $"套用完成：{success} 成功，{fail} 失敗";
}
```

- [ ] **Step 3：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 4：Commit**

```
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs
git commit -m "feat: MainWindowViewModel 新增 HasDevDirectory 與 ApplyDevCommand"
```

---

## Task 7：主視窗 UI 新增「套用開發」按鈕

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

- [ ] **Step 1：在 axaml 操作按鈕列加入「套用開發」按鈕**

在 `MainWindow.axaml` 第 62 行「套用變更」按鈕之後加入：

```xml
        <Button Content="套用開發"
                Command="{Binding ApplyDevCommand}"
                IsVisible="{Binding HasDevDirectory}"
                HorizontalAlignment="Left" />
```

完整操作按鈕 StackPanel：

```xml
      <StackPanel Orientation="Horizontal" Spacing="8">
        <Button Content="套用變更" Command="{Binding ApplyChangesCommand}"
                Classes="accent" HorizontalAlignment="Left" />
        <Button Content="套用開發"
                Command="{Binding ApplyDevCommand}"
                IsVisible="{Binding HasDevDirectory}"
                HorizontalAlignment="Left" />
        <Button Content="新增自訂連線" Click="OnAddConnectionClick"
                HorizontalAlignment="Left" />
        <Button Content="刪除自訂連線" Click="OnDeleteConnectionClick"
                HorizontalAlignment="Left" />
      </StackPanel>
```

- [ ] **Step 2：在 code-behind 設定 ApplyDevDialogCallback**

在 `MainWindow.axaml.cs` 的 `OnSettingsClick` 方法之後加入：

```csharp
    private void SetupApplyDevCallback(MainWindowViewModel vm)
    {
        vm.ApplyDevDialogCallback = async files =>
        {
            var dialog = new ApplyDevDialog(files);
            return await dialog.ShowDialog<IReadOnlyList<string>?>(this);
        };
    }
```

並在 `MainWindow` 建構式（或 `OnDataContextChanged`）中呼叫此方法。由於 `DataContext` 在建構式之後設定，覆寫 `OnDataContextChanged`：

在 `MainWindow.axaml.cs` class body 加入：

```csharp
    protected override void OnDataContextChanged(EventArgs e)
    {
        base.OnDataContextChanged(e);
        if (DataContext is MainWindowViewModel vm)
            SetupApplyDevCallback(vm);
    }
```

同時在 `OnSettingsClick` 的通知之後加入：

```csharp
        vm.NotifyHasDevDirectoryChanged();
```

完整更新後的 `OnSettingsClick`：

```csharp
    private async void OnSettingsClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new SettingsDialog(App.Services!.GetRequiredService<IAppSettingsService>());
        await dialog.ShowDialog(this);
        if (DataContext is MainWindowViewModel vm)
        {
            vm.NotifyCanSyncAnsibleChanged();
            vm.NotifyHasDevDirectoryChanged();
        }
    }
```

- [ ] **Step 3：確認建置通過**

```
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded, 0 Error(s)

- [ ] **Step 4：執行全部測試**

```
dotnet test tests/MoldplanDbSwitcher.Tests/
```

Expected: 全部 PASS

- [ ] **Step 5：Commit**

```
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml \
        src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: 主視窗新增「套用開發」按鈕與對話框連結"
```
