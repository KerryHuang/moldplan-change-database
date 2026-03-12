namespace MoldplanDbSwitcher.Models;

public class ConnectionExportData
{
    public int Version { get; init; } = 1;
    public DateTime ExportedAt { get; init; } = DateTime.UtcNow;
    public List<ConnectionProfile> Profiles { get; init; } = [];
}
