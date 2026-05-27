# App 更新提醒設計

## 目標

MoldplanDbSwitcher 啟動時自動向 GitHub Releases API 查詢最新版號，若高於目前執行版本則在主視窗顯示提醒列（含「下載新版」按鈕開瀏覽器到 release 頁），讓使用者能即時知道有新版可下載。

**範圍限定為「提醒」**——不自動下載、不自動安裝、不背景輪詢。僅啟動時查一次。

## 設計決策（已確認）

| 決策 | 選擇 | 理由 |
|---|---|---|
| 自動化程度 | 僅提醒 + 連結 | 入門最簡，跨平台無安裝問題 |
| 檢查時機 | 啟動時自動 | 不干擾，無新版完全靜音 |
| 認證 | 使用者自填 PAT | Repo 為私人，避免內嵌 token 反編譯風險 |
| 失敗處理 | 靜音失敗 | 不打擾正常使用 |

## Repo 識別

GitHub Repo: `KerryHuang/moldplan-change-database`（hard-coded 在 `UpdateCheckService` 常數，因 App 與該 Repo 一對一綁定）。

## 元件結構

```
src/MoldplanDbSwitcher/
├── Models/
│   ├── AppSettings.cs                ← 新增 GitHubToken 屬性
│   └── UpdateInfo.cs                 ← 新檔
├── Services/
│   ├── IUpdateCheckService.cs        ← 新檔
│   └── UpdateCheckService.cs         ← 新檔
├── ViewModels/
│   └── MainWindowViewModel.cs        ← 加入 UpdateAvailable / UpdateInfo / commands
└── Views/
    ├── MainWindow.axaml              ← 頂端 banner UI
    ├── MainWindow.axaml.cs           ← 「下載新版」開瀏覽器
    ├── SettingsDialog.axaml          ← 加 GitHub PAT 欄位
    └── SettingsDialog.axaml.cs       ← 讀寫 PAT

tests/MoldplanDbSwitcher.Tests/
├── Services/
│   └── UpdateCheckServiceTests.cs    ← 新檔
└── ViewModels/
    └── MainWindowViewModelTests.cs   ← 補測 banner 屬性
```

## Data Model

### UpdateInfo（新 record）

```csharp
public record UpdateInfo(
    string LatestVersion,    // 例 "1.2.0"（已去掉 v 前綴）
    string ReleaseUrl,       // GitHub release html_url
    string ReleaseNotes);    // body（release notes），可能為空
```

### AppSettings 新欄位

```csharp
public string? GitHubToken { get; set; }
```

序列化進既有 `%AppData%/MoldplanDbSwitcher/app-settings.json`。

## Service: IUpdateCheckService

```csharp
public interface IUpdateCheckService
{
    Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);
}
```

### 行為契約

| 情境 | 回傳 |
|---|---|
| token 為 null / 空 / 純空白 | `null` |
| HTTP 200 且最新 tag > 目前版本 | `UpdateInfo` |
| HTTP 200 且最新 tag ≤ 目前版本 | `null` |
| HTTP 200 但 tag 格式無效（非 `v\d+\.\d+\.\d+`） | `null` |
| HTTP 4xx / 5xx | `null` |
| 網路例外 / 逾時 | `null` |
| JSON 解析失敗 | `null` |

**任何錯誤都不拋出例外**，皆回 `null`。內部可以 `System.Diagnostics.Debug.WriteLine` 記錄方便開發階段觀察，但不影響使用者。

### 實作要點

```csharp
public class UpdateCheckService : IUpdateCheckService
{
    private const string RepoOwner = "KerryHuang";
    private const string RepoName = "moldplan-change-database";
    private const string UserAgent = "MoldplanDbSwitcher-UpdateCheck";

    private readonly HttpClient _http;
    private readonly Version _currentVersion;

    // 建構式注入 HttpClient（測試可換 HttpMessageHandler）+ 目前版本
    // 預設 ctor：new HttpClient { Timeout = TimeSpan.FromSeconds(10) }
    // 預設版本：Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0,0,0)

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

            var tagName = root.GetProperty("tag_name").GetString();    // "v1.2.0"
            var htmlUrl = root.GetProperty("html_url").GetString();    // release 頁
            var body = root.TryGetProperty("body", out var b) ? b.GetString() ?? "" : "";

            if (string.IsNullOrEmpty(tagName) || string.IsNullOrEmpty(htmlUrl))
                return null;

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

### 版本比對規則

使用 `System.Version` 的 `>` 運算子（依 Major / Minor / Build / Revision 排序）。

`v1.2.0` 解析成 `Version(1, 2, 0)`，與 Assembly 的 `Version` 比較。注意 csproj 已透過 GitHub Action 在 release 時動態設定版本，目前 `AssemblyVersion` 對得上 tag。

## ViewModel: MainWindowViewModel 變更

加入 fields / properties：

```csharp
private readonly IUpdateCheckService _updateCheckService;

[ObservableProperty] private bool _updateAvailable;
[ObservableProperty] private string _updateBannerText = "";
[ObservableProperty] private string? _updateReleaseUrl;
```

建構式新增 `IUpdateCheckService updateCheckService` 參數（追加到尾端）。

ctor 結尾（在 `LoadConnections()` / `DiscoverServerTxtFiles()` 之後）：
```csharp
_ = CheckForUpdatesAsync();
```

新增方法：
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

## View: MainWindow.axaml

在頂端「目前連線」Border **上方**新增提醒列（IsVisible 綁 UpdateAvailable）：

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

`MainWindow.axaml.cs` 加 handler：
```csharp
private void OnDownloadUpdateClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is MainWindowViewModel vm && !string.IsNullOrEmpty(vm.UpdateReleaseUrl))
    {
        Process.Start(new ProcessStartInfo(vm.UpdateReleaseUrl) { UseShellExecute = true });
    }
}
```

`UseShellExecute = true` 在 Windows / macOS / Linux 都會用預設瀏覽器開 URL。

## SettingsDialog 變更

AXAML 加入：
```xml
<StackPanel Spacing="4">
  <TextBlock Text="GitHub PAT (檢查更新用)：" />
  <TextBox x:Name="GitHubTokenBox" PasswordChar="●"
           Watermark="留白則不檢查更新" />
  <TextBlock FontSize="10" Foreground="Gray" TextWrapping="Wrap"
             Text="使用 fine-grained PAT，只授予該 Repo 的 Read access。" />
</StackPanel>
```

code-behind ctor 載入時 `GitHubTokenBox.Text = settings.GitHubToken ?? ""`；OnSaveClick 寫回 `GitHubToken = string.IsNullOrWhiteSpace(GitHubTokenBox.Text) ? null : GitHubTokenBox.Text`。

## DI 註冊（Program.cs）

```csharp
services.AddSingleton<HttpClient>(_ => new HttpClient { Timeout = TimeSpan.FromSeconds(10) });
services.AddSingleton<IUpdateCheckService, UpdateCheckService>();
```

`UpdateCheckService` 構造式接受 `HttpClient` 與一個可覆寫的 `Version`（測試用，正常路徑用 Assembly 版本）。

## 測試

### UpdateCheckServiceTests

不打真 GitHub API。用 `HttpMessageHandler` mock（或自寫 `FakeHttpMessageHandler`）注入 HttpClient 控制回應。

| 測試 | 情境 | 預期 |
|---|---|---|
| `CheckAsync_NullToken_ReturnsNull` | token = null | null |
| `CheckAsync_EmptyToken_ReturnsNull` | token = "" / 空白 | null |
| `CheckAsync_NewerVersionAvailable_ReturnsInfo` | API 回 `tag_name: "v2.0.0"`，current=1.1.2 | UpdateInfo("2.0.0", url, body) |
| `CheckAsync_SameVersion_ReturnsNull` | API 回 v1.1.2，current=1.1.2 | null |
| `CheckAsync_OlderVersion_ReturnsNull` | API 回 v1.0.0，current=1.1.2 | null |
| `CheckAsync_HttpError_ReturnsNull` | mock 回 401 / 404 / 500 | null |
| `CheckAsync_NetworkException_ReturnsNull` | mock 拋 HttpRequestException | null |
| `CheckAsync_InvalidTagFormat_ReturnsNull` | tag_name = "release-foo" | null |
| `CheckAsync_MalformedJson_ReturnsNull` | API 回 "not json" | null |

### MainWindowViewModelTests 補測

| 測試 | 情境 | 預期 |
|---|---|---|
| `Constructor_NoUpdateAvailable_BannerHidden` | mock 回 null | UpdateAvailable=false |
| `Constructor_UpdateAvailable_BannerShown` | mock 回 UpdateInfo | UpdateAvailable=true，UpdateReleaseUrl 設好 |
| `DismissUpdateCommand_HidesBanner` | banner 顯示中 | UpdateAvailable=false |

## 邊界與注意事項

- **第一次啟動**：使用者還沒填 PAT → token 為空 → 不查 → 正常啟動，不顯示 banner
- **GitHub API rate limit**：authenticated user 5000/h，個人使用遠超不到
- **csproj 版本**：目前 csproj 沒有 `<Version>` 設定，Assembly version 預設 `0.0.0.0`，需要 release pipeline 注入 version 或在 csproj 設 `<Version>$(GITHUB_REF_NAME)</Version>` 或讓 dotnet publish 時 `-p:Version=...`。**檢查現有 release.yml 是否注入版本；若沒有，這個檢查永遠會說「有新版」**。屬於前置條件，計畫第一步要驗證並補上
- **macOS Gatekeeper**：使用者下載新 zip 後，第一次執行需 `chmod +x` 與 `xattr -d com.apple.quarantine`，README 已說明
- **Self-host 應用程式更新與 SSL**：使用 `HttpClient` 預設信任作業系統的 root CA，內網 SSL 中間人代理可能擋下 api.github.com，靜音失敗已涵蓋
- **TaskCanceledException**：10 秒逾時保護啟動體驗

## 不在範圍內

明確排除（未來可擴充）：
- 自動下載 / 自動安裝
- 版本忽略（「不再提醒此版本」）
- 增量更新 / delta patch
- 公開 Repo 無 token 模式
- 多 Repo / 多更新管道

## 開發前提條件

實作前需先確認 / 修正：

1. **csproj 加入版本注入**：在 `MoldplanDbSwitcher.csproj` 加 `<Version>1.0.0</Version>`（預設 fallback），並修改 `release.yml` 在 dotnet publish 時加 `-p:Version=${{ steps.get-version.outputs.version }}` 讓 Assembly version 與 tag 對齊
2. 確認 GitHub PAT 在私人 Repo 上能存取 `releases/latest` endpoint（Repo 權限只需 Contents: Read）
