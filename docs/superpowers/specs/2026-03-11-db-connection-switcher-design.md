# 資料庫連線切換工具 - 設計規格書

## 概述

一個基於 Avalonia 的跨平台桌面應用程式（.NET 9，`net9.0`），用於透過修改 `WDMIS` 目錄下的 `SERVER.txt` 檔案來切換資料庫連線。應用程式會讀取 TableSpec 的 `connections.json`（即 DatabaseDescriptionApp 使用的設定檔）中的資料庫連線設定，同時也支援自訂連線。

**目標平台：** 以 Windows 為主（WDMIS 路徑為 Windows 特有）。使用 Avalonia 是為了未來潛在的跨平台擴展，但 WDMIS 搜尋邏輯僅適用於 Windows。

## 功能需求

### 1. 資料庫連線來源

應用程式支援兩種資料庫連線來源：

**A. TableSpec connections.json**
- 路徑：`%AppData%/TableSpec/connections.json`
- 與 DatabaseDescriptionApp 共用
- 格式：
  ```json
  {
    "profiles": [
      {
        "id": "guid",
        "name": "連線名稱",
        "server": "伺服器位址",
        "database": "資料庫名稱",
        "authType": 0,
        "username": "",
        "password": "",
        "isDefault": false
      }
    ],
    "currentProfileId": "guid"
  }
  ```
- 唯讀 — 本應用程式不會修改 DatabaseDescriptionApp 的設定

**B. 自訂連線**
- 儲存於應用程式自身的設定檔：`%AppData%/MoldplanDbSwitcher/connections.json`
- 簡化格式 — 僅需 `name`、`server`、`database` 欄位（因為本應用程式只修改 SERVER.txt，不實際連線資料庫，所以不需要認證相關欄位）
- 使用者可在應用程式內新增、編輯、刪除自訂連線

### 2. SERVER.txt 搜尋

- 搜尋 `SERVER.txt` 的位置：
  - `C:\WDMIS\SERVER.txt`
  - `D:\WDMIS\SERVER.txt`
- 在非 Windows 平台上，這些路徑不存在 — 應用程式會顯示相應訊息
- 若找到多個，以勾選方塊顯示全部 — 使用者可同時選擇一個或多個進行修改

### 3. SERVER.txt 格式

單行，以逗號分隔：
```
欄位1,資料庫名稱,伺服器位址,欄位4,欄位5
```

範例：
```
mis,yuchiun-test,100.73.36.124,XXX,1
```

**僅替換第 2 欄（資料庫名稱）和第 3 欄（伺服器位址）。** 第 1、4、5 欄保持不變。

### 4. 替換流程

1. 使用者選擇一個連線設定（來自任一來源）
2. 應用程式搜尋 SERVER.txt 檔案
3. 使用者選擇要修改的 SERVER.txt 檔案
4. 應用程式顯示變更前後對比
5. 使用者點擊「套用變更」— 變更前後預覽即為確認機制（無額外確認對話框）
6. 應用程式執行替換並顯示成功或失敗狀態

## UI 設計

### 主視窗佈局

```
┌──────────────────────────────────────────────┐
│  資料庫連線切換工具                            │
├──────────────────────────────────────────────┤
│                                              │
│  連線來源：[TableSpec ▼] [自訂 ▼]             │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ 名稱          伺服器        資料庫   │    │
│  │ ─────────────────────────────────────│    │
│  │ > yuchiun     127.0.0.1     mis     │    │
│  │   yuchiun-test 100.73.36.124 mis    │    │
│  │   production  192.168.1.100  mis    │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  SERVER.txt 位置：                            │
│  ☑ C:\WDMIS\SERVER.txt                      │
│  ☐ D:\WDMIS\SERVER.txt                      │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ 變更前: mis,yuchiun-test,100.73...   │    │
│  │ 變更後: mis,yuchiun,127.0.0.1,...    │    │
│  └──────────────────────────────────────┘    │
│                                              │
│              [套用變更]                       │
│                                              │
├──────────────────────────────────────────────┤
│  [+ 新增自訂連線]                             │
└──────────────────────────────────────────────┘
```

### 頁面

1. **主頁面** — 連線清單、SERVER.txt 選擇、預覽、套用按鈕
2. **新增/編輯連線對話框** — 自訂連線表單（名稱、伺服器、資料庫）

## 架構

### 單一專案，MVVM 模式

```
MoldplanDbSwitcher/
├── Models/
│   ├── ConnectionProfile.cs        # 連線資料模型
│   ├── ServerTxtEntry.cs           # 解析後的 SERVER.txt 資料
│   └── AppSettings.cs              # 應用程式設定
├── Services/
│   ├── ConnectionSourceService.cs  # 讀取 TableSpec + 自訂連線
│   ├── ServerTxtService.cs         # 搜尋、讀取、寫入 SERVER.txt
│   └── SettingsService.cs          # 管理自訂連線設定
├── ViewModels/
│   ├── MainWindowViewModel.cs      # 主視窗邏輯
│   └── ConnectionDialogViewModel.cs # 新增/編輯對話框邏輯
├── Views/
│   ├── MainWindow.axaml            # 主視窗 UI
│   └── ConnectionDialog.axaml      # 新增/編輯對話框 UI
├── App.axaml                       # 應用程式進入點
├── Program.cs                      # 進入點 + DI 設定
└── MoldplanDbSwitcher.csproj
```

### 主要相依套件

| 套件 | 用途 |
|------|------|
| Avalonia 11.x | 跨平台 UI 框架 |
| Semi.Avalonia | 主題（與 DatabaseDescriptionApp 一致） |
| CommunityToolkit.Mvvm | MVVM 支援（ObservableObject、RelayCommand） |
| System.Text.Json | 讀寫 connections.json |
| Microsoft.Extensions.DependencyInjection | 依賴注入容器 |

### 資料流程

```
connections.json (TableSpec) ──┐
                               ├──> ConnectionSourceService ──> MainWindowViewModel
connections.json (自訂) ───────┘                                      │
                                                                      ▼
                                                              使用者選擇連線設定
                                                                      │
                                                                      ▼
                                            ServerTxtService.Discover() ──> List<string> 路徑
                                                                      │
                                                                      ▼
                                                              使用者選擇路徑
                                                                      │
                                                                      ▼
                                            ServerTxtService.Preview() ──> 變更前後對比
                                                                      │
                                                                      ▼
                                            ServerTxtService.Apply()   ──> 寫入修改後的 SERVER.txt
```

## 錯誤處理

- `connections.json` 找不到或格式無效 → 顯示訊息，僅允許使用自訂連線
- 找不到 WDMIS 目錄 → 顯示「找不到 SERVER.txt」訊息
- SERVER.txt 格式不符預期 → 顯示錯誤訊息及檔案內容
- 檔案寫入權限不足 → 顯示錯誤訊息

## 不在範圍內

- 本應用程式不管理 DatabaseDescriptionApp 的連線設定（唯讀）
- 不進行資料庫連線或測試 — 僅修改檔案
- 不備份 SERVER.txt（僅顯示變更前後對比）
