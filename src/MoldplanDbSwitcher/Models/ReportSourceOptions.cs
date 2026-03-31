namespace MoldplanDbSwitcher.Models;

public record ReportSourceOptions(
    bool Specurai,
    bool Custom,
    bool AnsibleProduction,
    bool AnsibleStaging)
{
    public static ReportSourceOptions AllSelected =>
        new(Specurai: true, Custom: true, AnsibleProduction: true, AnsibleStaging: true);
}
