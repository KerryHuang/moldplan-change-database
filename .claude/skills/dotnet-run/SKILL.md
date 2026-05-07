---
name: dotnet-run
description: Use when building, running, testing, or publishing the MoldplanDbSwitcher dotnet project. Reference for all dotnet CLI commands in this repo.
---

# dotnet-run

## Overview

MoldplanDbSwitcher — .NET 9 + Avalonia 11.3 跨平台桌面應用程式的常用指令參考。

## 常用指令

### 建置

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

### 執行

```bash
dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

### 測試

```bash
# 全部測試
dotnet test tests/MoldplanDbSwitcher.Tests/

# 單一測試類別
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtServiceTests"

# 單一測試方法
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ServerTxtServiceTests.Apply_WritesModifiedContent"
```

### 發佈

```bash
# Windows x64
dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r win-x64 --self-contained -o publish/win-x64/

# macOS Apple Silicon
dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r osx-arm64 --self-contained -o publish/osx-arm64/
```

## 測試命名慣例

`方法名_情境_預期結果`，例如：`Apply_NonExistentFile_ReturnsFalse`

## 注意事項

- 測試使用 xUnit + NSubstitute
- Service 測試注入臨時目錄，在 `Dispose()` 清理
- 發佈需同時產出 win-x64 與 osx-arm64
