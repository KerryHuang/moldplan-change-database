using System.Text.Json.Serialization;

namespace MoldplanDbSwitcher.Models;

public enum AuthenticationType
{
    WindowsAuthentication = 0,
    SqlServerAuthentication = 1
}

public class ConnectionProfile
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("server")]
    public string Server { get; set; } = string.Empty;

    [JsonPropertyName("database")]
    public string Database { get; set; } = string.Empty;

    [JsonPropertyName("authType")]
    public AuthenticationType AuthType { get; set; } = AuthenticationType.WindowsAuthentication;

    [JsonPropertyName("username")]
    public string Username { get; set; } = string.Empty;

    [JsonPropertyName("password")]
    public string Password { get; set; } = string.Empty;

    [JsonPropertyName("isDefault")]
    public bool IsDefault { get; set; }

    [JsonIgnore]
    public string Source { get; set; } = "Custom";
}

public class ConnectionsFile
{
    [JsonPropertyName("profiles")]
    public List<ConnectionProfile> Profiles { get; set; } = [];

    [JsonPropertyName("currentProfileId")]
    public string? CurrentProfileId { get; set; }
}
