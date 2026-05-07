# 資料庫連線切換工具 (MoldplanDbSwitcher)

跨平台桌面應用程式，用於切換 WDMIS 系統的資料庫連線設定。選擇資料庫連線後，自動替換 `SERVER.txt` 中的伺服器位址與資料庫名稱，以及 .NET 專案的 `appsettings.Development.json` 中的 MSSQL 連線設定。

## 功能

- 讀取 [TableSpec (DatabaseDescriptionApp)](https://github.com/KerryHuang/DatabaseDescriptionApp) 的連線設定
- 支援新增、編輯、刪除自訂連線
- 自動搜尋 WDMIS 目錄下的 `SERVER.txt`
- 顯示變更前後對比，確認後套用
- 支援同時修改多個 `SERVER.txt`
- **套用開發設定**：掃描指定目錄下所有含 MSSQL 區塊的 `appsettings.Development.json`，勾選後批次更新

## SERVER.txt 格式

單行，以逗號分隔，僅替換第 2 欄（資料庫名稱）和第 3 欄（伺服器位址）：

```
欄位1,資料庫名稱,伺服器位址,欄位4,欄位5
```

範例：
```
app,my-database,192.168.1.100,XXX,1
```

## 預設搜尋路徑

| 平台 | 路徑 |
|------|------|
| Windows | `C:\WDMIS\SERVER.txt`、`D:\WDMIS\SERVER.txt` |
| macOS / Linux | `~/WDMIS/SERVER.txt` |

## 套用開發設定（appsettings.Development.json）

在「設定」視窗指定「開發目錄」後，主視窗會出現「套用開發」按鈕。點擊後：

1. 遞迴掃描目錄下所有含完整 MSSQL 區塊的 `appsettings.Development.json`（排除 `bin`、`obj` 目錄）
2. 對話框顯示套用預覽（Host、Port、UserId、Password、ApplicationDatabase）
3. 勾選要更新的檔案，確認後批次套用

僅更新 MSSQL 區塊的以下五個欄位，其他欄位（如 `LocalizationDatabase`、`QuartzJobDatabase`）保留不動：

| 欄位 | 來源 |
|------|------|
| `Host` | 連線的 Server（逗號前） |
| `Port` | 連線的 Server（逗號後，預設 `1433`） |
| `UserId` | 連線的 Username |
| `Password` | 連線的 Password |
| `ApplicationDatabase` | 連線的 Database |

## 連線設定來源

| 來源 | 路徑 | 說明 |
|------|------|------|
| TableSpec | `%AppData%/TableSpec/connections.json` | 與 DatabaseDescriptionApp 共用（唯讀） |
| 自訂 | `%AppData%/MoldplanDbSwitcher/connections.json` | 本應用程式管理 |

## 下載與執行

從 `publish/` 目錄取得對應平台的執行檔，不需安裝 .NET runtime：

| 平台 | 檔案 |
|------|------|
| Windows x64 | `publish/win-x64/MoldplanDbSwitcher.exe` |
| macOS ARM64 (Apple Silicon) | `publish/osx-arm64/MoldplanDbSwitcher` |

macOS 首次執行前需賦予執行權限：

```bash
chmod +x MoldplanDbSwitcher
./MoldplanDbSwitcher
```

## 從原始碼建置

### 需求

- .NET 9 SDK

### 建置與執行

```bash
dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

### 執行測試

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```

### 發佈

```bash
# Windows
dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r win-x64 --self-contained -o publish/win-x64/

# macOS (Apple Silicon)
dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r osx-arm64 --self-contained -o publish/osx-arm64/

# macOS (Intel)
dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r osx-x64 --self-contained -o publish/osx-x64/
```

## 技術棧

- .NET 9
- Avalonia 11.3 (跨平台 UI)
- CommunityToolkit.Mvvm (MVVM)
- xUnit + NSubstitute (測試)

## 專案結構

```
src/MoldplanDbSwitcher/
├── Models/          # 資料模型
├── Services/        # 業務邏輯（連線讀取、SERVER.txt 操作）
├── ViewModels/      # MVVM ViewModel
└── Views/           # Avalonia UI

tests/MoldplanDbSwitcher.Tests/
├── Models/          # 模型測試
├── Services/        # 服務測試
└── ViewModels/      # ViewModel 測試
```
