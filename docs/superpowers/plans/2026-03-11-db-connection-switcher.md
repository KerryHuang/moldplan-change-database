# 資料庫連線切換工具 實作計畫（TDD）

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立一個 Avalonia 桌面應用程式，讓使用者選擇資料庫連線後，自動替換 WDMIS 目錄下 SERVER.txt 的伺服器位址和資料庫名稱。

**Architecture:** 單一 .NET 9 Avalonia 專案，MVVM 模式。Services 層處理檔案 I/O 和連線設定讀取，ViewModels 層處理 UI 邏輯，Views 層定義 AXAML 介面。使用 Semi.Avalonia 主題與 CommunityToolkit.Mvvm。

**Tech Stack:** .NET 9, Avalonia 11.x, Semi.Avalonia, CommunityToolkit.Mvvm, System.Text.Json, Microsoft.Extensions.DependencyInjection, xUnit, NSubstitute

**Spec:** `docs/superpowers/specs/2026-03-11-db-connection-switcher-design.md`

---

## File Structure

```
src/MoldplanDbSwitcher/
├── MoldplanDbSwitcher.csproj
├── Program.cs
├── App.axaml / App.axaml.cs
├── ViewLocator.cs
├── app.manifest
├── Models/
│   ├── ConnectionProfile.cs
│   └── ServerTxtEntry.cs
├── Services/
│   ├── IConnectionSourceService.cs
│   ├── ConnectionSourceService.cs
│   ├── IServerTxtService.cs
│   ├── ServerTxtService.cs
│   ├── ISettingsService.cs
│   └── SettingsService.cs
├── ViewModels/
│   ├── MainWindowViewModel.cs
│   └── ConnectionDialogViewModel.cs
└── Views/
    ├── MainWindow.axaml / MainWindow.axaml.cs
    └── ConnectionDialog.axaml / ConnectionDialog.axaml.cs

tests/MoldplanDbSwitcher.Tests/
├── MoldplanDbSwitcher.Tests.csproj
├── Models/
│   ├── ServerTxtEntryTests.cs
│   └── ConnectionProfileTests.cs
├── Services/
│   ├── ServerTxtServiceTests.cs
│   ├── SettingsServiceTests.cs
│   └── ConnectionSourceServiceTests.cs
└── ViewModels/
    ├── MainWindowViewModelTests.cs
    └── ConnectionDialogViewModelTests.cs
```

---

## Chunk 1: 專案骨架與 Models（TDD）

### Task 1: 建立專案骨架

**Files:**
- Create: `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
- Create: `src/MoldplanDbSwitcher/app.manifest`
- Create: `tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`

- [ ] **Step 1: 建立專案目錄**

```bash
mkdir -p src/MoldplanDbSwitcher
mkdir -p tests/MoldplanDbSwitcher.Tests
```

- [ ] **Step 2: 建立主專案 .csproj**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <BuiltInComInteropSupport>true</BuiltInComInteropSupport>
    <ApplicationManifest>app.manifest</ApplicationManifest>
    <AvaloniaUseCompiledBindingsByDefault>true</AvaloniaUseCompiledBindingsByDefault>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Avalonia" Version="11.3.11" />
    <PackageReference Include="Avalonia.Desktop" Version="11.3.11" />
    <PackageReference Include="Avalonia.Themes.Fluent" Version="11.3.11" />
    <PackageReference Include="Avalonia.Fonts.Inter" Version="11.3.11" />
    <PackageReference Include="Avalonia.Controls.DataGrid" Version="11.3.11" />
    <PackageReference Include="Semi.Avalonia" Version="11.3.7.2" />
    <PackageReference Include="CommunityToolkit.Mvvm" Version="8.2.1" />
    <PackageReference Include="Microsoft.Extensions.DependencyInjection" Version="9.0.0" />
  </ItemGroup>
</Project>
```

- [ ] **Step 3: 建立 app.manifest**

```xml
<?xml version="1.0" encoding="utf-8"?>
<assembly manifestVersion="1.0" xmlns="urn:schemas-microsoft-com:asm.v1">
  <assemblyIdentity version="1.0.0.0" name="MoldplanDbSwitcher.Desktop"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security>
      <requestedPrivileges xmlns="urn:schemas-microsoft-com:asm.v3">
        <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
      </requestedPrivileges>
    </security>
  </trustInfo>
</assembly>
```

- [ ] **Step 4: 建立測試專案 .csproj**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.12.0" />
    <PackageReference Include="xunit" Version="2.9.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
    <PackageReference Include="NSubstitute" Version="5.3.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\MoldplanDbSwitcher\MoldplanDbSwitcher.csproj" />
  </ItemGroup>
</Project>
```

- [ ] **Step 5: 驗證兩個專案都可還原**

Run: `dotnet restore src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj && dotnet restore tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`
Expected: 成功還原所有套件

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj src/MoldplanDbSwitcher/app.manifest tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj
git commit -m "feat: 建立 MoldplanDbSwitcher 主專案與測試專案骨架"
```

---

### Task 2: ServerTxtEntry 模型（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/Models/ServerTxtEntryTests.cs`
- Create: `src/MoldplanDbSwitcher/Models/ServerTxtEntry.cs`

- [ ] **Step 1: 寫失敗測試 — Parse 正確格式**

```csharp
namespace MoldplanDbSwitcher.Tests.Models;

using MoldplanDbSwitcher.Models;

public class ServerTxtEntryTests
{
    [Fact]
    public void Parse_ValidLine_ReturnsCorrectEntry()
    {
        var entry = ServerTxtEntry.Parse("mis,yuchiun-test,100.73.36.124,XXX,1");

        Assert.Equal("mis", entry.Field1);
        Assert.Equal("yuchiun-test", entry.DatabaseName);
        Assert.Equal("100.73.36.124", entry.ServerAddress);
        Assert.Equal("XXX", entry.Field4);
        Assert.Equal("1", entry.Field5);
    }

    [Fact]
    public void Parse_InvalidLine_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => ServerTxtEntry.Parse("only,two"));
    }

    [Fact]
    public void ToLine_ReturnsCommaSeparated()
    {
        var entry = new ServerTxtEntry
        {
            Field1 = "mis",
            DatabaseName = "yuchiun",
            ServerAddress = "127.0.0.1",
            Field4 = "XXX",
            Field5 = "1"
        };

        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", entry.ToLine());
    }

    [Fact]
    public void Parse_ThenToLine_Roundtrip()
    {
        var original = "mis,yuchiun-test,100.73.36.124,XXX,1";
        var entry = ServerTxtEntry.Parse(original);
        Assert.Equal(original, entry.ToLine());
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtEntryTests"`
Expected: 編譯失敗，找不到 ServerTxtEntry

- [ ] **Step 3: 實作 ServerTxtEntry**

```csharp
namespace MoldplanDbSwitcher.Models;

public class ServerTxtEntry
{
    public string Field1 { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = string.Empty;
    public string ServerAddress { get; set; } = string.Empty;
    public string Field4 { get; set; } = string.Empty;
    public string Field5 { get; set; } = string.Empty;

    public static ServerTxtEntry Parse(string line)
    {
        var parts = line.Split(',');
        if (parts.Length < 5)
            throw new FormatException($"SERVER.txt 格式不正確，預期 5 個欄位但只有 {parts.Length} 個: {line}");

        return new ServerTxtEntry
        {
            Field1 = parts[0],
            DatabaseName = parts[1],
            ServerAddress = parts[2],
            Field4 = parts[3],
            Field5 = parts[4]
        };
    }

    public string ToLine() => $"{Field1},{DatabaseName},{ServerAddress},{Field4},{Field5}";
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtEntryTests"`
Expected: 4 tests passed

- [ ] **Step 5: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Models/ServerTxtEntryTests.cs src/MoldplanDbSwitcher/Models/ServerTxtEntry.cs
git commit -m "feat: 新增 ServerTxtEntry 模型（含解析與序列化）"
```

---

### Task 3: ConnectionProfile 模型

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs`
- Create: `src/MoldplanDbSwitcher/Models/ConnectionProfile.cs`

- [ ] **Step 1: 寫失敗測試 — JSON 序列化/反序列化**

```csharp
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionProfileTests
{
    [Fact]
    public void Deserialize_TableSpecFormat_ReadsCorrectly()
    {
        var json = """
        {
            "profiles": [
                {
                    "id": "test-id",
                    "name": "dev",
                    "server": "127.0.0.1",
                    "database": "mis",
                    "authType": 0,
                    "username": "",
                    "password": "",
                    "isDefault": true
                }
            ],
            "currentProfileId": "test-id"
        }
        """;

        var data = JsonSerializer.Deserialize<ConnectionsFile>(json);

        Assert.NotNull(data);
        Assert.Single(data.Profiles);
        Assert.Equal("dev", data.Profiles[0].Name);
        Assert.Equal("127.0.0.1", data.Profiles[0].Server);
        Assert.Equal("mis", data.Profiles[0].Database);
        Assert.Equal("test-id", data.CurrentProfileId);
    }

    [Fact]
    public void Source_IsJsonIgnored()
    {
        var profile = new ConnectionProfile { Name = "test", Source = "TableSpec" };
        var json = JsonSerializer.Serialize(profile);
        Assert.DoesNotContain("Source", json);
        Assert.DoesNotContain("TableSpec", json);
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProfileTests"`
Expected: 編譯失敗

- [ ] **Step 3: 實作 ConnectionProfile 與 ConnectionsFile**

```csharp
using System.Text.Json.Serialization;

namespace MoldplanDbSwitcher.Models;

public class ConnectionProfile
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("server")]
    public string Server { get; set; } = string.Empty;

    [JsonPropertyName("database")]
    public string Database { get; set; } = string.Empty;

    [JsonIgnore]
    public string Source { get; set; } = "Custom";
}

public class ConnectionsFile
{
    [JsonPropertyName("profiles")]
    public List<ConnectionProfile> Profiles { get; set; } = [];

    [JsonPropertyName("currentProfileId")]
    public string? CurrentProfileId { get; set; }
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProfileTests"`
Expected: 2 tests passed

- [ ] **Step 5: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs src/MoldplanDbSwitcher/Models/ConnectionProfile.cs
git commit -m "feat: 新增 ConnectionProfile 與 ConnectionsFile 模型"
```

---

## Chunk 2: Services（TDD）

### Task 4: SettingsService（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/Services/SettingsServiceTests.cs`
- Create: `src/MoldplanDbSwitcher/Services/ISettingsService.cs`
- Create: `src/MoldplanDbSwitcher/Services/SettingsService.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class SettingsServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly SettingsService _service;

    public SettingsServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "MoldplanDbSwitcherTest_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDir);
        _service = new SettingsService(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void LoadProfiles_NoFile_ReturnsEmpty()
    {
        var profiles = _service.LoadProfiles();
        Assert.Empty(profiles);
    }

    [Fact]
    public void AddProfile_ThenLoad_ReturnsSavedProfile()
    {
        var profile = new ConnectionProfile
        {
            Name = "test",
            Server = "127.0.0.1",
            Database = "mis"
        };

        _service.AddProfile(profile);
        var loaded = _service.LoadProfiles();

        Assert.Single(loaded);
        Assert.Equal("test", loaded[0].Name);
        Assert.Equal("127.0.0.1", loaded[0].Server);
        Assert.Equal("mis", loaded[0].Database);
    }

    [Fact]
    public void DeleteProfile_RemovesCorrectProfile()
    {
        var p1 = new ConnectionProfile { Id = "id1", Name = "one" };
        var p2 = new ConnectionProfile { Id = "id2", Name = "two" };

        _service.AddProfile(p1);
        _service.AddProfile(p2);
        _service.DeleteProfile("id1");

        var loaded = _service.LoadProfiles();
        Assert.Single(loaded);
        Assert.Equal("two", loaded[0].Name);
    }

    [Fact]
    public void UpdateProfile_ModifiesExisting()
    {
        var profile = new ConnectionProfile { Id = "id1", Name = "old", Server = "1.1.1.1", Database = "db1" };
        _service.AddProfile(profile);

        profile.Name = "new";
        profile.Server = "2.2.2.2";
        _service.UpdateProfile(profile);

        var loaded = _service.LoadProfiles();
        Assert.Single(loaded);
        Assert.Equal("new", loaded[0].Name);
        Assert.Equal("2.2.2.2", loaded[0].Server);
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SettingsServiceTests"`
Expected: 編譯失敗

- [ ] **Step 3: 建立 ISettingsService**

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface ISettingsService
{
    List<ConnectionProfile> LoadProfiles();
    void SaveProfiles(List<ConnectionProfile> profiles);
    void AddProfile(ConnectionProfile profile);
    void UpdateProfile(ConnectionProfile profile);
    void DeleteProfile(string id);
}
```

- [ ] **Step 4: 實作 SettingsService（支援可注入路徑以便測試）**

```csharp
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SettingsService : ISettingsService
{
    private readonly string _configPath;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public SettingsService() : this(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "MoldplanDbSwitcher"))
    {
    }

    public SettingsService(string configDir)
    {
        Directory.CreateDirectory(configDir);
        _configPath = Path.Combine(configDir, "connections.json");
    }

    public List<ConnectionProfile> LoadProfiles()
    {
        if (!File.Exists(_configPath))
            return [];

        try
        {
            var json = File.ReadAllText(_configPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json, JsonOptions);
            return data?.Profiles ?? [];
        }
        catch
        {
            return [];
        }
    }

    public void SaveProfiles(List<ConnectionProfile> profiles)
    {
        var data = new ConnectionsFile { Profiles = profiles };
        var json = JsonSerializer.Serialize(data, JsonOptions);
        File.WriteAllText(_configPath, json);
    }

    public void AddProfile(ConnectionProfile profile)
    {
        var profiles = LoadProfiles();
        profiles.Add(profile);
        SaveProfiles(profiles);
    }

    public void UpdateProfile(ConnectionProfile profile)
    {
        var profiles = LoadProfiles();
        var index = profiles.FindIndex(p => p.Id == profile.Id);
        if (index >= 0)
        {
            profiles[index] = profile;
            SaveProfiles(profiles);
        }
    }

    public void DeleteProfile(string id)
    {
        var profiles = LoadProfiles();
        profiles.RemoveAll(p => p.Id == id);
        SaveProfiles(profiles);
    }
}
```

- [ ] **Step 5: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SettingsServiceTests"`
Expected: 4 tests passed

- [ ] **Step 6: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Services/SettingsServiceTests.cs src/MoldplanDbSwitcher/Services/ISettingsService.cs src/MoldplanDbSwitcher/Services/SettingsService.cs
git commit -m "feat: 新增 SettingsService 自訂連線管理（TDD）"
```

---

### Task 5: ServerTxtService（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ServerTxtServiceTests.cs`
- Create: `src/MoldplanDbSwitcher/Services/IServerTxtService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ServerTxtService.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ServerTxtServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly ServerTxtService _service;

    public ServerTxtServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "ServerTxtTest_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDir);
        _service = new ServerTxtService([Path.Combine(_tempDir, "SERVER.txt")]);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void DiscoverPaths_NoFile_ReturnsEmpty()
    {
        Assert.Empty(_service.DiscoverPaths());
    }

    [Fact]
    public void DiscoverPaths_FileExists_ReturnsPath()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,db,server,x,1");

        var result = _service.DiscoverPaths();
        Assert.Single(result);
        Assert.Equal(path, result[0]);
    }

    [Fact]
    public void ReadEntry_ValidFile_ReturnsEntry()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,yuchiun-test,100.73.36.124,XXX,1");

        var entry = _service.ReadEntry(path);

        Assert.NotNull(entry);
        Assert.Equal("yuchiun-test", entry.DatabaseName);
        Assert.Equal("100.73.36.124", entry.ServerAddress);
    }

    [Fact]
    public void Preview_ReturnsModifiedLine()
    {
        var original = new ServerTxtEntry
        {
            Field1 = "mis",
            DatabaseName = "yuchiun-test",
            ServerAddress = "100.73.36.124",
            Field4 = "XXX",
            Field5 = "1"
        };
        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "yuchiun" };

        var result = _service.Preview(original, target);
        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", result);
    }

    [Fact]
    public void Apply_WritesModifiedContent()
    {
        var path = Path.Combine(_tempDir, "SERVER.txt");
        File.WriteAllText(path, "mis,yuchiun-test,100.73.36.124,XXX,1");

        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "yuchiun" };
        var result = _service.Apply(path, target);

        Assert.True(result);
        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", File.ReadAllText(path));
    }

    [Fact]
    public void Apply_NonExistentFile_ReturnsFalse()
    {
        var target = new ConnectionProfile { Server = "127.0.0.1", Database = "db" };
        var result = _service.Apply(Path.Combine(_tempDir, "nope.txt"), target);
        Assert.False(result);
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtServiceTests"`
Expected: 編譯失敗

- [ ] **Step 3: 建立 IServerTxtService**

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IServerTxtService
{
    List<string> DiscoverPaths();
    ServerTxtEntry? ReadEntry(string path);
    string Preview(ServerTxtEntry original, ConnectionProfile target);
    bool Apply(string path, ConnectionProfile target);
}
```

- [ ] **Step 4: 實作 ServerTxtService（支援可注入搜尋路徑以便測試）**

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ServerTxtService : IServerTxtService
{
    private readonly string[] _searchPaths;

    public ServerTxtService() : this([
        @"C:\WDMIS\SERVER.txt",
        @"D:\WDMIS\SERVER.txt"
    ])
    {
    }

    public ServerTxtService(string[] searchPaths)
    {
        _searchPaths = searchPaths;
    }

    public List<string> DiscoverPaths()
    {
        return _searchPaths.Where(File.Exists).ToList();
    }

    public ServerTxtEntry? ReadEntry(string path)
    {
        try
        {
            var line = File.ReadAllText(path).Trim();
            return ServerTxtEntry.Parse(line);
        }
        catch
        {
            return null;
        }
    }

    public string Preview(ServerTxtEntry original, ConnectionProfile target)
    {
        var modified = new ServerTxtEntry
        {
            Field1 = original.Field1,
            DatabaseName = target.Database,
            ServerAddress = target.Server,
            Field4 = original.Field4,
            Field5 = original.Field5
        };
        return modified.ToLine();
    }

    public bool Apply(string path, ConnectionProfile target)
    {
        try
        {
            var entry = ReadEntry(path);
            if (entry is null) return false;

            entry.DatabaseName = target.Database;
            entry.ServerAddress = target.Server;
            File.WriteAllText(path, entry.ToLine());
            return true;
        }
        catch
        {
            return false;
        }
    }
}
```

- [ ] **Step 5: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtServiceTests"`
Expected: 6 tests passed

- [ ] **Step 6: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Services/ServerTxtServiceTests.cs src/MoldplanDbSwitcher/Services/IServerTxtService.cs src/MoldplanDbSwitcher/Services/ServerTxtService.cs
git commit -m "feat: 新增 ServerTxtService 搜尋與替換（TDD）"
```

---

### Task 6: ConnectionSourceService（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionSourceServiceTests.cs`
- Create: `src/MoldplanDbSwitcher/Services/IConnectionSourceService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ConnectionSourceService.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionSourceServiceTests
{
    private readonly ISettingsService _settingsService;
    private readonly ConnectionSourceService _service;

    public ConnectionSourceServiceTests()
    {
        _settingsService = Substitute.For<ISettingsService>();
        // 使用不存在的 TableSpec 路徑來測試
        _service = new ConnectionSourceService(_settingsService, Path.Combine(Path.GetTempPath(), "nonexistent", "connections.json"));
    }

    [Fact]
    public void LoadTableSpecConnections_NoFile_ReturnsEmpty()
    {
        var result = _service.LoadTableSpecConnections();
        Assert.Empty(result);
    }

    [Fact]
    public void LoadCustomConnections_ReturnsFromSettingsService()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "custom1", Server = "1.1.1.1", Database = "db1" }
        };
        _settingsService.LoadProfiles().Returns(profiles);

        var result = _service.LoadCustomConnections();

        Assert.Single(result);
        Assert.Equal("Custom", result[0].Source);
    }

    [Fact]
    public void LoadAllConnections_CombinesBothSources()
    {
        _settingsService.LoadProfiles().Returns(new List<ConnectionProfile>
        {
            new() { Name = "custom1" }
        });

        var result = _service.LoadAllConnections();

        // TableSpec 檔案不存在，只有 custom
        Assert.Single(result);
    }

    [Fact]
    public void LoadTableSpecConnections_ValidFile_SetsSourceToTableSpec()
    {
        // 建立臨時 TableSpec 檔案
        var tempDir = Path.Combine(Path.GetTempPath(), "TableSpecTest_" + Guid.NewGuid());
        Directory.CreateDirectory(tempDir);
        var tempPath = Path.Combine(tempDir, "connections.json");
        File.WriteAllText(tempPath, """
        {
            "profiles": [
                { "id": "1", "name": "dev", "server": "127.0.0.1", "database": "mis" }
            ]
        }
        """);

        try
        {
            var service = new ConnectionSourceService(_settingsService, tempPath);
            var result = service.LoadTableSpecConnections();

            Assert.Single(result);
            Assert.Equal("TableSpec", result[0].Source);
            Assert.Equal("dev", result[0].Name);
        }
        finally
        {
            Directory.Delete(tempDir, true);
        }
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionSourceServiceTests"`
Expected: 編譯失敗

- [ ] **Step 3: 建立 IConnectionSourceService**

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionSourceService
{
    List<ConnectionProfile> LoadTableSpecConnections();
    List<ConnectionProfile> LoadCustomConnections();
    List<ConnectionProfile> LoadAllConnections();
}
```

- [ ] **Step 4: 實作 ConnectionSourceService（支援可注入 TableSpec 路徑）**

```csharp
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionSourceService : IConnectionSourceService
{
    private readonly ISettingsService _settingsService;
    private readonly string _tableSpecPath;

    public ConnectionSourceService(ISettingsService settingsService)
        : this(settingsService, Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "TableSpec",
            "connections.json"))
    {
    }

    public ConnectionSourceService(ISettingsService settingsService, string tableSpecPath)
    {
        _settingsService = settingsService;
        _tableSpecPath = tableSpecPath;
    }

    public List<ConnectionProfile> LoadTableSpecConnections()
    {
        if (!File.Exists(_tableSpecPath))
            return [];

        try
        {
            var json = File.ReadAllText(_tableSpecPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json);
            if (data?.Profiles is null) return [];

            foreach (var p in data.Profiles)
                p.Source = "TableSpec";

            return data.Profiles;
        }
        catch
        {
            return [];
        }
    }

    public List<ConnectionProfile> LoadCustomConnections()
    {
        var profiles = _settingsService.LoadProfiles();
        foreach (var p in profiles)
            p.Source = "Custom";
        return profiles;
    }

    public List<ConnectionProfile> LoadAllConnections()
    {
        var all = new List<ConnectionProfile>();
        all.AddRange(LoadTableSpecConnections());
        all.AddRange(LoadCustomConnections());
        return all;
    }
}
```

- [ ] **Step 5: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionSourceServiceTests"`
Expected: 4 tests passed

- [ ] **Step 6: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Services/ConnectionSourceServiceTests.cs src/MoldplanDbSwitcher/Services/IConnectionSourceService.cs src/MoldplanDbSwitcher/Services/ConnectionSourceService.cs
git commit -m "feat: 新增 ConnectionSourceService 連線來源管理（TDD）"
```

---

## Chunk 3: ViewModels（TDD）

### Task 7: MainWindowViewModel（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`
- Create: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MainWindowViewModelTests
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IServerTxtService _serverTxtService;
    private readonly ISettingsService _settingsService;

    public MainWindowViewModelTests()
    {
        _connectionSource = Substitute.For<IConnectionSourceService>();
        _serverTxtService = Substitute.For<IServerTxtService>();
        _settingsService = Substitute.For<ISettingsService>();

        _connectionSource.LoadTableSpecConnections().Returns(new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Source = "TableSpec" }
        });
        _connectionSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());
        _serverTxtService.DiscoverPaths().Returns(new List<string>());
    }

    private MainWindowViewModel CreateVm() => new(_connectionSource, _serverTxtService, _settingsService);

    [Fact]
    public void Constructor_LoadsConnections()
    {
        var vm = CreateVm();
        Assert.Single(vm.Connections);
        Assert.Equal("dev", vm.Connections[0].Name);
    }

    [Fact]
    public void Constructor_SetsFirstConnectionAsSelected()
    {
        var vm = CreateVm();
        Assert.NotNull(vm.SelectedConnection);
        Assert.Equal("dev", vm.SelectedConnection!.Name);
    }

    [Fact]
    public void ApplyChanges_NoSelection_SetsErrorStatus()
    {
        _connectionSource.LoadTableSpecConnections().Returns(new List<ConnectionProfile>());
        var vm = CreateVm();
        vm.SelectedConnection = null;

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請先選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_NoServerTxtSelected_SetsErrorStatus()
    {
        var vm = CreateVm();

        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("請至少選擇", vm.StatusMessage);
    }

    [Fact]
    public void ApplyChanges_Success_SetsSuccessStatus()
    {
        _serverTxtService.DiscoverPaths().Returns(new List<string> { @"C:\WDMIS\SERVER.txt" });
        _serverTxtService.Apply(Arg.Any<string>(), Arg.Any<ConnectionProfile>()).Returns(true);
        _serverTxtService.ReadEntry(Arg.Any<string>()).Returns(new ServerTxtEntry
        {
            Field1 = "mis", DatabaseName = "old", ServerAddress = "0.0.0.0", Field4 = "X", Field5 = "1"
        });

        var vm = CreateVm();
        vm.ApplyChangesCommand.Execute(null);

        Assert.Contains("成功", vm.StatusMessage);
    }

    [Fact]
    public void AddCustomConnection_AddsAndReloads()
    {
        var vm = CreateVm();
        vm.AddCustomConnection("new", "10.0.0.1", "testdb");

        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(
            p => p.Name == "new" && p.Server == "10.0.0.1" && p.Database == "testdb"));
    }

    [Fact]
    public void DeleteCustomConnection_OnlyDeletesCustomSource()
    {
        var vm = CreateVm();
        var tableSpecProfile = new ConnectionProfile { Id = "1", Name = "dev", Source = "TableSpec" };

        vm.DeleteCustomConnection(tableSpecProfile);

        _settingsService.DidNotReceive().DeleteProfile(Arg.Any<string>());
    }

    [Fact]
    public void ShowTableSpec_False_FiltersOutTableSpec()
    {
        var vm = CreateVm();
        vm.ShowTableSpec = false;

        _connectionSource.DidNotReceive().LoadTableSpecConnections();
        // 在 ShowTableSpec 改為 false 後，LoadConnections 會被呼叫
        // 但不會呼叫 LoadTableSpecConnections
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests"`
Expected: 編譯失敗

- [ ] **Step 3: 實作 MainWindowViewModel**

```csharp
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IServerTxtService _serverTxtService;
    private readonly ISettingsService _settingsService;

    [ObservableProperty]
    private ObservableCollection<ConnectionProfile> _connections = [];

    [ObservableProperty]
    private ConnectionProfile? _selectedConnection;

    [ObservableProperty]
    private ObservableCollection<ServerTxtFileItem> _serverTxtFiles = [];

    [ObservableProperty]
    private string _previewBefore = string.Empty;

    [ObservableProperty]
    private string _previewAfter = string.Empty;

    [ObservableProperty]
    private string _statusMessage = string.Empty;

    [ObservableProperty]
    private bool _showTableSpec = true;

    [ObservableProperty]
    private bool _showCustom = true;

    public MainWindowViewModel(
        IConnectionSourceService connectionSource,
        IServerTxtService serverTxtService,
        ISettingsService settingsService)
    {
        _connectionSource = connectionSource;
        _serverTxtService = serverTxtService;
        _settingsService = settingsService;

        LoadConnections();
        DiscoverServerTxtFiles();
    }

    partial void OnSelectedConnectionChanged(ConnectionProfile? value)
    {
        UpdatePreview();
    }

    partial void OnShowTableSpecChanged(bool value) => LoadConnections();
    partial void OnShowCustomChanged(bool value) => LoadConnections();

    [RelayCommand]
    private void LoadConnections()
    {
        var all = new List<ConnectionProfile>();
        if (ShowTableSpec)
            all.AddRange(_connectionSource.LoadTableSpecConnections());
        if (ShowCustom)
            all.AddRange(_connectionSource.LoadCustomConnections());

        Connections = new ObservableCollection<ConnectionProfile>(all);
        SelectedConnection = Connections.FirstOrDefault();
    }

    [RelayCommand]
    private void DiscoverServerTxtFiles()
    {
        var paths = _serverTxtService.DiscoverPaths();
        ServerTxtFiles = new ObservableCollection<ServerTxtFileItem>(
            paths.Select(p => new ServerTxtFileItem { Path = p, IsSelected = true }));

        if (paths.Count == 0)
            StatusMessage = "找不到 SERVER.txt 檔案";

        UpdatePreview();
    }

    private void UpdatePreview()
    {
        if (SelectedConnection is null || ServerTxtFiles.Count == 0)
        {
            PreviewBefore = string.Empty;
            PreviewAfter = string.Empty;
            return;
        }

        var firstSelected = ServerTxtFiles.FirstOrDefault(f => f.IsSelected);
        if (firstSelected is null) return;

        var entry = _serverTxtService.ReadEntry(firstSelected.Path);
        if (entry is null) return;

        PreviewBefore = entry.ToLine();
        PreviewAfter = _serverTxtService.Preview(entry, SelectedConnection);
    }

    [RelayCommand]
    private void ApplyChanges()
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

    [RelayCommand]
    private void RefreshAll()
    {
        LoadConnections();
        DiscoverServerTxtFiles();
        StatusMessage = "已重新整理";
    }

    public void AddCustomConnection(string name, string server, string database)
    {
        var profile = new ConnectionProfile
        {
            Name = name,
            Server = server,
            Database = database
        };
        _settingsService.AddProfile(profile);
        LoadConnections();
        StatusMessage = $"已新增自訂連線：{name}";
    }

    public void DeleteCustomConnection(ConnectionProfile profile)
    {
        if (profile.Source != "Custom") return;
        _settingsService.DeleteProfile(profile.Id);
        LoadConnections();
        StatusMessage = $"已刪除自訂連線：{profile.Name}";
    }
}

public partial class ServerTxtFileItem : ObservableObject
{
    [ObservableProperty]
    private string _path = string.Empty;

    [ObservableProperty]
    private bool _isSelected;
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests"`
Expected: 8 tests passed

- [ ] **Step 5: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs
git commit -m "feat: 新增 MainWindowViewModel（TDD）"
```

---

### Task 8: ConnectionDialogViewModel（TDD）

**Files:**
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionDialogViewModelTests.cs`
- Create: `src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ConnectionDialogViewModelTests
{
    [Fact]
    public void IsValid_AllFieldsFilled_ReturnsTrue()
    {
        var vm = new ConnectionDialogViewModel
        {
            Name = "test",
            Server = "127.0.0.1",
            Database = "mis"
        };
        Assert.True(vm.IsValid);
    }

    [Theory]
    [InlineData("", "127.0.0.1", "mis")]
    [InlineData("test", "", "mis")]
    [InlineData("test", "127.0.0.1", "")]
    [InlineData("  ", "127.0.0.1", "mis")]
    public void IsValid_MissingField_ReturnsFalse(string name, string server, string database)
    {
        var vm = new ConnectionDialogViewModel
        {
            Name = name,
            Server = server,
            Database = database
        };
        Assert.False(vm.IsValid);
    }
}
```

- [ ] **Step 2: 執行測試，確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionDialogViewModelTests"`
Expected: 編譯失敗

- [ ] **Step 3: 實作 ConnectionDialogViewModel**

```csharp
using CommunityToolkit.Mvvm.ComponentModel;

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

    public bool IsValid => !string.IsNullOrWhiteSpace(Name)
                        && !string.IsNullOrWhiteSpace(Server)
                        && !string.IsNullOrWhiteSpace(Database);
}
```

- [ ] **Step 4: 執行測試，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionDialogViewModelTests"`
Expected: 5 tests passed

- [ ] **Step 5: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/ViewModels/ConnectionDialogViewModelTests.cs src/MoldplanDbSwitcher/ViewModels/ConnectionDialogViewModel.cs
git commit -m "feat: 新增 ConnectionDialogViewModel（TDD）"
```

---

## Chunk 4: Views 與應用程式進入點

### Task 9: 建立 Avalonia 應用程式進入點

**Files:**
- Create: `src/MoldplanDbSwitcher/App.axaml`
- Create: `src/MoldplanDbSwitcher/App.axaml.cs`
- Create: `src/MoldplanDbSwitcher/Program.cs`
- Create: `src/MoldplanDbSwitcher/ViewLocator.cs`

- [ ] **Step 1: 建立 App.axaml**

```xml
<Application xmlns="https://github.com/avaloniaui"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:local="using:MoldplanDbSwitcher"
             x:Class="MoldplanDbSwitcher.App"
             RequestedThemeVariant="Default">
  <Application.DataTemplates>
    <local:ViewLocator />
  </Application.DataTemplates>
  <Application.Styles>
    <StyleInclude Source="avares://Semi.Avalonia/Themes/Index.axaml" />
    <StyleInclude Source="avares://Avalonia.Controls.DataGrid/Themes/Fluent.xaml" />
  </Application.Styles>
</Application>
```

- [ ] **Step 2: 建立 App.axaml.cs**

```csharp
using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using MoldplanDbSwitcher.ViewModels;
using MoldplanDbSwitcher.Views;
using Microsoft.Extensions.DependencyInjection;

namespace MoldplanDbSwitcher;

public class App : Application
{
    public static IServiceProvider Services { get; set; } = null!;

    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new MainWindow
            {
                DataContext = Services.GetRequiredService<MainWindowViewModel>()
            };
        }

        base.OnFrameworkInitializationCompleted();
    }
}
```

- [ ] **Step 3: 建立 Program.cs**

```csharp
using Avalonia;
using Microsoft.Extensions.DependencyInjection;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher;

class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        var services = new ServiceCollection();
        ConfigureServices(services);
        App.Services = services.BuildServiceProvider();

        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
    }

    private static void ConfigureServices(IServiceCollection services)
    {
        services.AddSingleton<ISettingsService, SettingsService>();
        services.AddSingleton<IConnectionSourceService, ConnectionSourceService>();
        services.AddSingleton<IServerTxtService, ServerTxtService>();
        services.AddTransient<MainWindowViewModel>();
    }

    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
}
```

- [ ] **Step 4: 建立 ViewLocator.cs**

```csharp
using Avalonia.Controls;
using Avalonia.Controls.Templates;
using CommunityToolkit.Mvvm.ComponentModel;

namespace MoldplanDbSwitcher;

public class ViewLocator : IDataTemplate
{
    public Control? Build(object? data)
    {
        if (data is null) return null;

        var name = data.GetType().FullName!
            .Replace("ViewModel", "View", StringComparison.Ordinal);
        var type = Type.GetType(name);

        if (type != null)
            return (Control)Activator.CreateInstance(type)!;

        return new TextBlock { Text = "Not Found: " + name };
    }

    public bool Match(object? data)
    {
        return data is ObservableObject;
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/App.axaml src/MoldplanDbSwitcher/App.axaml.cs src/MoldplanDbSwitcher/Program.cs src/MoldplanDbSwitcher/ViewLocator.cs
git commit -m "feat: 新增應用程式進入點、DI 設定與 ViewLocator"
```

---

### Task 10: 建立 Views

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Create: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`
- Create: `src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ConnectionDialog.axaml.cs`

- [ ] **Step 1: 建立 MainWindow.axaml**

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.MainWindow"
        x:DataType="vm:MainWindowViewModel"
        Title="資料庫連線切換工具"
        Width="650" Height="580"
        WindowStartupLocation="CenterScreen">

  <DockPanel Margin="16">

    <!-- 頂部：連線來源篩選 -->
    <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="16" Margin="0,0,0,12">
      <TextBlock Text="連線來源：" VerticalAlignment="Center" />
      <CheckBox Content="TableSpec" IsChecked="{Binding ShowTableSpec}" />
      <CheckBox Content="自訂" IsChecked="{Binding ShowCustom}" />
      <Button Content="重新整理" Command="{Binding RefreshAllCommand}" Margin="16,0,0,0" />
    </StackPanel>

    <!-- 底部：狀態列與操作按鈕 -->
    <StackPanel DockPanel.Dock="Bottom" Spacing="8">
      <!-- 變更前後對比 -->
      <Border BorderBrush="Gray" BorderThickness="1" CornerRadius="4" Padding="8"
              IsVisible="{Binding PreviewBefore, Converter={x:Static StringConverters.IsNotNullOrEmpty}}">
        <StackPanel Spacing="4">
          <TextBlock Text="變更前後對比" FontWeight="Bold" />
          <StackPanel Orientation="Horizontal" Spacing="4">
            <TextBlock Text="變更前:" Foreground="Gray" />
            <TextBlock Text="{Binding PreviewBefore}" />
          </StackPanel>
          <StackPanel Orientation="Horizontal" Spacing="4">
            <TextBlock Text="變更後:" Foreground="Green" />
            <TextBlock Text="{Binding PreviewAfter}" />
          </StackPanel>
        </StackPanel>
      </Border>

      <!-- 操作按鈕 -->
      <StackPanel Orientation="Horizontal" Spacing="8">
        <Button Content="套用變更" Command="{Binding ApplyChangesCommand}"
                Classes="accent" HorizontalAlignment="Left" />
        <Button Content="新增自訂連線" Click="OnAddConnectionClick"
                HorizontalAlignment="Left" />
        <Button Content="刪除自訂連線" Click="OnDeleteConnectionClick"
                HorizontalAlignment="Left" />
      </StackPanel>

      <!-- 狀態訊息 -->
      <TextBlock Text="{Binding StatusMessage}" Margin="0,4,0,0"
                 IsVisible="{Binding StatusMessage, Converter={x:Static StringConverters.IsNotNullOrEmpty}}" />
    </StackPanel>

    <!-- 中間：連線清單 + SERVER.txt 選擇 -->
    <DockPanel>
      <!-- SERVER.txt 選擇 -->
      <StackPanel DockPanel.Dock="Bottom" Margin="0,12,0,8">
        <TextBlock Text="SERVER.txt 位置：" FontWeight="Bold" Margin="0,0,0,4" />
        <ItemsControl ItemsSource="{Binding ServerTxtFiles}">
          <ItemsControl.ItemTemplate>
            <DataTemplate x:DataType="vm:ServerTxtFileItem">
              <CheckBox Content="{Binding Path}" IsChecked="{Binding IsSelected}" />
            </DataTemplate>
          </ItemsControl.ItemTemplate>
        </ItemsControl>
        <TextBlock Text="找不到 SERVER.txt 檔案"
                   IsVisible="{Binding !ServerTxtFiles.Count}"
                   Foreground="Orange" Margin="0,4,0,0" />
      </StackPanel>

      <!-- 連線清單 DataGrid -->
      <DataGrid ItemsSource="{Binding Connections}"
                SelectedItem="{Binding SelectedConnection}"
                AutoGenerateColumns="False"
                IsReadOnly="True"
                SelectionMode="Single"
                GridLinesVisibility="Horizontal"
                CanUserResizeColumns="True">
        <DataGrid.Columns>
          <DataGridTextColumn Header="來源" Binding="{Binding Source}" Width="80" />
          <DataGridTextColumn Header="名稱" Binding="{Binding Name}" Width="*" />
          <DataGridTextColumn Header="伺服器" Binding="{Binding Server}" Width="*" />
          <DataGridTextColumn Header="資料庫" Binding="{Binding Database}" Width="*" />
        </DataGrid.Columns>
      </DataGrid>
    </DockPanel>

  </DockPanel>
</Window>
```

- [ ] **Step 2: 建立 MainWindow.axaml.cs**

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private async void OnAddConnectionClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new ConnectionDialog();
        var result = await dialog.ShowDialog<ConnectionDialogViewModel?>(this);
        if (result is not null && DataContext is MainWindowViewModel vm)
        {
            vm.AddCustomConnection(result.Name, result.Server, result.Database);
        }
    }

    private void OnDeleteConnectionClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm && vm.SelectedConnection is { Source: "Custom" } profile)
        {
            vm.DeleteCustomConnection(profile);
        }
    }
}
```

- [ ] **Step 3: 建立 ConnectionDialog.axaml**

```xml
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.ConnectionDialog"
        x:DataType="vm:ConnectionDialogViewModel"
        Title="新增自訂連線"
        Width="400" Height="280"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <StackPanel Margin="20" Spacing="12">
    <TextBlock Text="{Binding DialogTitle}" FontSize="16" FontWeight="Bold" />

    <StackPanel Spacing="4">
      <TextBlock Text="名稱" />
      <TextBox Text="{Binding Name}" Watermark="例如：production" />
    </StackPanel>

    <StackPanel Spacing="4">
      <TextBlock Text="伺服器位址" />
      <TextBox Text="{Binding Server}" Watermark="例如：127.0.0.1" />
    </StackPanel>

    <StackPanel Spacing="4">
      <TextBlock Text="資料庫名稱" />
      <TextBox Text="{Binding Database}" Watermark="例如：mis" />
    </StackPanel>

    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Spacing="8" Margin="0,8,0,0">
      <Button Content="取消" Click="OnCancelClick" />
      <Button Content="確定" Click="OnConfirmClick" Classes="accent" />
    </StackPanel>
  </StackPanel>
</Window>
```

- [ ] **Step 4: 建立 ConnectionDialog.axaml.cs**

```csharp
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ConnectionDialog : Window
{
    public ConnectionDialog()
    {
        InitializeComponent();
        DataContext = new ConnectionDialogViewModel();
    }

    private void OnConfirmClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ConnectionDialogViewModel vm && vm.IsValid)
        {
            Close(vm);
        }
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}
```

- [ ] **Step 5: 驗證整個專案可編譯**

Run: `dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: Build succeeded

- [ ] **Step 6: 執行全部測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: All tests passed

- [ ] **Step 7: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/
git commit -m "feat: 新增主視窗與連線對話框 Views"
```

---

### Task 11: 最終驗證

- [ ] **Step 1: 執行全部測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ -v normal`
Expected: 所有測試通過（約 29 個測試）

- [ ] **Step 2: 執行應用程式**

Run: `dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: 視窗啟動，顯示主介面

- [ ] **Step 3: 手動驗證功能**

驗證清單：
1. 連線清單是否正確載入 TableSpec 設定
2. 勾選方塊篩選 TableSpec / 自訂連線是否正常
3. SERVER.txt 搜尋結果是否正確
4. 選擇連線後變更前後對比是否正確
5. 新增自訂連線對話框是否正常開啟與儲存
6. 套用變更是否正確寫入 SERVER.txt
7. 刪除自訂連線是否正常

- [ ] **Step 4: 最終 Commit**

```bash
git add -A
git commit -m "feat: 完成資料庫連線切換工具 v1.0（TDD）"
```
