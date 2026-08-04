# MoldplanDbSwitcher Velopack 自動更新設計

日期：2026-08-04
狀態：已與使用者確認

## 背景

現有更新機制（`UpdateCheckService`）只做「檢查＋橫幅通知＋連結」，使用者需手動下載
zip 解壓。需求：Windows 版升級為 Velopack 全自動更新（比照 Specurai），
開啟 app 時自動檢查、自動下載，重啟即完成。

前提事實：

- Repo 為 **private**，更新來源沿用 GitHub Release，以使用者設定的
  `GitHubToken` 授權（選項 B；目前僅一位使用者）。
- 現行 release 產物是純 zip（win-x64 + osx-arm64 + osx-x64）。
- 使用者在 Windows；macOS 產物無人使用。

## 需求決策（已確認）

| 決策點 | 結論 |
|---|---|
| 更新來源 | GitHub private Release + 使用者 GitHubToken（Velopack `GithubSource`） |
| 平台範圍 | 僅 Windows 走 Velopack；macOS 維持現有 zip 與「通知＋連結」 |
| 更新 UX | 啟動自動檢查 → 背景自動下載 → 橫幅「已下載 vX.Y.Z，重啟以完成更新」＋按鈕 → 點擊套用重啟 |
| 非 Velopack 安裝 | 退回現有「通知＋連結」行為（含直接跑 publish 資料夾、macOS） |
| token 過期／失敗 UI | 不做，維持靜音（Trace）；僅單一使用者 |

## 架構

```
MainWindowViewModel ──→ IUpdateCheckService（既有，簽章擴充）
                            │
                            ├─ VelopackUpdateService（新，Windows + IsInstalled）
                            │     UpdateManager + GithubSource(repoUrl, token, prerelease:false)
                            │     CheckAsync → 自動 DownloadAsync → CanAutoApply=true
                            │     ApplyAndRestart()
                            │
                            └─ UpdateCheckService（既有，GitHub API 通知＋連結）
                                  CanAutoApply=false（fallback：macOS／非 Velopack 安裝）
```

分派邏輯（factory 或組合服務）：`OperatingSystem.IsWindows() && manager.IsInstalled`
→ Velopack 路徑；否則 fallback。依 Law 3，Velopack 包在 interface 後面，
建構式可注入假實作供測試。

## 變更明細

### App 端（src/MoldplanDbSwitcher）

- `Program.cs`：`Main` 開頭加 `VelopackApp.Build().Run();`（Velopack 必要掛鉤）。
- csproj：加 `Velopack` PackageReference（版本比照 Specurai 使用的線上最新穩定版）。
- `Models/UpdateInfo`：加 `CanAutoApply`（bool）。
- `Services/IUpdateCheckService`：擴充
  ```csharp
  Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);   // 既有
  Task DownloadAsync(IProgress<int>? progress = null, CancellationToken ct = default); // 新
  void ApplyAndRestart();                                                        // 新
  ```
  既有 `UpdateCheckService` 對新方法丟 `InvalidOperationException`
  （fallback 路徑不會呼叫）。
- 新 `Services/VelopackUpdateCheckService`：實作上述介面；
  `CheckAsync` 內 `UpdateManager.CheckForUpdatesAsync`；
  token 為空時回 null（private repo 無授權注定失敗，不嘗試）。
- `MainWindowViewModel.CheckForUpdatesAsync`：
  - `info.CanAutoApply == true` → 自動 `DownloadAsync` → 橫幅
    「⬇ 已下載 vX.Y.Z，重啟以完成更新」＋「重啟更新」按鈕（`ApplyAndRestartCommand`）。
  - `CanAutoApply == false` → 現有橫幅＋連結行為不變。
  - 失敗靜音（維持現有 catch 風格）。

### 發布端（.github/workflows/release.yml）

Windows job 在 publish 後加：

```
dotnet tool install -g vpk
vpk pack -u MoldplanDbSwitcher -v {version} -p publish/win-x64 \
    -e MoldplanDbSwitcher.exe --packTitle "MoldplanDbSwitcher" -o Releases
```

上傳 `Releases/`（`MoldplanDbSwitcher-win-Setup.exe`、`*-full.nupkg`、`RELEASES`…）
到 GitHub Release；既有 zip 產物照舊。macOS job 不動。

## 一次性轉換

現行解壓 zip 的使用方式 Velopack 不認得（`IsInstalled == false`）。
第一個含本功能的 release 發布後，使用者需手動下載 `Setup.exe` 安裝一次，
之後全自動。

## 錯誤處理

- token 空／過期、網路失敗、GitHub 4xx/5xx：靜默回 null（Trace 記錄），無 UI。
- 下載失敗：橫幅不出現（維持靜音）。
- 非 Velopack 安裝：`IsInstalled == false` → fallback 到通知模式，不拋錯。

## 測試策略（TDD，Law 2/3）

- `VelopackUpdateCheckService`：token 空 → 回 null 且不初始化 UpdateManager（可離線驗證）。
- 分派邏輯：Windows+installed → Velopack；否則 fallback（以注入的假 manager/介面驗證）。
- `MainWindowViewModel`：
  - `CanAutoApply=true` → 呼叫 `DownloadAsync`、橫幅文字含「重啟」、命令可執行。
  - `CanAutoApply=false` → 維持既有橫幅與 `UpdateReleaseUrl` 行為（既有測試不得回歸）。
  - 下載拋例外 → 橫幅不出現、不拋出。
- 既有 `UpdateCheckService` 測試零回歸。

## 不做範圍

- macOS 自動更新、token 過期提醒、更新失敗 UI、進度條 UI。
