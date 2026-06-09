# MoldplanDbSwitcher 連線環境模式 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 MoldplanDbSwitcher 套用與 Specurai 一致的連線環境模式：環境欄位、選擇器統一顯示與排序、Production 防呆。

**Architecture:** 在 Models 加 `DatabaseEnvironment` 列舉（與 Specurai 同序、數字序列化）與 `ConnectionProfile.Environment`；`ConnectionProfileComparer` 集中排序、兩個 Converter 統一顯示；Production 防呆透過新的 `ConfirmDialog`（紅色橫幅）+ VM 確認回呼，覆蓋套用連線、刪除自訂連線、匯入覆蓋。

**Tech Stack:** .NET 9、Avalonia 11.3、Semi.Avalonia、CommunityToolkit.Mvvm、xUnit + NSubstitute（測試用 `Assert` 風格）。

---

## 慣例提醒
- 繁體中文註解與 commit（專案 CLAUDE.md 律法）。
- 測試用 xUnit `Assert`（**非** FluentAssertions），對照既有 `MainWindowViewModelTests`。
- Services 採 Interface-first（本功能不新增 Service）。
- 用 Bash（bash）；每個指令需 `cd C:/Users/zihao/source/repos/moldplan-change-database`（工具每次重置 cwd）。
- 分支 `feature/connection-environment-mode`（已建立，勿切換）。
- ⚠️ **序列化**：環境列舉與 Specurai 同序（Development=0…Production=3）、**數字序列化、不可加 JsonStringEnumConverter**（否則破壞 authType 與跨 app 相容）。

## 檔案結構

| 檔案 | 動作 |
|------|------|
| `src/MoldplanDbSwitcher/Models/DatabaseEnvironment.cs` | Create |
| `src/MoldplanDbSwitcher/Models/DatabaseEnvironmentInference.cs` | Create |
| `src/MoldplanDbSwitcher/Models/ConnectionProfileComparer.cs` | Create |
| `src/MoldplanDbSwitcher/Models/ConnectionProfile.cs` | Modify（+Environment） |
| `src/MoldplanDbSwitcher/Converters/DatabaseEnvironmentDisplayConverter.cs` | Create |
| `src/MoldplanDbSwitcher/Converters/ConnectionProfileDisplayConverter.cs` | Create |
| `src/MoldplanDbSwitcher/App.axaml` | Modify（註冊 Converter） |
| `src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs` | Modify（+Environment/Options） |
| `src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml` | Modify（+環境下拉） |
| `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` | Modify（排序、Ansible 推斷、ConfirmCallback、Apply/Delete 防呆、AddCustom 簽章） |
| `src/MoldplanDbSwitcher/Views/MainWindow.axaml(.cs)` | Modify（ComboBox/DataGrid、ConfirmCallback 接線、Add/Delete 接線） |
| `src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml(.cs)` | Create |
| `src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs` | Modify（HasProductionOverwrite） |
| `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml(.cs)` | Modify（預覽顯示、匯入防呆） |
| `src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml` | Modify（清單顯示） |
| `tests/MoldplanDbSwitcher.Tests/...` | 多檔新增/修改 |

---

## Task 1: 環境列舉與 ConnectionProfile 欄位

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/DatabaseEnvironment.cs`
- Modify: `src/MoldplanDbSwitcher/Models/ConnectionProfile.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs`

- [ ] **Step 1: 寫失敗測試**

在 `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs` 加入（檔頭若無，補 `using System.Text.Json;`、`using MoldplanDbSwitcher.Models;`）：

```csharp
[Fact]
public void Environment_預設為Staging()
{
    var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d" };
    Assert.Equal(DatabaseEnvironment.Staging, p.Environment);
}

[Fact]
public void Environment_序列化往返應保留()
{
    var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production };
    var json = JsonSerializer.Serialize(p);
    var back = JsonSerializer.Deserialize<ConnectionProfile>(json);
    Assert.Equal(DatabaseEnvironment.Production, back!.Environment);
}

[Fact]
public void Environment_序列化為數字()
{
    var p = new ConnectionProfile { Name = "a", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production };
    var json = JsonSerializer.Serialize(p);
    Assert.Contains("\"environment\":3", json);
}

[Fact]
public void 反序列化舊JSON無environment欄位_應為Staging()
{
    var json = "{\"name\":\"a\",\"server\":\"s\",\"database\":\"d\",\"authType\":0}";
    var p = JsonSerializer.Deserialize<ConnectionProfile>(json);
    Assert.Equal(DatabaseEnvironment.Staging, p!.Environment);
}

[Fact]
public void 反序列化Specurai式PascalCase數字_應正確對應環境()
{
    // 模擬 Specurai 寫出的 PascalCase 數字 + 不分大小寫解析
    var json = "{\"Name\":\"a\",\"Server\":\"s\",\"Database\":\"d\",\"Environment\":3}";
    var p = JsonSerializer.Deserialize<ConnectionProfile>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
    Assert.Equal(DatabaseEnvironment.Production, p!.Environment);
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionProfileTests"`
Expected: 編譯失敗（`DatabaseEnvironment`、`Environment` 尚未存在）。

- [ ] **Step 3: 建立列舉**

建立 `src/MoldplanDbSwitcher/Models/DatabaseEnvironment.cs`：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>資料庫連線所屬環境（順序須與 Specurai 一致以維持跨 app 相容）。</summary>
public enum DatabaseEnvironment
{
    /// <summary>開發環境</summary>
    Development,
    /// <summary>測試環境</summary>
    Testing,
    /// <summary>預備環境</summary>
    Staging,
    /// <summary>正式環境</summary>
    Production
}
```

- [ ] **Step 4: 加 Environment 屬性**

在 `src/MoldplanDbSwitcher/Models/ConnectionProfile.cs` 的 `IsDefault` 屬性之後、`[JsonIgnore] Source` 之前加入：

```csharp
    [JsonPropertyName("environment")]
    public DatabaseEnvironment Environment { get; set; } = DatabaseEnvironment.Staging;
```

- [ ] **Step 5: 執行測試確認通過**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionProfileTests"`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Models/DatabaseEnvironment.cs src/MoldplanDbSwitcher/Models/ConnectionProfile.cs tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs && git commit -m "feat: ConnectionProfile 新增環境欄位

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 環境名稱推斷（Ansible 用）

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/DatabaseEnvironmentInference.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Models/DatabaseEnvironmentInferenceTests.cs`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/MoldplanDbSwitcher.Tests/Models/DatabaseEnvironmentInferenceTests.cs`：

```csharp
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class DatabaseEnvironmentInferenceTests
{
    [Theory]
    [InlineData("Foo - 正式", DatabaseEnvironment.Production)]
    [InlineData("Foo - 測試", DatabaseEnvironment.Testing)]
    [InlineData("Foo-Staging", DatabaseEnvironment.Staging)]
    [InlineData("", DatabaseEnvironment.Staging)]
    [InlineData(null, DatabaseEnvironment.Staging)]
    public void FromName_應依關鍵字推斷(string? name, DatabaseEnvironment expected)
    {
        Assert.Equal(expected, DatabaseEnvironmentInference.FromName(name));
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~DatabaseEnvironmentInferenceTests"`
Expected: 編譯失敗。

- [ ] **Step 3: 建立推斷器**

建立 `src/MoldplanDbSwitcher/Models/DatabaseEnvironmentInference.cs`：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>依連線名稱推斷環境（供無明確環境欄位的 Ansible 來源使用）。</summary>
public static class DatabaseEnvironmentInference
{
    public static DatabaseEnvironment FromName(string? name)
    {
        if (string.IsNullOrEmpty(name)) return DatabaseEnvironment.Staging;
        if (name.Contains("正式")) return DatabaseEnvironment.Production;
        if (name.Contains("測試")) return DatabaseEnvironment.Testing;
        return DatabaseEnvironment.Staging;
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~DatabaseEnvironmentInferenceTests"`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Models/DatabaseEnvironmentInference.cs tests/MoldplanDbSwitcher.Tests/Models/DatabaseEnvironmentInferenceTests.cs && git commit -m "feat: 新增依名稱推斷環境的工具

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: ConnectionProfileComparer

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ConnectionProfileComparer.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileComparerTests.cs`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileComparerTests.cs`：

```csharp
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionProfileComparerTests
{
    private static ConnectionProfile P(string name, DatabaseEnvironment env, bool isDefault = false) =>
        new() { Name = name, Server = "s", Database = "d", Environment = env, IsDefault = isDefault };

    [Fact]
    public void 預設連線_排在非預設之前()
    {
        var list = new List<ConnectionProfile>
        {
            P("Zzz", DatabaseEnvironment.Development),
            P("Aaa", DatabaseEnvironment.Production, isDefault: true)
        };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal("Aaa", list[0].Name);
    }

    [Fact]
    public void 非預設_依環境列舉順序()
    {
        var list = new List<ConnectionProfile>
        {
            P("a", DatabaseEnvironment.Production),
            P("b", DatabaseEnvironment.Development),
            P("c", DatabaseEnvironment.Staging),
            P("d", DatabaseEnvironment.Testing)
        };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal(
            new[] { DatabaseEnvironment.Development, DatabaseEnvironment.Testing, DatabaseEnvironment.Staging, DatabaseEnvironment.Production },
            list.Select(p => p.Environment).ToArray());
    }

    [Fact]
    public void 同環境同預設_依名稱不分大小寫()
    {
        var list = new List<ConnectionProfile> { P("banana", DatabaseEnvironment.Staging), P("Apple", DatabaseEnvironment.Staging) };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal("Apple", list[0].Name);
    }

    [Fact]
    public void Null_排最後()
    {
        var a = P("a", DatabaseEnvironment.Staging);
        Assert.True(ConnectionProfileComparer.Instance.Compare(a, null) < 0);
        Assert.True(ConnectionProfileComparer.Instance.Compare(null, a) > 0);
        Assert.Equal(0, ConnectionProfileComparer.Instance.Compare(null, null));
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionProfileComparerTests"`
Expected: 編譯失敗。

- [ ] **Step 3: 建立比較器**

建立 `src/MoldplanDbSwitcher/Models/ConnectionProfileComparer.cs`：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>連線顯示排序：預設優先 → 環境（列舉順序）→ 名稱（不分大小寫）。</summary>
public sealed class ConnectionProfileComparer : IComparer<ConnectionProfile>
{
    public static readonly ConnectionProfileComparer Instance = new();

    public int Compare(ConnectionProfile? x, ConnectionProfile? y)
    {
        if (ReferenceEquals(x, y)) return 0;
        if (x is null) return 1;
        if (y is null) return -1;

        var byDefault = y.IsDefault.CompareTo(x.IsDefault);
        if (byDefault != 0) return byDefault;

        var byEnv = x.Environment.CompareTo(y.Environment);
        if (byEnv != 0) return byEnv;

        return string.Compare(x.Name, y.Name, StringComparison.OrdinalIgnoreCase);
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionProfileComparerTests"`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Models/ConnectionProfileComparer.cs tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileComparerTests.cs && git commit -m "feat: 新增連線顯示排序比較器

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 顯示轉換器與註冊

**Files:**
- Create: `src/MoldplanDbSwitcher/Converters/DatabaseEnvironmentDisplayConverter.cs`
- Create: `src/MoldplanDbSwitcher/Converters/ConnectionProfileDisplayConverter.cs`
- Modify: `src/MoldplanDbSwitcher/App.axaml`
- Test: `tests/MoldplanDbSwitcher.Tests/Converters/DatabaseEnvironmentDisplayConverterTests.cs`, `tests/MoldplanDbSwitcher.Tests/Converters/ConnectionProfileDisplayConverterTests.cs`

- [ ] **Step 1: 寫失敗測試**

建立 `tests/MoldplanDbSwitcher.Tests/Converters/DatabaseEnvironmentDisplayConverterTests.cs`：

```csharp
using System.Globalization;
using Xunit;
using MoldplanDbSwitcher.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Converters;

public class DatabaseEnvironmentDisplayConverterTests
{
    private readonly DatabaseEnvironmentDisplayConverter _c = new();

    [Theory]
    [InlineData(DatabaseEnvironment.Development, "開發環境")]
    [InlineData(DatabaseEnvironment.Testing, "測試環境")]
    [InlineData(DatabaseEnvironment.Staging, "預備環境")]
    [InlineData(DatabaseEnvironment.Production, "正式環境")]
    public void Convert_列舉_應為繁中(DatabaseEnvironment env, string expected)
    {
        Assert.Equal(expected, _c.Convert(env, typeof(string), null, CultureInfo.InvariantCulture));
    }
}
```

建立 `tests/MoldplanDbSwitcher.Tests/Converters/ConnectionProfileDisplayConverterTests.cs`：

```csharp
using System.Globalization;
using Xunit;
using MoldplanDbSwitcher.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Converters;

public class ConnectionProfileDisplayConverterTests
{
    private readonly ConnectionProfileDisplayConverter _c = new();

    private static ConnectionProfile P(string name, DatabaseEnvironment env, bool isDefault = false) =>
        new() { Name = name, Server = "s", Database = "d", Environment = env, IsDefault = isDefault };

    [Theory]
    [InlineData(DatabaseEnvironment.Development, "【開發】X")]
    [InlineData(DatabaseEnvironment.Testing, "【測試】X")]
    [InlineData(DatabaseEnvironment.Staging, "【預備】X")]
    [InlineData(DatabaseEnvironment.Production, "【正式】X")]
    public void Convert_非預設_應為環境標籤加名稱(DatabaseEnvironment env, string expected)
    {
        Assert.Equal(expected, _c.Convert(P("X", env), typeof(string), null, CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Convert_預設_應附加預設標記()
    {
        Assert.Equal("【正式】prod (預設)",
            _c.Convert(P("prod", DatabaseEnvironment.Production, isDefault: true), typeof(string), null, CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Convert_非ConnectionProfile_回傳原值字串()
    {
        Assert.Equal("其他", _c.Convert("其他", typeof(string), null, CultureInfo.InvariantCulture));
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~DisplayConverterTests"`
Expected: 編譯失敗。

- [ ] **Step 3: 建立兩個轉換器**

建立 `src/MoldplanDbSwitcher/Converters/DatabaseEnvironmentDisplayConverter.cs`：

```csharp
using System;
using System.Globalization;
using Avalonia.Data.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Converters;

/// <summary>將 DatabaseEnvironment 轉為繁中顯示名稱（開發/測試/預備/正式環境）。</summary>
public class DatabaseEnvironmentDisplayConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value switch
        {
            DatabaseEnvironment.Development => "開發環境",
            DatabaseEnvironment.Testing => "測試環境",
            DatabaseEnvironment.Staging => "預備環境",
            DatabaseEnvironment.Production => "正式環境",
            _ => value?.ToString()
        };

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
```

建立 `src/MoldplanDbSwitcher/Converters/ConnectionProfileDisplayConverter.cs`：

```csharp
using System;
using System.Globalization;
using Avalonia.Data.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Converters;

/// <summary>將 ConnectionProfile 轉為選擇器顯示字串：【環境簡稱】名稱 (預設)。</summary>
public class ConnectionProfileDisplayConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not ConnectionProfile p)
            return value?.ToString();

        var tag = p.Environment switch
        {
            DatabaseEnvironment.Development => "開發",
            DatabaseEnvironment.Testing => "測試",
            DatabaseEnvironment.Staging => "預備",
            DatabaseEnvironment.Production => "正式",
            _ => p.Environment.ToString()
        };

        return p.IsDefault ? $"【{tag}】{p.Name} (預設)" : $"【{tag}】{p.Name}";
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
```

- [ ] **Step 4: 在 App.axaml 註冊**

將 `src/MoldplanDbSwitcher/App.axaml` 改為（加入 `xmlns:converters` 與 `<Application.Resources>`）：

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:local="using:MoldplanDbSwitcher"
             xmlns:converters="using:MoldplanDbSwitcher.Converters"
             x:Class="MoldplanDbSwitcher.App"
             RequestedThemeVariant="Default">
  <Application.Resources>
    <converters:DatabaseEnvironmentDisplayConverter x:Key="DatabaseEnvironmentDisplayConverter" />
    <converters:ConnectionProfileDisplayConverter x:Key="ConnectionProfileDisplayConverter" />
  </Application.Resources>
  <Application.DataTemplates>
    <local:ViewLocator />
  </Application.DataTemplates>
  <Application.Styles>
    <FluentTheme />
    <StyleInclude Source="avares://Avalonia.Controls.DataGrid/Themes/Fluent.xaml" />
  </Application.Styles>
</Application>
```

- [ ] **Step 5: 測試與建置**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~DisplayConverterTests" && dotnet build src/MoldplanDbSwitcher`
Expected: 測試 PASS、Build succeeded。

- [ ] **Step 6: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Converters src/MoldplanDbSwitcher/App.axaml tests/MoldplanDbSwitcher.Tests/Converters && git commit -m "feat: 新增環境與連線顯示轉換器並註冊

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: ConnectionDialog 環境欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`（OnAddConnectionClick 傳環境）
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`（AddCustomConnection 簽章）
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionDialogViewModelTests.cs`、更新 `MainWindowViewModelTests`

- [ ] **Step 1: 寫失敗測試**

在 `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionDialogViewModelTests.cs` 加入：

```csharp
[Fact]
public void Environment_預設為Staging()
{
    var vm = new ConnectionDialogViewModel();
    Assert.Equal(DatabaseEnvironment.Staging, vm.Environment);
}

[Fact]
public void EnvironmentOptions_含四個值()
{
    Assert.Equal(
        new[] { DatabaseEnvironment.Development, DatabaseEnvironment.Testing, DatabaseEnvironment.Staging, DatabaseEnvironment.Production },
        ConnectionDialogViewModel.EnvironmentOptions.ToArray());
}
```
（若該測試檔未 `using MoldplanDbSwitcher.Models;` 則補上。）

同時更新 `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs` 既有測試 `AddCustomConnection_CallsSettingsService`，把呼叫改為新簽章並驗證環境：

```csharp
    [Fact]
    public void AddCustomConnection_CallsSettingsService()
    {
        var vm = CreateVm();
        vm.AddCustomConnection("new", "10.0.0.1", "testdb", DatabaseEnvironment.Production);

        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(
            p => p.Name == "new" && p.Server == "10.0.0.1" && p.Database == "testdb"
              && p.Environment == DatabaseEnvironment.Production));
    }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionDialogViewModelTests"`
Expected: 編譯失敗（Environment/EnvironmentOptions 不存在、AddCustomConnection 簽章不符）。

- [ ] **Step 3: ViewModel 加環境**

在 `src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs` 加入（檔頭補 `using System;`、`using System.Collections.Generic;`、`using MoldplanDbSwitcher.Models;`）：

```csharp
    [ObservableProperty]
    private DatabaseEnvironment _environment = DatabaseEnvironment.Staging;

    public static IReadOnlyList<DatabaseEnvironment> EnvironmentOptions { get; } =
        Enum.GetValues<DatabaseEnvironment>();
```

- [ ] **Step 4: AddCustomConnection 加環境參數**

在 `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` 將 `AddCustomConnection` 改為：

```csharp
    public void AddCustomConnection(string name, string server, string database, DatabaseEnvironment environment)
    {
        var profile = new ConnectionProfile
        {
            Name = name,
            Server = server,
            Database = database,
            Environment = environment
        };
        _settingsService.AddProfile(profile);
        LoadConnections();
        StatusMessage = $"已新增自訂連線：{name}";
    }
```

在 `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` 的 `OnAddConnectionClick` 將呼叫改為：

```csharp
            vm.AddCustomConnection(result.Name, result.Server, result.Database, result.Environment);
```

- [ ] **Step 5: ConnectionDialog.axaml 加環境下拉**

在 `src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml` 的「資料庫名稱」StackPanel（第 24-27 行）之後、按鈕列之前加入；並把 Window `Height="280"` 改為 `Height="340"`：

```xml
    <StackPanel Spacing="4">
      <TextBlock Text="環境" />
      <ComboBox HorizontalAlignment="Stretch"
                ItemsSource="{Binding EnvironmentOptions}"
                SelectedItem="{Binding Environment}">
        <ComboBox.ItemTemplate>
          <DataTemplate x:DataType="models:DatabaseEnvironment">
            <TextBlock Text="{Binding Converter={StaticResource DatabaseEnvironmentDisplayConverter}}" />
          </DataTemplate>
        </ComboBox.ItemTemplate>
      </ComboBox>
    </StackPanel>
```

並在根 `<Window>` 加入 `xmlns:models="using:MoldplanDbSwitcher.Models"`（緊接 `xmlns:vm` 那行之後）。

- [ ] **Step 6: 執行測試與建置**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ConnectionDialogViewModelTests|FullyQualifiedName~MainWindowViewModelTests" && dotnet build src/MoldplanDbSwitcher`
Expected: PASS、Build succeeded。

- [ ] **Step 7: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionDialogViewModelTests.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs && git commit -m "feat: ConnectionDialog 新增環境選擇

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 載入排序與 Ansible 環境推斷

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`（LoadConnections 排序、SyncAnsible 推斷）
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

在 `MainWindowViewModelTests` 加入（沿用既有 `CreateVm()` 與欄位）：

```csharp
    [Fact]
    public void LoadConnections_應依預設環境名稱排序()
    {
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "zzz", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, Source = "Specurai" },
            new() { Name = "aaa", Server = "s", Database = "d", Environment = DatabaseEnvironment.Development, Source = "Specurai" },
            new() { Name = "def", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, IsDefault = true, Source = "Specurai" },
        });
        var vm = CreateVm();

        Assert.Equal(new[] { "def", "aaa", "zzz" }, vm.Connections.Select(c => c.Name).ToArray());
    }

    [Fact]
    public async Task SyncAnsible_應依名稱推斷環境()
    {
        _ansibleSyncService.SyncAsync().Returns(new List<ConnectionProfile>
        {
            new() { Name = "客戶A - 正式", Server = "s", Database = "d", Source = "Ansible" },
            new() { Name = "客戶A - 測試", Server = "s", Database = "d", Source = "Ansible" },
        });
        var vm = CreateVm();

        await vm.SyncAnsibleCommand.ExecuteAsync(null);

        var prod = vm.Connections.First(c => c.Name == "客戶A - 正式");
        var test = vm.Connections.First(c => c.Name == "客戶A - 測試");
        Assert.Equal(DatabaseEnvironment.Production, prod.Environment);
        Assert.Equal(DatabaseEnvironment.Testing, test.Environment);
    }
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~MainWindowViewModelTests"`
Expected: 新測試失敗（尚未排序/推斷）。

- [ ] **Step 3: 套用排序與推斷**

在 `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` 的 `LoadConnections` 中，把指派 `Connections` 那行改為排序版本：

```csharp
        Connections = new ObservableCollection<ConnectionProfile>(
            all.OrderBy(p => p, ConnectionProfileComparer.Instance));
        SelectedConnection = Connections.FirstOrDefault();
```

在 `SyncAnsible` 中，於 `_ansibleConnections = await _ansibleSyncService.SyncAsync();` 之後加入：

```csharp
            foreach (var p in _ansibleConnections)
                p.Environment = DatabaseEnvironmentInference.FromName(p.Name);
```

（`System.Linq` 已隱含可用；`MoldplanDbSwitcher.Models` 已 using。）

- [ ] **Step 4: 執行測試確認通過**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~MainWindowViewModelTests"`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs && git commit -m "feat: 連線清單依環境排序並推斷 Ansible 環境

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Production 防呆 — ConfirmDialog 與套用/刪除

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml`、`ConfirmDialog.axaml.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`（ConfirmCallback、ApplyChanges、DeleteCustomConnection）
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`（接線 ConfirmCallback、Delete 改 async）
- Test: 更新 `MainWindowViewModelTests` 既有 Apply/Delete 測試 + 新增防呆測試

- [ ] **Step 1: 建立 ConfirmDialog（無單元測試的 UI 元件）**

建立 `src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml`：

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MoldplanDbSwitcher.Views.ConfirmDialog"
        Title="確認"
        Width="420"
        SizeToContent="Height"
        WindowStartupLocation="CenterOwner"
        CanResize="False">
  <StackPanel Margin="20" Spacing="15">
    <Border x:Name="WarningBanner" IsVisible="False"
            Background="#22FF3B30" BorderBrush="#FF3B30" BorderThickness="1"
            CornerRadius="4" Padding="10,8">
      <TextBlock x:Name="WarningText" Foreground="#FF3B30" FontWeight="Bold" TextWrapping="Wrap" />
    </Border>
    <TextBlock x:Name="MessageText" TextWrapping="Wrap" FontSize="14" />
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Spacing="10">
      <Button Content="是" Width="80" Click="OnYes" />
      <Button Content="否" Width="80" Click="OnNo" />
    </StackPanel>
  </StackPanel>
</Window>
```

建立 `src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml.cs`：

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;

namespace MoldplanDbSwitcher.Views;

public partial class ConfirmDialog : Window
{
    public ConfirmDialog() { InitializeComponent(); }

    /// <summary>建立確認對話框；warningBanner 非空白時於上方顯示紅色警告橫幅。</summary>
    public ConfirmDialog(string message, string? warningBanner) : this()
    {
        MessageText.Text = message;
        if (!string.IsNullOrEmpty(warningBanner))
        {
            WarningText.Text = warningBanner;
            WarningBanner.IsVisible = true;
        }
    }

    private void OnYes(object? sender, RoutedEventArgs e) => Close(true);
    private void OnNo(object? sender, RoutedEventArgs e) => Close(false);
}
```

- [ ] **Step 2: 寫/更新失敗測試**

在 `MainWindowViewModelTests`：

(a) 既有 `ApplyChanges_Success_SetsSuccessStatus`、`ApplyChanges_NoSelection_SetsErrorStatus`、`ApplyChanges_NoServerTxtSelected_SetsErrorStatus` 三個測試：因 `ApplyChanges` 改為 async，將 `vm.ApplyChangesCommand.Execute(null)` 改為 `await vm.ApplyChangesCommand.ExecuteAsync(null)`，並把測試方法改為 `async Task`。

(b) 既有 `DeleteCustomConnection_OnlyDeletesCustomSource`：`DeleteCustomConnection` 改為 async，將呼叫改為 `await vm.DeleteCustomConnection(tableSpecProfile);`，方法改 `async Task`。

(c) 新增防呆測試：

```csharp
    [Fact]
    public async Task ApplyChanges_Production_確認回否_不寫SERVER_txt()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        { Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1" });
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "prod", Server = "s", Database = "mis", Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(false); // 使用者按否

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        _serverTxtService.DidNotReceive().Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>());
        Assert.Contains("取消", vm.StatusMessage);
    }

    [Fact]
    public async Task ApplyChanges_Production_確認回是_有寫SERVER_txt()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        { Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1" });
        _connectionSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "prod", Server = "s", Database = "mis", Environment = DatabaseEnvironment.Production, Source = "Specurai" }
        });
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(true);

        await vm.ApplyChangesCommand.ExecuteAsync(null);

        _serverTxtService.Received().Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>());
    }

    [Fact]
    public async Task DeleteCustomConnection_Production_確認回否_不刪除()
    {
        var vm = CreateVm();
        vm.ConfirmCallback = (_, _) => Task.FromResult(false);
        var profile = new ConnectionProfile { Id = "9", Name = "prod", Server = "s", Database = "d",
            Environment = DatabaseEnvironment.Production, Source = "Custom" };

        await vm.DeleteCustomConnection(profile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }
```

- [ ] **Step 3: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~MainWindowViewModelTests"`
Expected: 編譯失敗或新測試失敗（ConfirmCallback 不存在、Apply/Delete 尚未防呆）。

- [ ] **Step 4: VM 加 ConfirmCallback 與防呆**

在 `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`，於 `SaveFileCallback` 等回呼附近加入：

```csharp
    /// <summary>Production 重大操作的確認回呼（由 View 設定）。參數：(訊息, 警告橫幅)。</summary>
    public Func<string, string?, Task<bool>>? ConfirmCallback { get; set; }
```

將 `ApplyChanges` 改為 async 並在 Production 時確認（注意把 `[RelayCommand] private void ApplyChanges()` 改成 `[RelayCommand] private async Task ApplyChanges()`）：

```csharp
    [RelayCommand]
    private async Task ApplyChanges()
    {
        if (SelectedConnection is null)
        {
            StatusMessage = "請先選擇一個連線設定";
            return;
        }

        var selectedFiles = ServerTxtFiles.Where(f => f.IsSelected).ToList();
        if (selectedFiles.Count == 0)
        {
            StatusMessage = "請至少選擇一個 SERVER.txt 檔案";
            return;
        }

        if (SelectedConnection.Environment == DatabaseEnvironment.Production && ConfirmCallback is not null)
        {
            var confirmed = await ConfirmCallback(
                $"確定要將 SERVER.txt 指向「{SelectedConnection.Name}」嗎？",
                $"⚠ 正式環境 (Production)：{SelectedConnection.Database}");
            if (!confirmed)
            {
                StatusMessage = "已取消套用";
                return;
            }
        }

        var successCount = 0;
        var failCount = 0;

        foreach (var file in selectedFiles)
        {
            if (_serverTxtService.Apply(file.Path, SelectedConnection))
                successCount++;
            else
                failCount++;
        }

        if (failCount == 0)
            StatusMessage = $"已成功更新 {successCount} 個檔案";
        else
            StatusMessage = $"完成：{successCount} 個成功，{failCount} 個失敗";

        UpdatePreview();
    }
```

將 `DeleteCustomConnection` 改為 async：

```csharp
    public async Task DeleteCustomConnection(ConnectionProfile profile)
    {
        if (profile.Source != "Custom") return;

        if (profile.Environment == DatabaseEnvironment.Production && ConfirmCallback is not null)
        {
            var confirmed = await ConfirmCallback(
                $"確定要刪除自訂連線「{profile.Name}」嗎？",
                $"⚠ 正式環境 (Production)：{profile.Database}");
            if (!confirmed) return;
        }

        _settingsService.DeleteProfile(profile.Id);
        LoadConnections();
        StatusMessage = $"已刪除自訂連線：{profile.Name}";
    }
```

- [ ] **Step 5: View 接線**

在 `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`：

(a) `OnDeleteConnectionClick` 改為 async：

```csharp
    private async void OnDeleteConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm && vm.SelectedConnection is { Source: "Custom" } profile)
        {
            await vm.DeleteCustomConnection(profile);
        }
    }
```

(b) 在 `OnDataContextChanged`（或 `SetupApplyDevCallback`）內，設定 ConfirmCallback。修改 `SetupApplyDevCallback` 為同時接線：

```csharp
    private void SetupApplyDevCallback(MainWindowViewModel vm)
    {
        vm.ApplyDevDialogCallback = async (files, profile) =>
        {
            var dialog = new ApplyDevDialog(files, profile);
            return await dialog.ShowDialog<IReadOnlyList<string>?>(this);
        };

        vm.ConfirmCallback = async (message, banner) =>
        {
            var dialog = new ConfirmDialog(message, banner);
            return await dialog.ShowDialog<bool>(this);
        };
    }
```

- [ ] **Step 6: 執行測試與建置**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~MainWindowViewModelTests" && dotnet build src/MoldplanDbSwitcher`
Expected: PASS、Build succeeded。

- [ ] **Step 7: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml.cs src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs && git commit -m "feat: 套用連線與刪除自訂連線的 Production 防呆

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 匯入覆蓋的 Production 防呆

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs`（HasProductionOverwrite）
- Modify: `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml(.cs)`（預覽顯示 + 匯入前確認）
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

在 `tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs` 加入（沿用該檔既有的建構與 mock 方式；以下用最小相依直接建立 VM）：

```csharp
    [Fact]
    public void HasProductionOverwrite_有Production覆蓋時為True()
    {
        var existing = new List<ConnectionProfile>
        {
            new() { Id = "1", Name = "prod", Server = "s", Database = "d", Environment = DatabaseEnvironment.Production, Source = "Custom" }
        };
        var vm = new ImportConnectionsViewModel(
            Substitute.For<IConnectionExportService>(), Substitute.For<ISettingsService>(), existing);
        // 直接灌入一筆與既有同名（衝突）且選擇覆蓋的預覽
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
```
（檔頭若缺則補 `using NSubstitute;`、`using MoldplanDbSwitcher.Models;`、`using MoldplanDbSwitcher.Services;`。）

- [ ] **Step 2: 執行測試確認失敗**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ImportConnectionsViewModelTests"`
Expected: 編譯失敗（HasProductionOverwrite 不存在）。

- [ ] **Step 3: 加 HasProductionOverwrite**

在 `src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs` 的 `ExecuteImport` 之前加入：

```csharp
    /// <summary>是否有選擇覆蓋且涉及 Production 環境的項目（供匯入前防呆）。</summary>
    public bool HasProductionOverwrite()
        => ImportPreviews.Any(item =>
            item.HasConflict
            && item.ConflictAction == ConflictAction.Overwrite
            && (item.Profile.Environment == DatabaseEnvironment.Production
                || item.ExistingProfile?.Environment == DatabaseEnvironment.Production));
```
（檔頭已 using System.Linq？若無請補 `using System.Linq;`。）

- [ ] **Step 4: 匯入預覽改用統一顯示 + 匯入前確認**

在 `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml`，將預覽項目的名稱 TextBlock（`<TextBlock Text="{Binding Profile.Name}" FontWeight="SemiBold" />`）改為：

```xml
                        <TextBlock Text="{Binding Profile, Converter={StaticResource ConnectionProfileDisplayConverter}}" FontWeight="SemiBold" />
```

在 `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml.cs` 將 `OnImportClick` 改為 async 並加入 Production 確認：

```csharp
    private async void OnImportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ImportConnectionsViewModel vm) return;

        if (vm.HasProductionOverwrite())
        {
            var confirm = new ConfirmDialog(
                "匯入清單將覆蓋既有的正式環境連線，確定要繼續嗎？",
                "⚠ 此次匯入包含 Production（正式環境）連線的覆蓋");
            var ok = await confirm.ShowDialog<bool>(this);
            if (!ok) return;
        }

        var result = vm.ExecuteImport();
        Close(result);
    }
```

- [ ] **Step 5: 執行測試與建置**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test tests/MoldplanDbSwitcher.Tests --filter "FullyQualifiedName~ImportConnectionsViewModelTests" && dotnet build src/MoldplanDbSwitcher`
Expected: PASS、Build succeeded。

- [ ] **Step 6: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs && git commit -m "feat: 匯入覆蓋 Production 連線時防呆並統一預覽顯示

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 選擇器統一顯示（ComboBox、DataGrid、匯出清單）

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`（連線 ComboBox、DataGrid 環境欄）
- Modify: `src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml`（清單顯示）

UI 變更，無單元測試；以建置確認。轉換器以 `{StaticResource ConnectionProfileDisplayConverter}` / `{StaticResource DatabaseEnvironmentDisplayConverter}` 引用（App 資源）。

- [ ] **Step 1: MainWindow 連線 ComboBox 改用轉換器**

將 `src/MoldplanDbSwitcher/Views/MainWindow.axaml` 的連線 ComboBox ItemTemplate（第 32-42 行）改為：

```xml
        <ComboBox.ItemTemplate>
          <DataTemplate DataType="models:ConnectionProfile">
            <TextBlock Text="{Binding Converter={StaticResource ConnectionProfileDisplayConverter}}" />
          </DataTemplate>
        </ComboBox.ItemTemplate>
```

- [ ] **Step 2: DataGrid 新增「環境」欄**

在 `src/MoldplanDbSwitcher/Views/MainWindow.axaml` 的 DataGrid 欄位中，於「來源」欄之後加入：

```xml
              <DataGridTextColumn Header="環境" Width="90"
                                  Binding="{Binding Environment, Converter={StaticResource DatabaseEnvironmentDisplayConverter}}" />
```

- [ ] **Step 3: 匯出清單改用轉換器**

將 `src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml` 的清單項目（第 37-40 行的 StackPanel 內兩個 TextBlock）改為單一：

```xml
                  <TextBlock Text="{Binding Profile, Converter={StaticResource ConnectionProfileDisplayConverter}}" FontWeight="SemiBold" />
```
（即移除原本的 `Profile.Name` 與 `Profile.Server` 兩行，改為一行轉換器顯示。）

- [ ] **Step 4: 建置確認**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet build src/MoldplanDbSwitcher`
Expected: Build succeeded。

- [ ] **Step 5: Commit**

```bash
cd C:/Users/zihao/source/repos/moldplan-change-database && git add src/MoldplanDbSwitcher/Views/MainWindow.axaml src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml && git commit -m "feat: 連線選擇器與 DataGrid 套用統一環境顯示

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 整體驗證與程式碼審查

**Files:** 無（驗證任務）

- [ ] **Step 1: 完整建置**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet build`
Expected: Build succeeded。

- [ ] **Step 2: 完整測試**

Run: `cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet test`
Expected: 全部通過（含新增 Comparer、Inference、Converters、ConnectionProfile 序列化、ConnectionDialog、MainWindow 排序/Ansible/防呆、Import 防呆測試）。

- [ ] **Step 3: 手動驗證 UI**

執行：`cd C:/Users/zihao/source/repos/moldplan-change-database && dotnet run --project src/MoldplanDbSwitcher`，確認：
- 主視窗連線 ComboBox 與 DataGrid（含「環境」欄）顯示 `【環境】名稱 (預設)`、依 預設→環境→名稱 排序。
- 讀取的 Specurai 連線顯示其真實環境；Ansible 連線依名稱推斷；自訂連線可在 ConnectionDialog 選環境。
- 對 Production 連線按「套用變更」「刪除自訂連線」、以及匯入會覆蓋 Production 連線時，跳出紅色警告橫幅確認；非 Production 無橫幅。
- 匯出/匯入清單顯示統一格式。

- [ ] **Step 4: 程式碼審查**

使用 `superpowers:requesting-code-review` 技能審查本次所有變更，再回報完成。
