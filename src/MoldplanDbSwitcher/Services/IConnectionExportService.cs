using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionExportService
{
    byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords);
    byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords);
    ConnectionExportData ImportFromJson(byte[] data);
    ConnectionExportData ImportFromEncryptedJson(byte[] data, string password);
    bool IsEncryptedFormat(byte[] data);
}
