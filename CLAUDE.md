# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Immutable Laws

<law>
**Law 1: 繁體中文** - 所有 UI 文字、commit 訊息、文件、回覆皆使用繁體中文。程式碼識別符維持英文
**Law 2: TDD** - 先寫失敗測試，確認失敗，再寫最小實作，確認通過。無測試不寫產品代碼
**Law 3: Interface-first Services** - 每個 Service 必須有 interface，建構式接受可注入路徑參數以便測試
</law>

## Project Overview

MoldplanDbSwitcher — 跨平台 Avalonia 桌面應用程式，用於切換 WDMIS 系統的資料庫連線。選擇連線後替換 `SERVER.txt` 中的伺服器位址與資料庫名稱。

`apps/DatabaseDescriptionApp` 是 git submodule（唯讀參考），本專案讀取其 `%AppData%/Specurai/connections.json` 設定檔。

## Build & Test Commands

See `/dotnet-run` skill for all build, test, and publish commands.

## Architecture

單一專案 MVVM 架構（非 Clean Architecture），使用 .NET 9 + Avalonia 11.3。

```
src/MoldplanDbSwitcher/
├── Models/        → 資料模型（ConnectionProfile, ServerTxtEntry）
├── Services/      → 業務邏輯，皆有 interface 以便測試
├── ViewModels/    → CommunityToolkit.Mvvm（ObservableProperty, RelayCommand）
└── Views/         → Avalonia AXAML + code-behind
```

**Services 的可測試性設計：** `SettingsService`、`ServerTxtService`、`ConnectionSourceService` 都有接受路徑參數的建構式，測試時注入臨時目錄避免碰到真實檔案系統。

**連線來源：**
- Specurai: `%AppData%/Specurai/connections.json`（PascalCase JSON，需 `PropertyNameCaseInsensitive = true`）
- 自訂: `%AppData%/MoldplanDbSwitcher/connections.json`

Specurai 端標記為停用（`"IsEnabled": false`）的連線不會列入可切換清單；舊設定檔沒有這個欄位，視為啟用。停用只能在 Specurai 的連線設定畫面操作。

**SERVER.txt 搜尋路徑（跨平台）：**
- Windows: `C:\WDMIS\SERVER.txt`, `D:\WDMIS\SERVER.txt`
- macOS/Linux: `~/WDMIS/SERVER.txt`

## Key Conventions

- DI：透過 `Microsoft.Extensions.DependencyInjection`，在 `Program.cs` 註冊
