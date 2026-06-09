namespace MoldplanDbSwitcher.Models;

/// <summary>依連線名稱推斷環境（供無明確環境欄位的 Ansible 來源使用）。</summary>
public static class DatabaseEnvironmentInference
{
    public static DatabaseEnvironment FromName(string? name)
    {
        if (string.IsNullOrEmpty(name)) return DatabaseEnvironment.Staging;
        if (name.Contains("正式")) return DatabaseEnvironment.Production;
        if (name.Contains("測試")) return DatabaseEnvironment.Testing;
        return DatabaseEnvironment.Staging;
    }
}
