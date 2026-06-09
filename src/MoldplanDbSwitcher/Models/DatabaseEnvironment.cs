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
