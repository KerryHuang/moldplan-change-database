using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionExportService : IConnectionExportService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords)
    {
        var prepared = PrepareProfiles(profiles, includePasswords);
        var exportData = new ConnectionExportData { Profiles = prepared };
        return JsonSerializer.SerializeToUtf8Bytes(exportData, JsonOptions);
    }

    public byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords)
        => throw new NotImplementedException();

    public ConnectionExportData ImportFromJson(byte[] data)
        => throw new NotImplementedException();

    public ConnectionExportData ImportFromEncryptedJson(byte[] data, string password)
        => throw new NotImplementedException();

    public bool IsEncryptedFormat(byte[] data)
        => throw new NotImplementedException();

    private static List<ConnectionProfile> PrepareProfiles(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords)
    {
        return profiles.Select(p => new ConnectionProfile
        {
            Id = p.Id,
            Name = p.Name,
            Server = p.Server,
            Database = p.Database,
            AuthType = p.AuthType,
            Username = p.Username,
            Password = includePasswords ? p.Password : null!,
            IsDefault = p.IsDefault
        }).ToList();
    }
}
