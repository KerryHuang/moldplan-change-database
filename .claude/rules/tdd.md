---
globs: ["tests/**", "src/MoldplanDbSwitcher/Services/**", "src/MoldplanDbSwitcher/Models/**"]
---

# TDD 慣例

- 測試框架：xUnit + NSubstitute
- 測試檔案結構鏡像 src：`tests/MoldplanDbSwitcher.Tests/Services/XxxServiceTests.cs`
- Service 測試使用臨時目錄（`Path.GetTempPath()`），在 `Dispose()` 中清理
- 介面依賴使用 `Substitute.For<IXxx>()` mock
- 執行單一測試：`dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ClassName.MethodName"`
- 測試命名：`方法名_情境_預期結果`，例如 `Apply_NonExistentFile_ReturnsFalse`
