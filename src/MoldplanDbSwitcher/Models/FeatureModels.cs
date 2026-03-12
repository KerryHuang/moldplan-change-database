namespace MoldplanDbSwitcher.Models;

public class FeatureEntry
{
    public string SysType { get; set; } = string.Empty;
    public string ItemId { get; set; } = string.Empty;
    public string ItemDesc { get; set; } = string.Empty;
    public string AppFile { get; set; } = string.Empty;
    public string OpenYn { get; set; } = string.Empty;
}

public class CustomerFeatureData
{
    public string Code { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public string Database { get; set; } = string.Empty;
    public List<FeatureEntry> Features { get; set; } = [];

    public static CustomerFeatureData FromConnectionName(string connectionName, string database)
    {
        var code = connectionName
            .Replace("-Staging", "")
            .Replace("-Test", "");

        return new CustomerFeatureData
        {
            Code = code,
            CustomerName = code,
            Database = database
        };
    }
}

public class FeatureReportData
{
    public List<CustomerFeatureData> Customers { get; set; } = [];
    public List<string> FailedConnections { get; set; } = [];
    public List<string> SkippedConnections { get; set; } = [];
}
