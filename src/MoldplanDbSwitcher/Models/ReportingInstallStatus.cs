namespace MoldplanDbSwitcher.Models;

public record ReportingInstallStatus(
    bool DatabaseExists, bool SchemaExists,
    int TableCount, int ViewCount, int ProcedureCount)
{
    public bool IsFullyDeployed =>
        DatabaseExists && SchemaExists && TableCount >= 14 && ViewCount >= 13 && ProcedureCount >= 13;
}
