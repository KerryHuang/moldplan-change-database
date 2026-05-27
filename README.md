# 資料庫連線切換工具 (MoldplanDbSwitcher)

跨平台桌面應用程式，用於切換 WDMIS 系統的資料庫連線設定。選擇資料庫連線後，自動替換 `SERVER.txt` 中的伺服器位址與資料庫名稱，以及 .NET 專案的 `appsettings.Development.json` 中的 MSSQL 連線設定。

## 功能

主視窗採三分頁設計，頂端有全域「目前連線」下拉選單，所有分頁共用同一個連線。

### 連線切換

- 讀取 [TableSpec (DatabaseDescriptionApp)](https://github.com/KerryHuang/DatabaseDescriptionApp) 的連線設定
- 支援新增、編輯、刪除自訂連線
- 自動搜尋 WDMIS 目錄下的 `SERVER.txt`
- 顯示變更前後對比，確認後套用
- 支援同時修改多個 `SERVER.txt`
- **套用開發設定**：掃描指定目錄下所有含 MSSQL 區塊的 `appsettings.Development.json`，勾選後批次更新

### Reporting 查詢

針對 MoldPlan 的 `Reporting` schema 寬表 / View 提供 DBA 友善的查詢工具：

- 左側分組列出 `Reporting` schema 下的 Base Tables / Summary Tables / Views / System Tables，附中文描述
- 選取物件後自動載入 Top N 預覽（預設 100，硬上限 10000）、欄位 schema、最近 RefreshLog
- DataGrid 欄位 header 顯示欄名 + 中文描述（hover 也有 tooltip）
- **Filter Builder**：「+ 條件」可加多列篩選，每列可選欄位 / 運算子（=、≠、包含、開頭為、>, <, ≥, ≤, IS NULL, IS NOT NULL）/ 值，列間以 AND / OR 串接，連續 OR 自動加圓括號分組
- **Sort Builder**：「+ 排序」可加多欄位排序（升冪 / 降冪）
- 狀態列顯示實際執行的 SQL 與連到的 DB 名稱（診斷用）
- 切換頂端連線時自動清空選取與結果，重新載入新連線的物件清單

### Reporting 部署

部署 / 重建 / 移除目標資料庫的 `Reporting` schema 一鍵化（取代手動執行 `docs/scripts/Reporting/*.sql`）：

- 環境掃描：顯示 Schema 是否存在、Tables / Views / SP 數量
- **部署全部 (01→04)**：依序執行 Schema → Tables → Views → SP；完整部署後按鈕自動停用並顯示「✓ 已完整部署」
- **部署 Daily Job (05) / Hourly Job (06)**：自動替換 `<<CHANGE_ME>>` 為目標 DB 名稱
- **⚠ 移除全部 (98)**：二次防呆，需手動輸入目標 DB 名稱才能執行
- 腳本路徑可在「設定」指定，或透過 `MOLDPLAN_REPO` 環境變數提供（預設 `D:\Repos\MoldPlan-Workspace\docs\scripts\Reporting`）

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
| Ansible | `deploy-ansible` repo（需在「設定」指定路徑） | 從 Ansible vault 解密讀取，需 `~/.ansible-vault-pass` |

## 應用程式設定

`%AppData%/MoldplanDbSwitcher/app-settings.json`，可在「設定」對話框維護：

| 設定 | 用途 |
|------|------|
| `AnsibleRepoPath` | deploy-ansible Repo 路徑（同步 Ansible 連線用） |
| `VaultPasswordFile` | Ansible Vault 密碼檔（預設 `~/.ansible-vault-pass`） |
| `DevDirectory` | 「套用開發設定」掃描根目錄 |
| `MoldPlanScriptsPath` | Reporting 部署腳本路徑（留白則讀 `MOLDPLAN_REPO` 環境變數） |

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
- Microsoft.Data.SqlClient (Reporting 查詢 / 部署)
- xUnit + NSubstitute (測試；整合測試以 LocalDB 為測試 DB)

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
