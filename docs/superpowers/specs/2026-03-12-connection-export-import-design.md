# 連線設定匯出/匯入功能設計

## 概述

為 MoldplanDbSwitcher 新增資料庫連線設定的匯出與匯入功能，格式與 TableSpec 完全相容（`.json` 純文字 / `.tsjson` AES 加密），可跨應用程式交換連線設定。

## 1. Model 調整

### 1.1 ConnectionProfile 對齊 TableSpec

新增欄位：

| 欄位 | 型別 | 說明 |
|------|------|------|
| `AuthType` | `AuthenticationType` enum | `WindowsAuthentication` / `SqlServerAuthentication` |
| `IsDefault` | `bool` | 是否為預設連線 |

新增列舉：

```csharp
public enum AuthenticationType
{
    WindowsAuthentication = 0,
    SqlServerAuthentication = 1
}
```

`Source` 屬性保留為 `[JsonIgnore]` 計算屬性，不參與序列化。

**向下相容：** JSON 反序列化設定 `PropertyNameCaseInsensitive = true`，缺少 `AuthType` 時預設為 `WindowsAuthentication`，缺少 `IsDefault` 時預設為 `false`。

### 1.2 新增 ConnectionExportData

```csharp
public class ConnectionExportData
{
    public int Version { get; init; } = 1;
    public DateTime ExportedAt { get; init; } = DateTime.UtcNow;
    public required IReadOnlyList<ConnectionProfile> Profiles { get; init; }
}
```

## 2. Service 層

### 2.1 IConnectionExportService 介面

```csharp
public interface IConnectionExportService
{
    byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords);
    byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords);
    ConnectionExportData ImportFromJson(byte[] data);
    ConnectionExportData ImportFromEncryptedJson(byte[] data, string password);
    bool IsEncryptedFormat(byte[] data);
}
```

### 2.2 ConnectionExportService 實作

**加密方案（與 TableSpec 相同）：**

- 演算法：AES-256-CBC
- 金鑰衍生：PBKDF2 with SHA-256, 100,000 iterations
- 隨機化：16 bytes Salt + 16 bytes IV
- Magic Bytes：`TSEC`（4 bytes，用於格式識別）

**加密格式二進制結構：**

```
[TSEC 4 bytes][Salt 16 bytes][IV 16 bytes][AES 加密的 JSON 內容]
```

**純文字 JSON 格式：**

```json
{
    "Version": 1,
    "ExportedAt": "2026-03-12T10:30:00Z",
    "Profiles": [
        {
            "Name": "生產環境",
            "Server": "db-server",
            "Database": "MyDB",
            "AuthType": 0,
            "Username": null,
            "Password": null,
            "IsDefault": false
        }
    ]
}
```

**密碼處理邏輯：**

- `includePasswords = false` 時，匯出前將 Password 欄位設為 null
- 加密格式預設 `includePasswords = true`
- 純文字格式預設 `includePasswords = false`

**副檔名：**

| 格式 | 副檔名 | 說明 |
|------|--------|------|
| 純文字 JSON | `.json` | 可直接以文字編輯器開啟 |
| 加密 JSON | `.tsjson` | 與 TableSpec 相容的加密格式 |

### 2.3 對現有 Service 的影響

`ConnectionProfile` 結構變更影響：

- **ConnectionSourceService** — 載入 TableSpec JSON 時需對應新欄位
- **SettingsService** — 自訂連線的序列化/反序列化需含新欄位
- **SqlConnectionFactory** — 依 `AuthType` 決定使用 Windows 驗證或 SQL 帳號密碼
- **ServerTxtService** — 無影響（僅使用 Server/Database）

## 3. ViewModel 層

### 3.1 ExportConnectionsViewModel

**屬性：**

- `ProfileSelections` (ObservableCollection\<ProfileSelectionItem\>) — 可勾選的連線清單
- `UseEncryption` (bool) — 是否使用加密格式
- `IncludePasswords` (bool) — 是否包含密碼
- `EncryptionPassword` (string) — 加密密碼
- `ConfirmPassword` (string) — 確認密碼

**ProfileSelectionItem：**

- `Profile` (ConnectionProfile)
- `IsSelected` (bool, ObservableProperty)

**命令：**

- `SelectAllCommand` / `DeselectAllCommand`

**方法：**

- `GetExportData()` → byte[] — 根據選項呼叫對應的 `IConnectionExportService` 方法

**預設行為：**

- 切換到加密模式時，`IncludePasswords` 自動設為 true
- 切換到純文字模式時，`IncludePasswords` 自動設為 false

### 3.2 ImportConnectionsViewModel

**屬性：**

- `NeedsPassword` (bool) — 是否需要解密密碼
- `DecryptPassword` (string)
- `ErrorMessage` (string) — 錯誤訊息
- `ImportPreviews` (ObservableCollection\<ImportPreviewItem\>) — 匯入預覽清單

**ImportPreviewItem：**

- `Profile` (ConnectionProfile)
- `HasConflict` (bool) — 是否與現有連線名稱衝突（大小寫無關）
- `ExistingProfile` (ConnectionProfile?) — 衝突的現有連線
- `ConflictAction` (enum: Overwrite / Skip, ObservableProperty)

**命令：**

- `OverwriteAllCommand` / `SkipAllCommand` — 批量處理衝突

**方法：**

- `LoadImportData(byte[] data)` — 偵測格式，設定 NeedsPassword
- `DecryptAndLoad()` — 解密並載入預覽
- `ExecuteImport()` → ImportResult — 執行匯入，回傳統計

**ImportResult：**

```csharp
public class ImportResult
{
    public int Added { get; init; }
    public int Skipped { get; init; }
    public int Overwritten { get; init; }
}
```

## 4. View 層

### 4.1 ExportConnectionsWindow

```
[標題] 選擇要匯出的連線
├─ [全選][取消全選] 按鈕
├─ [CheckBox] 連線清單（顯示名稱和伺服器）
├─ ─────────── 分隔線 ─────────
├─ 匯出格式:
│  ○ 純文字 JSON (.json)
│  ○ 加密 JSON (.tsjson)
├─ ☑ 包含密碼
└─ 加密密碼 (條件顯示, UseEncryption = true)
   ├─ [PasswordBox] 加密密碼
   └─ [PasswordBox] 確認密碼

底部: [匯出] [取消]
```

**Code-behind 邏輯：**

1. 驗證至少選擇一個連線
2. 驗證加密密碼相符（若使用加密）
3. 開啟 SaveFileDialog（副檔名根據格式動態設置）
4. 呼叫 `vm.GetExportData()` 取得 byte[]
5. 寫入檔案並關閉視窗

### 4.2 ImportConnectionsWindow

**狀態 1：需要密碼** (`NeedsPassword = true`)

```
此檔案為加密格式，請輸入解密密碼：
[PasswordBox] 解密密碼
[錯誤訊息] (紅色，條件顯示)
[解密] 按鈕
```

**狀態 2：顯示預覽** (`NeedsPassword = false`)

```
即將匯入的連線設定：
[全部覆蓋][全部跳過] 按鈕
┌─────────────────────────────┐
│ 連線名稱        (衝突)       │ ← HasConflict 時顯示橙色標籤
│ 伺服器位址      (灰色)       │
│ [覆蓋 ○ / 跳過 ○]           │ ← 衝突時顯示
└─────────────────────────────┘

底部: [匯入] [取消]
```

**Code-behind 邏輯：**

1. 解密按鈕呼叫 `vm.DecryptAndLoad()`
2. 匯入按鈕呼叫 `vm.ExecuteImport()` 取得 ImportResult
3. Close(result) 返回結果

## 5. 主視窗整合

### 5.1 選單列

MainWindow.axaml 新增選單列：

```xml
<Menu>
  <MenuItem Header="檔案(_F)">
    <MenuItem Header="匯出連線設定(_X)" Command="{Binding ExportConnectionsCommand}"/>
    <MenuItem Header="匯入連線設定(_I)" Command="{Binding ImportConnectionsCommand}"/>
  </MenuItem>
</Menu>
```

### 5.2 MainWindowViewModel 新增命令

- `ExportConnectionsCommand` — 開啟 ExportConnectionsWindow 模態對話框
- `ImportConnectionsCommand` — 開啟檔案選擇對話框 → 讀取 byte[] → 開啟 ImportConnectionsWindow → 完成後重新載入連線清單

## 6. DI 註冊

Program.cs 新增：

```csharp
services.AddSingleton<IConnectionExportService, ConnectionExportService>();
```

## 7. 測試計畫

| 測試檔案 | 覆蓋範圍 |
|----------|----------|
| `Models/ConnectionExportDataTests.cs` | 模型預設值、序列化 |
| `Services/ConnectionExportServiceTests.cs` | 匯出/匯入純文字、加密、格式偵測、密碼錯誤 |
| `ViewModels/ExportConnectionsViewModelTests.cs` | 選擇邏輯、加密切換、匯出資料生成 |
| `ViewModels/ImportConnectionsViewModelTests.cs` | 格式偵測、衝突檢測、批量操作、匯入執行 |
| 現有測試更新 | ConnectionProfile 新欄位的向下相容驗證 |

## 8. 錯誤處理

| 情況 | 處理方式 |
|------|----------|
| 加密密碼錯誤 | ImportConnectionsViewModel 設置 ErrorMessage，UI 顯示紅色提示 |
| 檔案格式不正確 | 反序列化異常 → ErrorMessage |
| 無選擇連線匯出 | 驗證攔截，不開啟儲存對話框 |
| 密碼不一致 | 驗證攔截，提示使用者 |
