# MoldplanDbSwitcher Velopack 自動更新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Windows 版啟動時自動檢查＋背景下載新版，橫幅一鍵重啟完成更新；非 Velopack 安裝與 macOS 維持現有「通知＋連結」。

**Architecture:** `VelopackUpdateCheckService` 實作既有 `IUpdateCheckService`（介面擴充 `DownloadAsync`/`ApplyAndRestart`），內部持 fallback（既有 `UpdateCheckService`）：非 Windows 或非 Velopack 安裝時委派 fallback。更新來源為 GitHub private Release（Velopack `GithubSource` + 使用者設定的 GitHubToken）。CI 的 Windows job 加 `vpk pack` 產 Velopack 資產。

**Tech Stack:** .NET 9、Avalonia 11.3、CommunityToolkit.Mvvm、Velopack（NuGet 最新穩定版）、xUnit + NSubstitute（無 FluentAssertions，用 xunit Assert）。

**Spec:** `docs/superpowers/specs/2026-08-04-velopack-auto-update-design.md`

## Global Constraints

- 所有 UI 文字、commit 訊息、註解繁體中文；程式碼識別符英文（Law 1）。
- TDD：先寫失敗測試、確認失敗、再最小實作、確認通過（Law 2）。
- Service 必有 interface、可注入以便測試（Law 3）。
- git add 逐檔指名，禁止 `git add -A` / `git add .`。
- 既有測試零回歸（`dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`）。
- Repo 常數：`RepoOwner = "KerryHuang"`、`RepoName = "moldplan-change-database"`（與既有 `UpdateCheckService.cs:9-10` 一致）。

---

### Task 1: Model 與介面擴充 + fallback 服務補新方法

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/UpdateInfo.cs`
- Modify: `src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/UpdateCheckService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs`（加測試）

**Interfaces:**
- Consumes: 既有 `UpdateInfo` record、`IUpdateCheckService.CheckAsync(string?, CancellationToken)`。
- Produces（Task 2/4 依賴）：
  - `record UpdateInfo(string LatestVersion, string ReleaseUrl, string ReleaseNotes, bool CanAutoApply = false)`
  - `Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default);`
  - `void ApplyAndRestart();`

- [ ] **Step 1: 寫失敗測試**

在 `UpdateCheckServiceTests.cs` 追加（比照該檔既有風格）：

```csharp
    [Fact]
    public async Task DownloadAsync_通知模式不支援_應丟InvalidOperationException()
    {
        var service = new UpdateCheckService();
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DownloadAsync());
    }

    [Fact]
    public void ApplyAndRestart_通知模式不支援_應丟InvalidOperationException()
    {
        var service = new UpdateCheckService();
        Assert.Throws<InvalidOperationException>(() => service.ApplyAndRestart());
    }
```

（測試方法命名以該檔既有慣例為準：先看檔案，若既有為英文命名則改用英文同義命名。）

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj --filter "FullyQualifiedName~UpdateCheckServiceTests"`
Expected: 編譯失敗（介面無 `DownloadAsync`）。

- [ ] **Step 3: 最小實作**

`UpdateInfo.cs`：

```csharp
namespace MoldplanDbSwitcher.Models;

/// <summary>更新資訊；CanAutoApply 表示可自動下載套用（Velopack 安裝）而非僅通知</summary>
public record UpdateInfo(string LatestVersion, string ReleaseUrl, string ReleaseNotes, bool CanAutoApply = false);
```

`IUpdateCheckService.cs`：

```csharp
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUpdateCheckService
{
    Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);

    /// <summary>下載已偵測到的更新（僅 CanAutoApply 來源支援）</summary>
    Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default);

    /// <summary>套用已下載的更新並重啟（僅 CanAutoApply 來源支援）</summary>
    void ApplyAndRestart();
}
```

`UpdateCheckService.cs` 類別內追加：

```csharp
    public Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default)
        => throw new InvalidOperationException("此更新來源僅支援通知，請至 Release 頁面手動下載。");

    public void ApplyAndRestart()
        => throw new InvalidOperationException("此更新來源僅支援通知，請至 Release 頁面手動下載。");
```

既有 `CheckAsync` 回傳的 `new UpdateInfo(versionStr, htmlUrl, body)` 不用改——新參數預設 `false`。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`
Expected: 全綠（含既有 UpdateCheckServiceTests、MainWindowViewModelTests 零回歸）。

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/UpdateInfo.cs src/MoldplanDbSwitcher/Services/IUpdateCheckService.cs src/MoldplanDbSwitcher/Services/UpdateCheckService.cs tests/MoldplanDbSwitcher.Tests/Services/UpdateCheckServiceTests.cs
git commit -m "feat: 更新服務介面擴充自動套用能力（通知模式維持不支援）"
```

---

### Task 2: VelopackUpdateCheckService（含 Velopack 套件）

**Files:**
- Modify: `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`（加 `Velopack` PackageReference，NuGet 最新穩定版）
- Create: `src/MoldplanDbSwitcher/Services/VelopackUpdateCheckService.cs`
- Test: `tests/MoldplanDbSwitcher.Tests/Services/VelopackUpdateCheckServiceTests.cs`

**Interfaces:**
- Consumes: Task 1 的介面；`Velopack.UpdateManager`、`Velopack.Sources.GithubSource`。
- Produces（Task 3/4 依賴）：`VelopackUpdateCheckService(IUpdateCheckService fallback)`，行為——
  - 非 Windows 或非 Velopack 安裝 → 委派 `fallback.CheckAsync`。
  - Velopack 安裝但 token 空 → 回 null（private repo 無授權注定失敗）。
  - Velopack 偵測到新版 → 回 `UpdateInfo(..., CanAutoApply: true)`。
  - `DownloadAsync`/`ApplyAndRestart` 未先 Check 到更新 → `InvalidOperationException`。

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/VelopackUpdateCheckServiceTests.cs
using System.Threading;
using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class VelopackUpdateCheckServiceTests
{
    private readonly IUpdateCheckService _fallback = Substitute.For<IUpdateCheckService>();

    // 測試環境不是 Velopack 安裝（IsInstalled=false），CheckAsync 應委派 fallback
    [Fact]
    public async Task CheckAsync_非Velopack安裝_應委派fallback()
    {
        var expected = new UpdateInfo("9.9.9", "https://example.com", "notes");
        _fallback.CheckAsync("tok", Arg.Any<CancellationToken>()).Returns(expected);
        var service = new VelopackUpdateCheckService(_fallback);

        var result = await service.CheckAsync("tok");

        Assert.Equal(expected, result);
        await _fallback.Received(1).CheckAsync("tok", Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task DownloadAsync_未偵測到更新_應丟InvalidOperationException()
    {
        var service = new VelopackUpdateCheckService(_fallback);
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DownloadAsync());
    }

    [Fact]
    public void ApplyAndRestart_未偵測到更新_應丟InvalidOperationException()
    {
        var service = new VelopackUpdateCheckService(_fallback);
        Assert.Throws<InvalidOperationException>(() => service.ApplyAndRestart());
    }
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj --filter "FullyQualifiedName~VelopackUpdateCheckServiceTests"`
Expected: 編譯失敗（型別不存在）。

- [ ] **Step 3: 加套件與實作**

csproj 加（用 `dotnet add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj package Velopack` 取最新穩定版）。

```csharp
// src/MoldplanDbSwitcher/Services/VelopackUpdateCheckService.cs
using System.Diagnostics;
using MoldplanDbSwitcher.Models;
using Velopack;
using Velopack.Sources;
using VelopackUpdateInfo = Velopack.UpdateInfo;

namespace MoldplanDbSwitcher.Services;

/// <summary>
/// Velopack 自動更新實作：Windows 且以 Velopack 安裝時走自動下載＋套用；
/// 其餘情境（macOS、直接解壓執行）委派 fallback 的通知模式。
/// 更新來源為 GitHub private Release，需使用者設定 GitHubToken。
/// </summary>
public sealed class VelopackUpdateCheckService : IUpdateCheckService
{
    private const string RepoUrl = "https://github.com/KerryHuang/moldplan-change-database";

    private readonly IUpdateCheckService _fallback;
    private UpdateManager? _manager;
    private VelopackUpdateInfo? _pending;

    public VelopackUpdateCheckService(IUpdateCheckService fallback)
    {
        _fallback = fallback;
    }

    public async Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default)
    {
        var manager = GetManagerOrNull(token);
        if (!OperatingSystem.IsWindows() || manager is null || !manager.IsInstalled)
            return await _fallback.CheckAsync(token, ct);

        // private repo：無 token 時 API 必定 404，不嘗試
        if (string.IsNullOrWhiteSpace(token))
            return null;

        try
        {
            _pending = await manager.CheckForUpdatesAsync().ConfigureAwait(false);
            if (_pending is null)
                return null;

            var target = _pending.TargetFullRelease;
            return new UpdateInfo(
                target.Version.ToString(),
                $"{RepoUrl}/releases/tag/v{target.Version}",
                target.NotesMarkdown ?? string.Empty,
                CanAutoApply: true);
        }
        catch (Exception ex)
        {
            Trace.WriteLine($"[UpdateCheck] Velopack 檢查失敗：{ex.Message}");
            return null;
        }
    }

    public async Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default)
    {
        if (_manager is null || _pending is null)
            throw new InvalidOperationException("未偵測到待套用的更新，請先呼叫 CheckAsync。");

        await _manager.DownloadUpdatesAsync(_pending, p => progress?.Report(p), ct).ConfigureAwait(false);
    }

    public void ApplyAndRestart()
    {
        if (_manager is null || _pending is null)
            throw new InvalidOperationException("未偵測到待套用的更新。");

        _manager.ApplyUpdatesAndRestart(_pending.TargetFullRelease);
    }

    /// <summary>lazy 建立 UpdateManager；非 Velopack 環境建構失敗回 null（走 fallback）</summary>
    private UpdateManager? GetManagerOrNull(string? token)
    {
        if (_manager is not null) return _manager;
        try
        {
            var source = new GithubSource(RepoUrl,
                accessToken: string.IsNullOrWhiteSpace(token) ? null : token,
                prerelease: false);
            _manager = new UpdateManager(source);
            return _manager;
        }
        catch (Exception ex)
        {
            Trace.WriteLine($"[UpdateCheck] Velopack 初始化失敗：{ex.Message}");
            return null;
        }
    }
}
```

注意：`Velopack.UpdateInfo` 與 `Models.UpdateInfo` 同名，檔頭 alias 已處理；若 Velopack API 與上述簽章有出入（版本差異），以編譯錯誤與官方 API 為準調整，行為不變。

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`
Expected: 新測試 PASS（測試機非 Velopack 安裝 → `IsInstalled` false → 委派 fallback），全綠零回歸。

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj src/MoldplanDbSwitcher/Services/VelopackUpdateCheckService.cs tests/MoldplanDbSwitcher.Tests/Services/VelopackUpdateCheckServiceTests.cs
git commit -m "feat: 新增 Velopack 自動更新服務（非安裝環境委派通知模式）"
```

---

### Task 3: Program.cs — Velopack 掛鉤與 DI 換裝

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

**Interfaces:**
- Consumes: Task 2 的 `VelopackUpdateCheckService(IUpdateCheckService fallback)`。
- Produces: DI 解析 `IUpdateCheckService` 得到 Velopack 服務（內含通知 fallback）。

- [ ] **Step 1: 修改 Main 與 DI**

`Main` 第一行（`var services = ...` 之前）加：

```csharp
        // Velopack 必要掛鉤：安裝／更新／解除安裝時處理捷徑與版本切換後直接結束行程
        VelopackApp.Build().Run();
```

檔頭補 `using Velopack;`。

DI 註冊替換（`Program.cs:27`）：

```csharp
        services.AddSingleton<IUpdateCheckService>(_ => new VelopackUpdateCheckService(new UpdateCheckService()));
```

- [ ] **Step 2: 建置 + 全測試**

Run: `dotnet build && dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`
Expected: 成功、全綠。

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "feat: 掛載 Velopack 啟動掛鉤並改用自動更新服務"
```

---

### Task 4: MainWindowViewModel 自動下載流程 + 橫幅按鈕

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs:93-108`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml:39-47`
- Test: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`（加測試）

**Interfaces:**
- Consumes: Task 1/2 的 `UpdateInfo.CanAutoApply`、`DownloadAsync`、`ApplyAndRestart`。
- Produces: `UpdateReadyToRestart`（bool ObservableProperty）、`ApplyUpdateAndRestartCommand`。

- [ ] **Step 1: 寫失敗測試**

在 `MainWindowViewModelTests.cs` 追加（用該檔既有的 `CreateConnectionSwitch()` 等 helper 建 VM；建構 VM 的方式照抄檔內既有測試）：

```csharp
    [Fact]
    public async Task 更新可自動套用_應自動下載並顯示重啟橫幅()
    {
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com", "", CanAutoApply: true));

        var vm = CreateViewModel(); // 依該檔既有建構方式；建構式內會觸發 CheckForUpdatesAsync
        await Task.Delay(200);      // 等待 fire-and-forget 完成（比照檔內既有非同步測試手法，若有更好的等待 helper 就用它）

        await _updateCheckService.Received(1).DownloadAsync(Arg.Any<IProgress<int>?>(), Arg.Any<CancellationToken>());
        Assert.True(vm.UpdateAvailable);
        Assert.True(vm.UpdateReadyToRestart);
        Assert.Contains("重啟", vm.UpdateBannerText);
    }

    [Fact]
    public async Task 更新僅通知模式_應維持既有橫幅不下載()
    {
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com/rel", ""));

        var vm = CreateViewModel();
        await Task.Delay(200);

        await _updateCheckService.DidNotReceiveWithAnyArgs().DownloadAsync(default, default);
        Assert.True(vm.UpdateAvailable);
        Assert.False(vm.UpdateReadyToRestart);
        Assert.Equal("https://example.com/rel", vm.UpdateReleaseUrl);
    }

    [Fact]
    public async Task 自動下載失敗_橫幅不應出現()
    {
        _appSettingsService.Load().Returns(new AppSettings { GitHubToken = "tok" });
        _updateCheckService.CheckAsync(Arg.Any<string?>(), Arg.Any<CancellationToken>())
            .Returns(new UpdateInfo("2.0.0", "https://example.com", "", CanAutoApply: true));
        _updateCheckService.DownloadAsync(Arg.Any<IProgress<int>?>(), Arg.Any<CancellationToken>())
            .Returns<Task>(_ => throw new HttpRequestException("網路中斷"));

        var vm = CreateViewModel();
        await Task.Delay(200);

        Assert.False(vm.UpdateAvailable);
    }

    [Fact]
    public void 重啟更新命令_應呼叫ApplyAndRestart()
    {
        var vm = CreateViewModel();
        vm.ApplyUpdateAndRestartCommand.Execute(null);
        _updateCheckService.Received(1).ApplyAndRestart();
    }
```

（若檔內沒有 `CreateViewModel()` helper，先在測試類加一個組合既有 helper 的私有方法；`AppSettings.GitHubToken` 屬性名以實際 Model 為準。）

- [ ] **Step 2: 跑測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj --filter "FullyQualifiedName~MainWindowViewModelTests"`
Expected: 編譯失敗（`UpdateReadyToRestart` 不存在）。

- [ ] **Step 3: 實作 ViewModel 與 AXAML**

`MainWindowViewModel.cs`：

1. ObservableProperty 區追加：

```csharp
    [ObservableProperty] private bool _updateReadyToRestart;
```

2. `CheckForUpdatesAsync` 改為：

```csharp
    private async Task CheckForUpdatesAsync()
    {
        try
        {
            var token = _appSettingsService.Load().GitHubToken;
            var info = await _updateCheckService.CheckAsync(token);
            if (info == null) return;
            UpdateReleaseUrl = info.ReleaseUrl;
            var current = Assembly.GetExecutingAssembly().GetName().Version?.ToString(3) ?? "?";

            if (info.CanAutoApply)
            {
                // 背景自動下載，完成後橫幅提供一鍵重啟
                await _updateCheckService.DownloadAsync();
                UpdateBannerText = $"⬇ 已下載 v{info.LatestVersion}（目前 v{current}），重啟以完成更新";
                UpdateReadyToRestart = true;
            }
            else
            {
                UpdateBannerText = $"🎉 有新版 v{info.LatestVersion} 可用（目前 v{current}）";
            }

            UpdateAvailable = true;
        }
        catch { /* 靜音：檢查或下載失敗都不打擾使用者 */ }
    }

    [RelayCommand]
    private void ApplyUpdateAndRestart()
    {
        try { _updateCheckService.ApplyAndRestart(); }
        catch { /* 靜音 */ }
    }
```

`MainWindow.axaml:44` 的按鈕區改為：

```xml
        <Button Content="重啟更新" Command="{Binding ApplyUpdateAndRestartCommand}"
                IsVisible="{Binding UpdateReadyToRestart}" />
        <Button Content="下載新版" Click="OnDownloadUpdateClick"
                IsVisible="{Binding !UpdateReadyToRestart}" />
        <Button Content="稍後" Command="{Binding DismissUpdateCommand}" />
```

- [ ] **Step 4: 跑測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`
Expected: 全綠（含既有 MainWindowViewModel 測試零回歸）。

- [ ] **Step 5: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs src/MoldplanDbSwitcher/Views/MainWindow.axaml tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: 主視窗支援自動下載更新與一鍵重啟套用"
```

---

### Task 5: release.yml — vpk pack 產 Velopack 資產

**Files:**
- Modify: `.github/workflows/release.yml`（build-windows job 與 create-release job）

**Interfaces:**
- Consumes: 既有 `publish/win-x64` 輸出、`steps.get-version.outputs.version`。
- Produces: GitHub Release 資產含 `MoldplanDbSwitcher-win-Setup.exe`、`*-full.nupkg`、`RELEASES`（Velopack `GithubSource` 讀取所需）。

- [ ] **Step 1: build-windows job 在「建立壓縮包」之後加**

```yaml
      - name: 安裝 Velopack CLI
        run: dotnet tool install -g vpk

      - name: 建立 Velopack 安裝包
        run: vpk pack -u MoldplanDbSwitcher -v ${{ steps.get-version.outputs.version }} -p publish/win-x64 -e MoldplanDbSwitcher.exe --packTitle "MoldplanDbSwitcher" -o Releases

      - name: 上傳 Velopack 構件
        uses: actions/upload-artifact@v4
        with:
          name: windows-velopack
          path: Releases/*
          retention-days: 30
```

- [ ] **Step 2: create-release job 的「整理發布檔案」加一行**

```yaml
          cp artifacts/windows-velopack/* release-files/ 2>/dev/null || true
```

- [ ] **Step 3: 本機驗證 YAML 與 vpk 指令**

Run: `dotnet tool install -g vpk`（若未裝）後在本機 dry-run 驗證指令可跑：
`dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r win-x64 --self-contained -o publish/win-x64 -p:Version=0.0.1 && vpk pack -u MoldplanDbSwitcher -v 0.0.1 -p publish/win-x64 -e MoldplanDbSwitcher.exe --packTitle "MoldplanDbSwitcher" -o Releases`
Expected: `Releases/` 產出 `MoldplanDbSwitcher-win-Setup.exe`、`MoldplanDbSwitcher-0.0.1-full.nupkg`、`RELEASES`。驗證後刪除本機 `publish/win-x64` 與 `Releases/` 產物（不入版控）。

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: release 加入 Velopack 安裝包產出"
```

---

### Task 6: 收尾驗證

**Files:**
- 無新檔；全方案驗證。

- [ ] **Step 1: 全建置 + 全測試**

Run: `dotnet build && dotnet test`
Expected: 成功、全綠。

- [ ] **Step 2: 確認 git 狀態乾淨**

Run: `git status --short`
Expected: 無未追蹤的產物（publish/、Releases/ 已清）。

- [ ] **Step 3:（發版時）一次性轉換提醒**

發第一個含本功能的 tag 後：使用者手動下載 `MoldplanDbSwitcher-win-Setup.exe` 安裝一次；
之後啟動 app 即自動更新。此步驟為人工操作，不在程式碼範圍。
