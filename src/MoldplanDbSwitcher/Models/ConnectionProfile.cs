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

    [JsonPropertyName("environment")]
    public DatabaseEnvironment Environment { get; set; } = DatabaseEnvironment.Staging;

    /// <summary>
    /// 是否啟用。Specurai 端停用的連線不會出現在可切換的連線清單中。
    /// 舊設定檔沒有這個欄位，預設 true 使其維持啟用。
    /// </summary>
    [JsonPropertyName("isEnabled")]
    public bool IsEnabled { get; set; } = true;

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
