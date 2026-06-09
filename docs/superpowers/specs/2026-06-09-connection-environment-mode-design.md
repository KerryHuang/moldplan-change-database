# MoldplanDbSwitcher 連線環境模式 — 設計規格

- 日期：2026-06-09
- 狀態：已核准，待實作
- 對齊來源：DatabaseDescriptionApp（Specurai）的「連線環境欄位 + Production 防呆 + 選擇器統一顯示排序」功能

## 目標

讓 MoldplanDbSwitcher 套用與姊妹專案 DatabaseDescriptionApp 相同的連線環境模式：

1. **環境欄位 + 編輯表單**：`ConnectionProfile` 新增環境欄位（Development/Testing/Staging/Production），ConnectionDialog 加環境下拉。
2. **選擇器統一顯示 + 排序**：所有連線選擇器顯示 `【環境簡稱】名稱 (預設)`，並依 預設→環境→名稱 排序；主視窗 DataGrid 加「環境」欄。
3. **Production 防呆**：對 Production 連線的重大操作（套用連線寫 SERVER.txt、刪除自訂連線、匯入覆蓋）顯示紅色警告橫幅確認。

顯示格式、環境簡稱（開發/測試/預備/正式）、排序規則均**沿用姊妹專案的既定決策**，以維持跨 app 一致。

## 背景與限制

### 專案現況
- 單一專案 MVVM（非 Clean Architecture），.NET 9，Avalonia 11.3 + Semi.Avalonia，CommunityToolkit.Mvvm。
- 有測試專案 `tests/MoldplanDbSwitcher.Tests`（xUnit）。CLAUDE.md 律法：繁體中文、TDD、Interface-first Services。
- `Models/ConnectionProfile.cs`：`[JsonPropertyName]` camelCase、`AuthType` enum 數字序列化、`[JsonIgnore] Source`（"Custom"/"Specurai"/"Ansible"）。**目前無環境欄位**。
- 連線來源：`ConnectionSourceService` 載入自有 `%AppData%/MoldplanDbSwitcher/connections.json`（`SettingsService`）、Specurai 的 `%AppData%/Specurai/connections.json`（唯讀）、Ansible 同步結果。`MainWindowViewModel.LoadConnections` 合併三者，**目前無排序**。
- 既有確認對話框：`DropConfirmDialog`（輸入資料庫名稱確認），用於 Reporting DROP。

### 跨 app 序列化相容性（關鍵）
- Specurai 將 `Environment` 以**數字**序列化（PascalCase `"Environment"`）。
- MoldplanDbSwitcher 讀 Specurai JSON 時使用 `PropertyNameCaseInsensitive = true`，故 `"Environment"` 會對應到本專案的 `environment` 屬性；只要列舉**同順序**（Development=0…Production=3）且本專案也用**數字**序列化，即可正確讀出 Specurai 連線的真實環境。
- ⚠️ 因此本專案**不可**引入全域 `JsonStringEnumConverter`（會破壞 `authType` 與跨 app 的數字相容）。
- MoldplanDbSwitcher 只**讀**取 Specurai 檔案、從不回寫；自有 connections.json 僅本專案使用。故新增欄位對 Specurai 零影響。

### 預設值
- 自有 connections.json 舊資料缺 `environment` → 屬性初始值落在 **Staging**。
- 新建自訂連線預設 Staging。

## 設計

### 1. 環境列舉與模型

新增 `src/MoldplanDbSwitcher/Models/DatabaseEnvironment.cs`：

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

`Models/ConnectionProfile.cs` 新增屬性（數字序列化、camelCase 屬性名）：

```csharp
[JsonPropertyName("environment")]
public DatabaseEnvironment Environment { get; set; } = DatabaseEnvironment.Staging;
```

### 2. 各來源的環境決定
- **自訂**：ConnectionDialog 環境下拉 → 寫入自有 JSON。
- **Specurai**：`ConnectionSourceService.LoadSpecuraiConnections()` 反序列化即自動帶入（缺欄位 → Staging）。
- **Ansible**：新增 `Models/DatabaseEnvironmentInference.cs`：

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

於載入 Ansible 連線時套用 `p.Environment = DatabaseEnvironmentInference.FromName(p.Name)`。

### 3. 排序：ConnectionProfileComparer

新增 `src/MoldplanDbSwitcher/Models/ConnectionProfileComparer.cs`（與 Specurai 同邏輯）：

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

於 `MainWindowViewModel.LoadConnections` 合併三來源後、指派 `Connections` 前以此比較器排序。

### 4. 顯示轉換器

新增 `src/MoldplanDbSwitcher/Converters/` 資料夾：

- `DatabaseEnvironmentDisplayConverter.cs`：`DatabaseEnvironment` → 繁中（開發環境/測試環境/預備環境/正式環境），供 ConnectionDialog 環境下拉與 DataGrid 環境欄顯示。
- `ConnectionProfileDisplayConverter.cs`：`ConnectionProfile` → `【{環境簡稱}】{名稱}`（簡稱：開發/測試/預備/正式），預設加 ` (預設)`；非 ConnectionProfile 回 `value?.ToString()`。

於 `src/MoldplanDbSwitcher/App.axaml` 新增 `xmlns:converters="using:MoldplanDbSwitcher.Converters"` 與 `<Application.Resources>` 註冊兩者。

### 5. 各選擇器套用
- **主視窗連線 ComboBox**：ItemTemplate 改用 `ConnectionProfileDisplayConverter`。
- **主視窗 DataGrid**：新增「環境」欄，以 `DatabaseEnvironmentDisplayConverter` 顯示繁中。其餘欄位（Source/Name/Server/Database）保留。
- **匯出 / 匯入視窗清單**：項目標籤改用 `{Binding Profile, Converter={StaticResource ConnectionProfileDisplayConverter}}`。
- **ConnectionDialog**：新增「環境」`ComboBox`（`ItemsSource` 為四個列舉值，`SelectedItem` 綁定環境；以 `DatabaseEnvironmentDisplayConverter` 顯示繁中），預設 Staging。

`SelectedItem`/`IsChecked` 等選取綁定維持不變，僅改顯示文字與新增環境欄/下拉。

### 6. Production 防呆（紅色警告橫幅）

新增 `src/MoldplanDbSwitcher/Views/ConfirmDialog.axaml(.cs)`：支援可選的紅色警告橫幅（仿 Specurai：`ConfirmDialog(message, warningBanner)`，`warningBanner` 非空白時顯示紅框警告）。

`MainWindowViewModel` 新增確認回呼 `public Func<string, Task<bool>>? ConfirmCallback { get; set; }`（由 View 在 code-behind 設定為顯示 ConfirmDialog）。在下列操作於目標連線環境為 Production 時，先以橫幅文字 `⚠ 正式環境 (Production)：{資料庫}` 確認，未確認則中止：

- **套用連線（`ApplyChanges` → 寫 SERVER.txt）**：目標為 `SelectedConnection`。
- **刪除自訂連線（`DeleteCustomConnection`）**：目標為被刪連線。
- **匯入覆蓋**：若匯入清單含 Production 連線則確認。

非 Production 時行為與現狀相同（不額外確認）。

## 測試（TDD，`tests/MoldplanDbSwitcher.Tests`）

- `ConnectionProfileComparerTests`：預設優先、環境順序、名稱排序、null。
- `ConnectionProfileDisplayConverterTests`：四環境×預設/非預設、非 ConnectionProfile 回原值。
- `DatabaseEnvironmentDisplayConverterTests`：四環境對應繁中。
- `DatabaseEnvironmentInferenceTests`：含「正式」→Production、含「測試」→Testing、其餘/空→Staging。
- `ConnectionProfile` 序列化：環境數字往返；缺 `environment` 欄位反序列化 → Staging；以 Specurai 式 PascalCase 數字（`PropertyNameCaseInsensitive`）反序列化 → 正確環境。
- `ConnectionDialogViewModelTests`：環境預設 Staging、可設定與讀取。
- `MainWindowViewModelTests`：LoadConnections 後依 預設→環境→名稱 排序；Ansible 連線套用名稱推斷；`ApplyChanges` 在 ConfirmCallback 回 false 時不呼叫 `ServerTxtService.Apply`（Production 目標）。

## 不在範圍內（Out of Scope）
- ConnectionDialog 不擴充驗證類型/帳號密碼/預設勾選（僅新增環境）。
- 不修改 Specurai（DatabaseDescriptionApp）任何程式碼。
- 不改變 Ansible 同步本身的資料格式（僅在載入時推斷環境）。
- 報表來源對話（ReportSourceDialog）維持現有的來源類別篩選，不套用本顯示格式。
