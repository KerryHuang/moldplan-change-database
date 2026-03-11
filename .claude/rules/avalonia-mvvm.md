---
globs: ["src/MoldplanDbSwitcher/Views/**", "src/MoldplanDbSwitcher/ViewModels/**"]
---

# Avalonia MVVM 慣例

- ViewModel 使用 CommunityToolkit.Mvvm：`[ObservableProperty]` 產生屬性，`[RelayCommand]` 產生命令
- ViewModel 為 `partial class`，繼承 `ObservableObject`
- View 的 DataContext 透過 DI 注入，不在 AXAML 中硬編碼
- AXAML 啟用 compiled bindings：`x:DataType="vm:XxxViewModel"`
- 對話框透過 code-behind 的事件處理開啟，結果回傳 ViewModel
- Avalonia 資源（icon 等）必須在 .csproj 加 `<AvaloniaResource>` 才會嵌入發佈包
