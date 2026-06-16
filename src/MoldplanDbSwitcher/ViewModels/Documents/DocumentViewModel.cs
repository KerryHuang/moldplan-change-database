using System;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.ViewModels.Documents;

/// <summary>MDI 文件基底：每個功能頁為一個子類。</summary>
public abstract partial class DocumentViewModel : ObservableObject
{
    /// <summary>型別識別字串，用於 DataTemplate 路由與預設 singleton 鍵。</summary>
    public abstract string DocumentType { get; }

    /// <summary>singleton 鍵；同鍵同時間只開一份。預設＝DocumentType。</summary>
    public virtual string DocumentKey => DocumentType;

    [ObservableProperty]
    private string _title = string.Empty;

    /// <summary>tab 圖示（emoji 或符號）。</summary>
    public virtual string Icon => string.Empty;

    /// <summary>是否可關閉；主頁文件設 false。</summary>
    public virtual bool CanClose => true;

    /// <summary>要求關閉本文件時觸發，由 shell 訂閱移除。</summary>
    public event Action<DocumentViewModel>? CloseRequested;

    [RelayCommand]
    private void Close() => CloseRequested?.Invoke(this);

    /// <summary>連線變更時各文件覆寫重指向；預設不做事。</summary>
    public virtual Task UseConnectionAsync(ActiveConnection connection) => Task.CompletedTask;
}
