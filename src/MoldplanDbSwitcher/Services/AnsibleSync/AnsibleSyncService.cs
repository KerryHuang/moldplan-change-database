using System.Globalization;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public class AnsibleSyncService : IAnsibleSyncService
{
    private readonly IAppSettingsService _appSettingsService;

    private static readonly IDeserializer YamlDeserializer =
        new DeserializerBuilder()
            .WithNamingConvention(NullNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build();

    public AnsibleSyncService(IAppSettingsService appSettingsService)
    {
        _appSettingsService = appSettingsService;
    }

    public async Task<List<ConnectionProfile>> SyncAsync()
    {
        var settings = _appSettingsService.Load();
        if (string.IsNullOrWhiteSpace(settings.AnsibleRepoPath))
            return [];

        var inventoryDir = Path.Combine(
            settings.AnsibleRepoPath, "ansible", "customer", "inventory");

        if (!Directory.Exists(inventoryDir))
            return [];

        var hostsFile = Path.Combine(inventoryDir, "hosts.yml");
        if (!File.Exists(hostsFile))
            return [];

        var groupVarsDir = Path.Combine(inventoryDir, "group_vars");
        var customers = ParseCustomers(hostsFile);
        var profiles = new List<ConnectionProfile>();

        foreach (var customer in customers)
        {
            foreach (var env in customer.Environments)
            {
                var profile = await BuildProfileAsync(
                    customer, env, groupVarsDir, settings.VaultPasswordFile);
                if (profile != null)
                    profiles.Add(profile);
            }
        }

        return profiles;
    }

    private List<CustomerInfo> ParseCustomers(string hostsFile)
    {
        var content = File.ReadAllText(hostsFile);
        var root = YamlDeserializer.Deserialize<Dictionary<string, object>>(content);

        var customers = new List<CustomerInfo>();

        if (root.TryGetValue("all", out var allObj) &&
            allObj is Dictionary<object, object> all &&
            all.TryGetValue("children", out var childrenObj) &&
            childrenObj is Dictionary<object, object> children)
        {
            foreach (var (groupKey, groupVal) in children)
            {
                var groupName = groupKey.ToString()!;
                if (!groupName.StartsWith("customer_"))
                    continue;

                // 只取 customer_<name>（不含 _production/_staging）
                var suffix = groupName["customer_".Length..];
                if (suffix.Contains('_'))
                    continue; // 跳過 customer_name_env 格式

                if (groupVal is not Dictionary<object, object> groupDict) continue;

                var vars = groupDict.TryGetValue("vars", out var v)
                    ? v as Dictionary<object, object>
                    : null;

                var mssqlHost = vars?.GetValueOrDefault("mssql_host")?.ToString() ?? string.Empty;
                var tailscaleIp = vars?.GetValueOrDefault("tailscale_ip")?.ToString() ?? string.Empty;
                var customerName = vars?.GetValueOrDefault("customer")?.ToString() ?? suffix;

                var environments = new List<string>();
                if (groupDict.TryGetValue("hosts", out var hostsObj) &&
                    hostsObj is Dictionary<object, object> hosts)
                {
                    foreach (var (hostKey, hostVal) in hosts)
                    {
                        if (hostVal is Dictionary<object, object> hostDict &&
                            hostDict.TryGetValue("env", out var envObj))
                        {
                            environments.Add(envObj.ToString()!);
                        }
                    }
                }

                if (environments.Count == 0) continue;

                customers.Add(new CustomerInfo
                {
                    GroupName = groupName,
                    CustomerName = customerName,
                    MssqlHost = mssqlHost,
                    TailscaleIp = tailscaleIp,
                    Environments = environments.Distinct().ToList()
                });
            }
        }

        return customers;
    }

    private async Task<ConnectionProfile?> BuildProfileAsync(
        CustomerInfo customer, string env, string groupVarsDir, string vaultPasswordFile)
    {
        var envGroup = $"customer_{customer.CustomerName}_{env}";
        var dbYmlPath = Path.Combine(groupVarsDir, envGroup, "database.yml");
        string? database = null;

        if (File.Exists(dbYmlPath))
        {
            try
            {
                var dbYml = YamlDeserializer.Deserialize<Dictionary<string, object>>(
                    await File.ReadAllTextAsync(dbYmlPath));
                database = ExtractMainDatabase(dbYml);
            }
            catch { /* 解析失敗跳過 */ }
        }

        if (string.IsNullOrEmpty(database))
            return null;

        var vaultVars = await MergeVaultVarsAsync(
            customer.CustomerName, env, groupVarsDir, vaultPasswordFile);

        var isContainer = customer.MssqlHost.Equals("container", StringComparison.OrdinalIgnoreCase);
        var server = isContainer ? customer.TailscaleIp : customer.MssqlHost;

        if (string.IsNullOrEmpty(server))
            return null;

        var username = isContainer ? "SA" : "mis";
        var password = isContainer
            ? GetVaultVar(vaultVars, "vault_db_container_password", "service")
            : GetVaultVar(vaultVars,
                "vault_db_main_password",
                "vault_db_admin_password",
                "vault_db_password",
                "service");

        var envLabel = env == "production" ? "正式" : "測試";
        var displayName = CultureInfo.CurrentCulture.TextInfo.ToTitleCase(customer.CustomerName);

        return new ConnectionProfile
        {
            Name = $"{displayName} - {envLabel}",
            Server = server,
            Database = database,
            AuthType = AuthenticationType.SqlServerAuthentication,
            Username = username,
            Password = password,
            Source = "Ansible"
        };
    }

    private static string? ExtractMainDatabase(Dictionary<string, object> dbYml)
    {
        if (dbYml.TryGetValue("main_sql_override", out var overrideObj) &&
            overrideObj is Dictionary<object, object> overrideDict &&
            overrideDict.TryGetValue("database", out var db))
        {
            return db?.ToString();
        }
        return null;
    }

    private async Task<Dictionary<string, string>> MergeVaultVarsAsync(
        string customerName, string env, string groupVarsDir, string vaultPasswordFile)
    {
        string? password = null;
        if (File.Exists(vaultPasswordFile))
            password = (await File.ReadAllTextAsync(vaultPasswordFile)).Trim();

        var merged = new Dictionary<string, string>();

        foreach (var group in new[]
        {
            $"customer_{customerName}",
            $"customer_{customerName}_{env}"
        })
        {
            var vaultFile = Path.Combine(groupVarsDir, group, "vault.yml");
            if (!File.Exists(vaultFile)) continue;

            try
            {
                var rawContent = await File.ReadAllTextAsync(vaultFile);
                string yamlContent;

                if (rawContent.TrimStart().StartsWith("$ANSIBLE_VAULT"))
                {
                    if (password == null) continue;
                    yamlContent = VaultDecryptor.Decrypt(rawContent, password);
                }
                else
                {
                    yamlContent = rawContent;
                }

                var vars = YamlDeserializer.Deserialize<Dictionary<string, object>>(yamlContent);
                foreach (var (k, v) in vars)
                    merged[k] = v?.ToString() ?? string.Empty;
            }
            catch
            {
                // 單一 vault 解密失敗不中斷整體流程
            }
        }

        return merged;
    }

    private static string GetVaultVar(Dictionary<string, string> vars, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (vars.TryGetValue(key, out var val) && !string.IsNullOrEmpty(val))
                return val;
        }
        return keys[^1]; // 最後一個參數視為預設值
    }

    private class CustomerInfo
    {
        public string GroupName { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public string MssqlHost { get; set; } = string.Empty;
        public string TailscaleIp { get; set; } = string.Empty;
        public List<string> Environments { get; set; } = [];
    }
}
