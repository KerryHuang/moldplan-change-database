namespace MoldplanDbSwitcher.Models;

/// <summary>連線顯示排序：預設優先 → 環境（列舉順序）→ 名稱（不分大小寫）。</summary>
public sealed class ConnectionProfileComparer : IComparer<ConnectionProfile>
{
    public static readonly ConnectionProfileComparer Instance = new();

    public int Compare(ConnectionProfile? x, ConnectionProfile? y)
    {
        if (ReferenceEquals(x, y)) return 0;
        if (x is null) return 1;
        if (y is null) return -1;

        var byDefault = y.IsDefault.CompareTo(x.IsDefault);
        if (byDefault != 0) return byDefault;

        var byEnv = x.Environment.CompareTo(y.Environment);
        if (byEnv != 0) return byEnv;

        return string.Compare(x.Name, y.Name, StringComparison.OrdinalIgnoreCase);
    }
}
