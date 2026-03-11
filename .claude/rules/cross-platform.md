---
globs: ["src/MoldplanDbSwitcher/Services/ServerTxtService.cs"]
---

# 跨平台路徑慣例

- 檔案路徑使用 `Path.Combine()`，不硬編碼分隔符
- 平台判斷使用 `OperatingSystem.IsWindows()` / `OperatingSystem.IsMacOS()`
- 預設路徑透過 `GetDefaultPaths()` 靜態方法提供，建構式接受覆寫
- 發佈指令需同時產出 `win-x64` 和 `osx-arm64` 版本
