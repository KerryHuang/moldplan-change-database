using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;
using NSubstitute;

namespace MoldplanDbSwitcher.Tests.Services.AnsibleSync;

public class AnsibleSyncServiceTests : IDisposable
{
    private readonly string _repoRoot;
    private readonly string _groupVarsDir;
    private readonly string _vaultPassFile;

    public AnsibleSyncServiceTests()
    {
        _repoRoot = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        _groupVarsDir = Path.Combine(_repoRoot, "ansible", "customer", "inventory", "group_vars");
        Directory.CreateDirectory(_groupVarsDir);

        _vaultPassFile = Path.Combine(_repoRoot, ".vault-pass");
        File.WriteAllText(_vaultPassFile, "testpass");
    }

    public void Dispose() => Directory.Delete(_repoRoot, true);

    private void WriteFile(string relativeToGroupVars, string content)
    {
        var fullPath = Path.Combine(_groupVarsDir, relativeToGroupVars);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
    }

    private void WriteHostsYml(string yaml)
    {
        var hostsPath = Path.Combine(_repoRoot, "ansible", "customer", "inventory", "hosts.yml");
        Directory.CreateDirectory(Path.GetDirectoryName(hostsPath)!);
        File.WriteAllText(hostsPath, yaml);
    }

    private AnsibleSyncService CreateSut(string repoPath)
    {
        var settings = new AppSettings
        {
            AnsibleRepoPath = repoPath,
            VaultPasswordFile = _vaultPassFile
        };
        var appSettingsService = Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);
        return new AnsibleSyncService(appSettingsService);
    }

    [Fact]
    public async Task SyncAsync_ExternalMssql_ReturnsCorrectProfile()
    {
        WriteHostsYml("""
            all:
              children:
                customer_testco:
                  hosts:
                    testco-production:
                      env: production
                  vars:
                    mssql_host: 192.168.1.100
                    tailscale_ip: 100.1.2.3
                    customer: testco
            """);

        WriteFile("customer_testco_production/database.yml", """
            main_sql_override:
              database: "testcoDB"
            """);

        WriteFile("customer_testco/vault.yml", """
            vault_db_main_password: prodpass123
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = await sut.SyncAsync();

        var prod = profiles.FirstOrDefault(p => p.Name.Contains("正式"));
        Assert.NotNull(prod);
        Assert.Equal("192.168.1.100", prod.Server);
        Assert.Equal("testcoDB", prod.Database);
        Assert.Equal("mis", prod.Username);
        Assert.Equal("prodpass123", prod.Password);
        Assert.Equal("Ansible", prod.Source);
        Assert.Equal(AuthenticationType.SqlServerAuthentication, prod.AuthType);
    }

    [Fact]
    public async Task SyncAsync_ContainerMssql_UsesTailscaleIp()
    {
        WriteHostsYml("""
            all:
              children:
                customer_waydo:
                  hosts:
                    waydo-staging:
                      env: staging
                  vars:
                    mssql_host: container
                    tailscale_ip: 100.73.36.124
                    customer: waydo
            """);

        WriteFile("customer_waydo_staging/database.yml", """
            main_sql_override:
              database: "waydo-test"
            """);

        WriteFile("customer_waydo/vault.yml", """
            vault_db_container_password: containerPass
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = await sut.SyncAsync();

        var staging = profiles.FirstOrDefault(p => p.Name.Contains("測試"));
        Assert.NotNull(staging);
        Assert.Equal("100.73.36.124", staging.Server);
        Assert.Equal("waydo-test", staging.Database);
        Assert.Equal("SA", staging.Username);
        Assert.Equal("containerPass", staging.Password);
    }

    [Fact]
    public async Task SyncAsync_EmptyRepoPath_ReturnsEmpty()
    {
        var settings = new AppSettings { AnsibleRepoPath = string.Empty };
        var appSettingsService = Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);
        var sut = new AnsibleSyncService(appSettingsService);

        var profiles = await sut.SyncAsync();

        Assert.Empty(profiles);
    }

    [Fact]
    public async Task SyncAsync_NoHostsFile_ReturnsEmpty()
    {
        // repoRoot exists but has no hosts.yml
        var sut = CreateSut(_repoRoot);
        var profiles = await sut.SyncAsync();

        Assert.Empty(profiles);
    }

    [Fact]
    public async Task SyncAsync_NoDatabaseYml_SkipsCustomer()
    {
        WriteHostsYml("""
            all:
              children:
                customer_nodbco:
                  hosts:
                    nodbco-production:
                      env: production
                  vars:
                    mssql_host: 192.168.1.200
                    tailscale_ip: 100.1.2.4
                    customer: nodbco
            """);
        // No database.yml for customer_nodbco_production

        var sut = CreateSut(_repoRoot);
        var profiles = await sut.SyncAsync();

        Assert.Empty(profiles);
    }

    [Fact]
    public async Task SyncAsync_VaultEnvOverridesCustomer_UsesEnvPassword()
    {
        WriteHostsYml("""
            all:
              children:
                customer_overco:
                  hosts:
                    overco-staging:
                      env: staging
                  vars:
                    mssql_host: 192.168.1.50
                    tailscale_ip: 100.5.5.5
                    customer: overco
            """);

        WriteFile("customer_overco_staging/database.yml", """
            main_sql_override:
              database: "overco-staging"
            """);

        WriteFile("customer_overco/vault.yml", """
            vault_db_main_password: base_password
            """);

        WriteFile("customer_overco_staging/vault.yml", """
            vault_db_main_password: env_password
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = await sut.SyncAsync();

        var staging = profiles.FirstOrDefault();
        Assert.NotNull(staging);
        Assert.Equal("env_password", staging.Password);
    }
}
