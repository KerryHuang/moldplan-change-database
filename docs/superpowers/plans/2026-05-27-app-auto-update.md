# App 更新提醒 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App 啟動時透過 GitHub Releases API 查最新版本，若高於目前版本則在主視窗顯示提醒列，使用者點「下載新版」開瀏覽器到 release 頁。

**Architecture:** Interface-first Service (`IUpdateCheckService`) + DI 注入 `HttpClient`，靜音失敗。`MainWindowViewModel` 在 ctor 結尾 fire-and-forget 觸發檢查，結果 set ObservableProperty 驅動 banner UI。GitHub PAT 由使用者在 SettingsDialog 自填，存入既有 `AppSettings`。

**Tech Stack:** .NET 9 / Avalonia 11.3 / `System.Net.Http.HttpClient` / `System.Text.Json` / xUnit + NSubstitute

**Reference spec:** `docs/superpowers/specs/2026-05-27-app-auto-update-design.md`

---

## 檔案結構

### 新增

| 路徑 | 職責 |
|---|---|
| `src/MoldplanDbSwitcher/Models/UpdateInfo.cs` | `UpdateInfo` record |
| `src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs` | 介面 |
| `src/MoldplanDbSwitcher/Services/UpdateCheckService.cs` | GitHub API 呼叫 + 版本比對 |
| `tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs` | 服務測試（FakeHttpMessageHandler 注入） |
| `tests/MoldplanDbSwitcher.Tests/TestHelpers/FakeHttpMessageHandler.cs` | mock HTTP 工具 |

### 修改

| 路徑 | 變更 |
|---|---|
| `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj` | 加 `<Version>1.0.0</Version>` |
| `.github/workflows/release.yml` | dotnet publish 加 `-p:Version=${version}` |
| `src/MoldplanDbSwitcher/Models/AppSettings.cs` | 加 `GitHubToken` 屬性 |
| `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` | 加 banner 屬性 / Command + ctor 啟動檢查 |
| `src/MoldplanDbSwitcher/Views/MainWindow.axaml` | 加 banner Border |
| `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs` | 加 OnDownloadUpdateClick |
| `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml` | 加 GitHub PAT 欄位 |
| `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs` | 讀寫 PAT |
| `src/MoldplanDbSwitcher/Program.cs` | DI 註冊 HttpClient + IUpdateCheckService |
| `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs` | 補測 banner 顯示 / Dismiss |

---

## Task 1: csproj 加 Version + release.yml 注入版本（前置條件）

**Files:**
- Modify: `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
- Modify: `.github/workflows/release.yml`

> 為什麼先做：Assembly version 預設 `0.0.0.0`，會讓「最新版 vs 目前版」比對永遠誤判，破壞所有後續測試假設。

- [ ] **Step 1: 加 `<Version>` 到 csproj**

在 `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj` 的 `<PropertyGroup>` 中（任意位置，建議放在 `<Nullable>enable</Nullable>` 之後）插入：
```xml
<Version>1.0.0</Version>
```

- [ ] **Step 2: 修改 release.yml 注入 tag 版本**

開啟 `.github/workflows/release.yml`。找到兩處 `dotnet publish ${{ env.PROJECT_PATH }} -c Release -r ...`（windows 與 macos job 各一處），各自在指令末端加 `-p:Version=${{ steps.get-version.outputs.version }}`：

windows job 那行原本：
```yaml
        run: dotnet publish ${{ env.PROJECT_PATH }} -c Release -r win-x64 --self-contained -o publish/win-x64
```
改為：
```yaml
        run: dotnet publish ${{ env.PROJECT_PATH }} -c Release -r win-x64 --self-contained -o publish/win-x64 -p:Version=${{ steps.get-version.outputs.version }}
```

macos job 那行原本：
```yaml
        run: dotnet publish ${{ env.PROJECT_PATH }} -c Release -r ${{ matrix.runtime }} --self-contained -o publish/${{ matrix.runtime }}
```
改為：
```yaml
        run: dotnet publish ${{ env.PROJECT_PATH }} -c Release -r ${{ matrix.runtime }} --self-contained -o publish/${{ matrix.runtime }} -p:Version=${{ steps.get-version.outputs.version }}
```

- [ ] **Step 3: 本機 build 驗證版本注入**

Run: `dotnet build src/MoldplanDbSwitcher/ -c Release /p:Version=1.2.3 --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

Run: `powershell -Command "(Get-Item 'src/MoldplanDbSwitcher/bin/Release/net9.0/MoldplanDbSwitcher.dll').VersionInfo.FileVersion"`
Expected: 顯示 `1.2.3` 或 `1.2.3.0`

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj .github/workflows/release.yml
git commit -m "build: csproj 加 Version + release.yml 注入 tag 版本"
```

---

## Task 2: UpdateInfo Model

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/UpdateInfo.cs`

- [ ] **Step 1: 寫 record**

```csharp
// src/MoldplanDbSwitcher/Models/UpdateInfo.cs
namespace MoldplanDbSwitcher.Models;

public record UpdateInfo(string LatestVersion, string ReleaseUrl, string ReleaseNotes);
```

- [ ] **Step 2: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/UpdateInfo.cs
git commit -m "feat: 新增 UpdateInfo Model"
```

---

## Task 3: AppSettings 加 GitHubToken

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/AppSettings.cs`

- [ ] **Step 1: 加屬性**

開啟 `src/MoldplanDbSwitcher/Models/AppSettings.cs`，在 `DevDirectory` 屬性下方加：
```csharp
public string? GitHubToken { get; set; }
```

完整檔內容應為：
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

    public string? MoldPlanScriptsPath { get; set; }

    public string? GitHubToken { get; set; }
}
```

- [ ] **Step 2: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 3: 跑既有 AppSettings 測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsServiceTests" --nologo 2>&1 | tail -3`
Expected: 5 通過

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/AppSettings.cs
git commit -m "feat: AppSettings 新增 GitHubToken 屬性"
```

---

## Task 4: FakeHttpMessageHandler 測試 helper

**Files:**
- Create: `tests/MoldplanDbSwitcher.Tests/TestHelpers/FakeHttpMessageHandler.cs`

- [ ] **Step 1: 寫 helper**

```csharp
// tests/MoldplanDbSwitcher.Tests/TestHelpers/FakeHttpMessageHandler.cs
using System.Net;

namespace MoldplanDbSwitcher.Tests.TestHelpers;

public class FakeHttpMessageHandler : HttpMessageHandler
{
    private readonly Func<HttpRequestMessage, HttpResponseMessage> _responder;
    public List<HttpRequestMessage> Requests { get; } = new();

    public FakeHttpMessageHandler(Func<HttpRequestMessage, HttpResponseMessage> responder)
    {
        _responder = responder;
    }

    public static FakeHttpMessageHandler Json(HttpStatusCode status, string json) =>
        new(_ => new HttpResponseMessage(status)
        {
            Content = new StringContent(json, System.Text.Encoding.UTF8, "application/json")
        });

    public static FakeHttpMessageHandler Throws(Exception ex) =>
        new(_ => throw ex);

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests.Add(request);
        return Task.FromResult(_responder(request));
    }
}
```

- [ ] **Step 2: 編譯**

Run: `dotnet build tests/MoldplanDbSwitcher.Tests/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 3: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/TestHelpers/FakeHttpMessageHandler.cs
git commit -m "test: 新增 FakeHttpMessageHandler 測試 helper"
```

---

## Task 5: IUpdateCheckService 介面

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs`

- [ ] **Step 1: 寫介面**

```csharp
// src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUpdateCheckService
{
    Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);
}
```

- [ ] **Step 2: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs
git commit -m "feat: 新增 IUpdateCheckService 介面"
```

---

## Task 6: UpdateCheckService — token 為空回 null

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/UpdateCheckService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class UpdateCheckServiceTests
{
    private static UpdateCheckService Create(
        FakeHttpMessageHandler? handler = null,
        Version? currentVersion = null)
    {
        var http = new HttpClient(handler ?? FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, "{}"));
        return new UpdateCheckService(http, currentVersion ?? new Version(1, 0, 0));
    }

    [Fact]
    public async Task CheckAsync_NullToken_ReturnsNull()
    {
        var sut = Create();
        var result = await sut.CheckAsync(null);
        Assert.Null(result);
    }

    [Fact]
    public async Task CheckAsync_EmptyToken_ReturnsNull()
    {
        var sut = Create();
        Assert.Null(await sut.CheckAsync(""));
        Assert.Null(await sut.CheckAsync("   "));
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UpdateCheckServiceTests" --nologo 2>&1 | tail -3`
Expected: 編譯錯誤（`UpdateCheckService` 不存在）

- [ ] **Step 3: 寫最小實作**

```csharp
// src/MoldplanDbSwitcher/Services/UpdateCheckService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UpdateCheckService : IUpdateCheckService
{
    private readonly HttpClient _http;
    private readonly Version _currentVersion;

    public UpdateCheckService(HttpClient http, Version currentVersion)
    {
        _http = http;
        _currentVersion = currentVersion;
    }

    public UpdateCheckService() : this(
        new HttpClient { Timeout = TimeSpan.FromSeconds(10) },
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0, 0))
    { }

    public Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(token))
            return Task.FromResult<UpdateInfo?>(null);
        return Task.FromResult<UpdateInfo?>(null);
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UpdateCheckServiceTests" --nologo 2>&1 | tail -3`
Expected: 2 通過

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/UpdateCheckService.cs tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs
git commit -m "feat: 新增 UpdateCheckService（token 為空回 null）"
```

---

## Task 7: UpdateCheckService — 新版可用回 UpdateInfo

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/UpdateCheckService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs`

- [ ] **Step 1: 加測試**

在 `UpdateCheckServiceTests.cs` 末尾（class 結尾 `}` 前）加：

```csharp
[Fact]
public async Task CheckAsync_NewerVersionAvailable_ReturnsInfo()
{
    var json = """
        {
            "tag_name": "v2.0.0",
            "html_url": "https://github.com/owner/repo/releases/tag/v2.0.0",
            "body": "release notes here"
        }
        """;
    var handler = FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json);
    var sut = Create(handler, currentVersion: new Version(1, 1, 2));

    var result = await sut.CheckAsync("dummy-token");

    Assert.NotNull(result);
    Assert.Equal("2.0.0", result!.LatestVersion);
    Assert.Equal("https://github.com/owner/repo/releases/tag/v2.0.0", result.ReleaseUrl);
    Assert.Equal("release notes here", result.ReleaseNotes);
}

[Fact]
public async Task CheckAsync_SendsBearerTokenAndUserAgent()
{
    var json = "{}";
    var handler = FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json);
    var sut = Create(handler);

    await sut.CheckAsync("my-token");

    var req = handler.Requests.Single();
    Assert.Equal("Bearer", req.Headers.Authorization?.Scheme);
    Assert.Equal("my-token", req.Headers.Authorization?.Parameter);
    Assert.NotEmpty(req.Headers.UserAgent);
    Assert.Contains(req.Headers.Accept, h => h.MediaType == "application/vnd.github+json");
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UpdateCheckServiceTests" --nologo 2>&1 | tail -3`
Expected: 2 失敗（新加的測試）

- [ ] **Step 3: 實作完整 CheckAsync**

把 `src/MoldplanDbSwitcher/Services/UpdateCheckService.cs` 整個換成：

```csharp
using System.Net.Http.Headers;
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UpdateCheckService : IUpdateCheckService
{
    private const string RepoOwner = "KerryHuang";
    private const string RepoName = "moldplan-change-database";
    private const string UserAgent = "MoldplanDbSwitcher-UpdateCheck";

    private readonly HttpClient _http;
    private readonly Version _currentVersion;

    public UpdateCheckService(HttpClient http, Version currentVersion)
    {
        _http = http;
        _currentVersion = currentVersion;
    }

    public UpdateCheckService() : this(
        new HttpClient { Timeout = TimeSpan.FromSeconds(10) },
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0, 0))
    { }

    public async Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get,
                $"https://api.github.com/repos/{RepoOwner}/{RepoName}/releases/latest");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            req.Headers.UserAgent.ParseAdd(UserAgent);
            req.Headers.Accept.ParseAdd("application/vnd.github+json");

            using var resp = await _http.SendAsync(req, ct);
            if (!resp.IsSuccessStatusCode) return null;

            var json = await resp.Content.ReadAsStringAsync(ct);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var tagName = root.TryGetProperty("tag_name", out var t) ? t.GetString() : null;
            var htmlUrl = root.TryGetProperty("html_url", out var u) ? u.GetString() : null;
            var body = root.TryGetProperty("body", out var b) ? b.GetString() ?? "" : "";

            if (string.IsNullOrEmpty(tagName) || string.IsNullOrEmpty(htmlUrl)) return null;

            var versionStr = tagName.TrimStart('v', 'V');
            if (!Version.TryParse(versionStr, out var latest)) return null;

            return latest > _currentVersion
                ? new UpdateInfo(versionStr, htmlUrl, body)
                : null;
        }
        catch { return null; }
    }
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UpdateCheckServiceTests" --nologo 2>&1 | tail -3`
Expected: 4 通過

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/UpdateCheckService.cs tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs
git commit -m "feat: UpdateCheckService 實作 GitHub Releases 查詢"
```

---

## Task 8: UpdateCheckService — 邊界 case 測試

**Files:**
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs`

- [ ] **Step 1: 加邊界測試**

加到 `UpdateCheckServiceTests.cs` 結尾：

```csharp
[Fact]
public async Task CheckAsync_SameVersion_ReturnsNull()
{
    var json = """{"tag_name":"v1.1.2","html_url":"https://x","body":""}""";
    var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json),
        currentVersion: new Version(1, 1, 2));
    Assert.Null(await sut.CheckAsync("t"));
}

[Fact]
public async Task CheckAsync_OlderVersion_ReturnsNull()
{
    var json = """{"tag_name":"v1.0.0","html_url":"https://x","body":""}""";
    var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json),
        currentVersion: new Version(1, 1, 2));
    Assert.Null(await sut.CheckAsync("t"));
}

[Theory]
[InlineData(System.Net.HttpStatusCode.Unauthorized)]
[InlineData(System.Net.HttpStatusCode.NotFound)]
[InlineData(System.Net.HttpStatusCode.InternalServerError)]
public async Task CheckAsync_HttpError_ReturnsNull(System.Net.HttpStatusCode status)
{
    var sut = Create(FakeHttpMessageHandler.Json(status, ""));
    Assert.Null(await sut.CheckAsync("t"));
}

[Fact]
public async Task CheckAsync_NetworkException_ReturnsNull()
{
    var sut = Create(FakeHttpMessageHandler.Throws(new HttpRequestException("boom")));
    Assert.Null(await sut.CheckAsync("t"));
}

[Fact]
public async Task CheckAsync_InvalidTagFormat_ReturnsNull()
{
    var json = """{"tag_name":"release-foo","html_url":"https://x","body":""}""";
    var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json));
    Assert.Null(await sut.CheckAsync("t"));
}

[Fact]
public async Task CheckAsync_MalformedJson_ReturnsNull()
{
    var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, "not json"));
    Assert.Null(await sut.CheckAsync("t"));
}

[Fact]
public async Task CheckAsync_MissingFields_ReturnsNull()
{
    var json = """{"tag_name":"v2.0.0"}""";
    var sut = Create(FakeHttpMessageHandler.Json(System.Net.HttpStatusCode.OK, json));
    Assert.Null(await sut.CheckAsync("t"));
}
```

- [ ] **Step 2: 跑全部 UpdateCheckServiceTests，確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "UpdateCheckServiceTests" --nologo 2>&1 | tail -3`
Expected: 全部通過（含 Theory 3 個共 11 個）

- [ ] **Step 3: Commit**

```bash
git add tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs
git commit -m "test: UpdateCheckService 補邊界 case（HTTP 錯/網路錯/JSON 錯/版本格式錯）"
```

---

## Task 9: MainWindowViewModel 加入更新檢查屬性與啟動觸發

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試**

開啟 `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`，找到既有 SetUp 方法（可能命名為 `CreateViewModel` 或在每個測試直接 new）。新增測試：

```csharp
[Fact]
public async Task Ctor_UpdateAvailable_SetsBannerProperties()
{
    var update = Substitute.For<IUpdateCheckService>();
    update.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
        .Returns(new UpdateInfo("9.9.9", "https://x/release", "notes"));

    var vm = CreateViewModelWithUpdate(update);
    await WaitForUpdateCheckAsync(vm);

    Assert.True(vm.UpdateAvailable);
    Assert.Equal("https://x/release", vm.UpdateReleaseUrl);
    Assert.Contains("9.9.9", vm.UpdateBannerText);
}

[Fact]
public async Task Ctor_NoUpdate_BannerHidden()
{
    var update = Substitute.For<IUpdateCheckService>();
    update.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
        .Returns((UpdateInfo?)null);

    var vm = CreateViewModelWithUpdate(update);
    await WaitForUpdateCheckAsync(vm);

    Assert.False(vm.UpdateAvailable);
}

[Fact]
public async Task DismissUpdateCommand_HidesBanner()
{
    var update = Substitute.For<IUpdateCheckService>();
    update.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
        .Returns(new UpdateInfo("9.9.9", "https://x", ""));
    var vm = CreateViewModelWithUpdate(update);
    await WaitForUpdateCheckAsync(vm);

    vm.DismissUpdateCommand.Execute(null);

    Assert.False(vm.UpdateAvailable);
}

// 等啟動時的 fire-and-forget update check 跑完
private static async Task WaitForUpdateCheckAsync(MainWindowViewModel vm)
{
    for (var i = 0; i < 50; i++)
    {
        if (vm.UpdateAvailable || vm.UpdateBannerText.Length > 0) return;
        await Task.Delay(20);
    }
}
```

並新增 helper（放在既有 `CreateViewModel` 或類似工廠旁邊；若沒有則新建一個）：

```csharp
private static MainWindowViewModel CreateViewModelWithUpdate(IUpdateCheckService update)
{
    // 視既有 ctor 簽章，用 Substitute.For 給其他依賴。
    var connSource = Substitute.For<IConnectionSourceService>();
    connSource.LoadSpecuraiConnections().Returns(new List<ConnectionProfile>());
    connSource.LoadCustomConnections().Returns(new List<ConnectionProfile>());

    var serverTxt = Substitute.For<IServerTxtService>();
    serverTxt.DiscoverPaths().Returns(new List<string>());

    var settings = Substitute.For<ISettingsService>();
    settings.LoadProfiles().Returns(new List<ConnectionProfile>());

    var featureReport = Substitute.For<IFeatureReportService>();
    var connExport = Substitute.For<IConnectionExportService>();
    var usageReport = Substitute.For<IUsageReportService>();
    var ansible = Substitute.For<IAnsibleSyncService>();
    var appSettings = Substitute.For<IAppSettingsService>();
    appSettings.Load().Returns(new AppSettings());
    var appSettingsDev = Substitute.For<IAppSettingsDevService>();
    var sqlFactory = Substitute.For<ISqlConnectionFactory>();
    sqlFactory.Create(Arg.Any<ConnectionProfile>())
        .Returns(new Microsoft.Data.SqlClient.SqlConnection());

    var query = Substitute.For<IReportingObjectService>();
    query.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
    query.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
    query.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
    var reportingQuery = new ReportingQueryViewModel(_ => query,
        _ => Substitute.For<IReportingQueryService>(), "");
    var reportingDeploy = new ReportingDeployViewModel(_ => query,
        _ => Substitute.For<IReportingDeployService>(), "", "");

    return new MainWindowViewModel(
        connSource, serverTxt, settings, featureReport, connExport, usageReport,
        ansible, appSettings, appSettingsDev, sqlFactory, reportingQuery, reportingDeploy,
        update);
}
```

> 注意：若既有 `MainWindowViewModelTests` 已有類似 CreateViewModel helper，把 update 參數加進去並更新所有呼叫端。

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests" --nologo 2>&1 | tail -3`
Expected: 編譯錯（找不到 UpdateAvailable / UpdateReleaseUrl / DismissUpdateCommand / ctor 14 個參數）

- [ ] **Step 3: 修改 MainWindowViewModel**

在 `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs` 找到既有的 fields 區塊。

加新 field：
```csharp
private readonly IUpdateCheckService _updateCheckService;
```

加新 ObservableProperties（與既有 `[ObservableProperty] private bool _isExporting;` 同區）：
```csharp
[ObservableProperty] private bool _updateAvailable;
[ObservableProperty] private string _updateBannerText = "";
[ObservableProperty] private string? _updateReleaseUrl;
```

修改 ctor 簽章，**追加** 第 13 個參數 `IUpdateCheckService updateCheckService`：
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
    IAppSettingsDevService appSettingsDevService,
    ISqlConnectionFactory connectionFactory,
    ReportingQueryViewModel reportingQuery,
    ReportingDeployViewModel reportingDeploy,
    IUpdateCheckService updateCheckService)
```

ctor body 結尾（在 `DiscoverServerTxtFiles();` 之後）：
```csharp
    _updateCheckService = updateCheckService;
    _ = CheckForUpdatesAsync();
}
```

注意：`_updateCheckService = updateCheckService;` 要放在 base ctor body 「賦值區」與既有 `LoadConnections()` 之前才合理；最終 ctor 內容應該長這樣：

```csharp
public MainWindowViewModel(
    IConnectionSourceService connectionSource,
    /* ... 既有所有參數 ... */
    ReportingDeployViewModel reportingDeploy,
    IUpdateCheckService updateCheckService)
{
    _connectionSource = connectionSource;
    /* ... 既有所有賦值 ... */
    ReportingDeploy = reportingDeploy;
    _updateCheckService = updateCheckService;

    LoadConnections();
    DiscoverServerTxtFiles();
    _ = CheckForUpdatesAsync();
}
```

加新方法（任意位置）：
```csharp
private async Task CheckForUpdatesAsync()
{
    try
    {
        var token = _appSettingsService.Load().GitHubToken;
        var info = await _updateCheckService.CheckAsync(token);
        if (info == null) return;
        UpdateReleaseUrl = info.ReleaseUrl;
        var current = System.Reflection.Assembly.GetExecutingAssembly()
            .GetName().Version?.ToString(3) ?? "?";
        UpdateBannerText = $"🎉 有新版 v{info.LatestVersion} 可用（目前 v{current}）";
        UpdateAvailable = true;
    }
    catch { /* 靜音 */ }
}

[RelayCommand]
private void DismissUpdate() => UpdateAvailable = false;
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests" --nologo 2>&1 | tail -3`
Expected: 通過全部（含新加 3 個）

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: MainWindowViewModel 啟動時檢查更新並暴露 banner 屬性"
```

---

## Task 10: Program.cs DI 註冊

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

- [ ] **Step 1: 加 using**

確認 `using MoldplanDbSwitcher.Services;` 已存在（應該已有）。

- [ ] **Step 2: 註冊 IUpdateCheckService**

在 `ConfigureServices` 方法內，找到 `services.AddSingleton<IAppSettingsService, AppSettingsService>();` 那行附近，加：

```csharp
services.AddSingleton<IUpdateCheckService>(_ => new UpdateCheckService());
```

註：用 lambda 而不是 `AddSingleton<IUpdateCheckService, UpdateCheckService>()`，因為 UpdateCheckService 有一個無參預設 ctor，DI 用 lambda 明確走無參數路徑（會自己建內部 HttpClient + 讀 Assembly version）。

- [ ] **Step 3: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "feat: DI 註冊 IUpdateCheckService"
```

---

## Task 11: MainWindow 加入 banner UI

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

- [ ] **Step 1: 在 MainWindow.axaml 頂端加 banner Border**

開啟 `src/MoldplanDbSwitcher/Views/MainWindow.axaml`。找到既有的「目前連線」Border（含 `Text="目前連線："` 那個）。在它**上方**（同一個 DockPanel 的 Top dock 順序中先 dock）新增：

```xml
  <Border DockPanel.Dock="Top" Padding="8" Margin="0,0,0,8"
          Background="#1F5A2D" CornerRadius="4"
          IsVisible="{Binding UpdateAvailable}">
    <StackPanel Orientation="Horizontal" Spacing="12">
      <TextBlock Text="{Binding UpdateBannerText}" Foreground="White"
                 VerticalAlignment="Center" />
      <Button Content="下載新版" Click="OnDownloadUpdateClick" />
      <Button Content="稍後" Command="{Binding DismissUpdateCommand}" />
    </StackPanel>
  </Border>
```

實際插入位置：找到 `<DockPanel Margin="16">` 之後第一個 `<Border DockPanel.Dock="Top" ... 目前連線`，在那個 Border 的**前面**插入上述新 Border。

- [ ] **Step 2: 在 MainWindow.axaml.cs 加 Click handler**

開啟 `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`。在 class 內任意位置（例如既有 `OnTopConnectionChanged` 旁）加：

```csharp
private void OnDownloadUpdateClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm && !string.IsNullOrEmpty(vm.UpdateReleaseUrl))
    {
        try
        {
            System.Diagnostics.Process.Start(
                new System.Diagnostics.ProcessStartInfo(vm.UpdateReleaseUrl)
                { UseShellExecute = true });
        }
        catch { /* 靜音 */ }
    }
}
```

確認檔頂 using 已含 `using Avalonia.Interactivity;`（既有 handler 已用，應已存在）。

- [ ] **Step 3: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: MainWindow 加入更新提醒 banner（下載新版開瀏覽器）"
```

---

## Task 12: SettingsDialog 加 GitHub PAT 欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs`

- [ ] **Step 1: AXAML 加欄位**

開啟 `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml`。在主 StackPanel 最後一個既有 `<StackPanel Spacing="4">`（應為 MoldPlanScriptsPath 或 DevDirectory 那組）之**後**新增：

```xml
      <StackPanel Spacing="4">
        <TextBlock Text="GitHub PAT（檢查更新用）：" />
        <TextBox x:Name="GitHubTokenBox" PasswordChar="●"
                 Watermark="留白則不檢查更新" />
        <TextBlock FontSize="10" Foreground="Gray" TextWrapping="Wrap"
                   Text="建議使用 fine-grained PAT，只授予該 Repo 的 Read access。" />
      </StackPanel>
```

- [ ] **Step 2: code-behind 讀寫**

開啟 `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs`。

在 ctor 內，既有 `DevDirectoryBox.Text = settings.DevDirectory;` 之後加：
```csharp
GitHubTokenBox.Text = settings.GitHubToken ?? string.Empty;
```

注意：若已有 `MoldPlanScriptsPathBox.Text = ...` 那行，加在它之後。

在 `OnSaveClick` 內，找到 `_appSettingsService.Save(new AppSettings { ... });` 區塊，在物件初始化器中加：
```csharp
GitHubToken = string.IsNullOrWhiteSpace(GitHubTokenBox.Text) ? null : GitHubTokenBox.Text,
```

整個 Save 區塊應為（以實際當前內容為準補欄位，不要漏既有欄位）：
```csharp
_appSettingsService.Save(new AppSettings
{
    AnsibleRepoPath = AnsibleRepoPathBox.Text ?? string.Empty,
    VaultPasswordFile = VaultPasswordFileBox.Text ?? string.Empty,
    DevDirectory = DevDirectoryBox.Text ?? string.Empty,
    MoldPlanScriptsPath = string.IsNullOrWhiteSpace(MoldPlanScriptsPathBox.Text)
        ? null : MoldPlanScriptsPathBox.Text,
    GitHubToken = string.IsNullOrWhiteSpace(GitHubTokenBox.Text) ? null : GitHubTokenBox.Text,
});
```

- [ ] **Step 3: 編譯**

Run: `dotnet build src/MoldplanDbSwitcher/ --nologo 2>&1 | tail -3`
Expected: `0 個錯誤`

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/SettingsDialog.axaml src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs
git commit -m "feat: SettingsDialog 新增 GitHub PAT 欄位"
```

---

## Task 13: 整合測試（全測試 + 手動驗證）

**Files:** （無新增）

- [ ] **Step 1: 跑全部測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --nologo 2>&1 | tail -3`
Expected: 全綠（既有 163 + 新增約 11 個 service + 3 個 vm = ~177 通過）

- [ ] **Step 2: 啟動 App 手動驗證 — 無 PAT 情境**

Run: `dotnet run --project src/MoldplanDbSwitcher/`
驗證：
- App 正常啟動
- 主視窗頂端**沒有**綠色 banner（因 PAT 為空，CheckAsync 回 null）
- 開「設定」對話框，看到「GitHub PAT」欄位
- 關閉 App

- [ ] **Step 3: 啟動 App 手動驗證 — 有 PAT 且有新版**

前置：在 GitHub 建立 fine-grained PAT（Contents: Read on this repo）。

在 App「設定」填入 PAT 並儲存，關閉重啟。

由於本機 Assembly version 為 1.0.0（csproj 預設），而 latest release tag 為 `v1.1.2`，重啟後應看到綠色 banner「🎉 有新版 v1.1.2 可用（目前 v1.0.0）」。

點「下載新版」應開瀏覽器到 https://github.com/KerryHuang/moldplan-change-database/releases/tag/v1.1.2

點「稍後」應隱藏 banner。

- [ ] **Step 4: 啟動 App 手動驗證 — 有 PAT 但無新版**

把 csproj 的 `<Version>` 暫時改為 `99.0.0`，rebuild，重啟 App。

預期：無 banner（latest < current）。

驗證完把 `<Version>` 改回 `1.0.0`。

- [ ] **Step 5: Commit（若手動驗證有修 bug）**

```bash
git add -A
git commit -m "fix: 手動驗證後微調"
```

如無 bug，跳過本步。

---

## Self-Review Notes

- **Spec coverage**：
  - 範圍（僅提醒、啟動時、PAT、靜音）→ Task 6/7/9/11
  - UpdateInfo / IUpdateCheckService / 行為契約 → Task 2/5/6/7/8
  - AppSettings.GitHubToken → Task 3/12
  - MainWindowViewModel banner 屬性 / 命令 → Task 9
  - MainWindow banner UI + Process.Start → Task 11
  - SettingsDialog PAT 欄位 → Task 12
  - DI 註冊 → Task 10
  - 測試（9 個 service + 3 個 vm）→ Task 6/7/8/9
  - csproj Version 注入前置條件 → Task 1
- **Placeholder scan**：所有 step 都有具體程式碼與指令，無 TBD/TODO/placeholder
- **Type consistency**：`UpdateInfo` 三欄（LatestVersion / ReleaseUrl / ReleaseNotes）在所有 Task 一致；`IUpdateCheckService.CheckAsync(string?, CancellationToken)` 簽章在所有 Task 一致；`UpdateAvailable` / `UpdateBannerText` / `UpdateReleaseUrl` 在 ViewModel 與 View 綁定一致
