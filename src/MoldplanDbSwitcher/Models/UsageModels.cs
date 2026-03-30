namespace MoldplanDbSwitcher.Models;

public class UsageEntry
{
    public string ProgNo { get; set; } = string.Empty;
    public string ProgName { get; set; } = string.Empty;
    public decimal UsageMinutes { get; set; }
    public int Count { get; set; }
}

public class UsageReportData
{
    public List<(string CustomerName, UsageEntry Entry)> Rows { get; set; } = [];
    public List<string> FailedConnections { get; set; } = [];
    public List<string> SkippedConnections { get; set; } = [];
}
