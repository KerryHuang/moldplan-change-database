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
        var profiles = (await sut.SyncAsync()).Profiles;

        var prod = profiles.FirstOrDefault(p => p.Name.Contains("正式"));
        Assert.NotNull(prod);
        Assert.Equal("192.168.1.100", prod.Server);
        Assert.Equal("testcoDB", prod.Database);
        Assert.Equal("mis", prod.Username);
        Assert.Equal("prodpass123", prod.Password);
        Assert.Equal("MoldPlan Center", prod.Source);
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
        var profiles = (await sut.SyncAsync()).Profiles;

        var staging = profiles.FirstOrDefault(p => p.Name.Contains("預備"));
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

        var profiles = (await sut.SyncAsync()).Profiles;

        Assert.Empty(profiles);
    }

    [Fact]
    public async Task SyncAsync_NoHostsFile_ReturnsEmpty()
    {
        // repoRoot exists but has no hosts.yml
        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

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
        var result = await sut.SyncAsync();

        Assert.Empty(result.Profiles);
        Assert.Contains("nodbco-production", result.SkippedEntries);
    }

    [Fact]
    public async Task SyncAsync_DatabaseByEnv_ProductionUsesProdKey()
    {
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_gmaco:
                      hosts:
                        gmaco-production:
                          env: production
                        gmaco-staging:
                          env: staging
                      vars:
                        mssql_host: 192.168.1.250
                        customer: gmaco
            """);

        WriteFile("customer_gmaco/database.yml", """
            main_sql_database_by_env:
              prod: "GMACO"
              staging: "gmaco-staging"
            """);

        WriteFile("customer_gmaco_production/database.yml", """
            main_sql_override:
              username: "{{ sql.admin.username }}"
              password: "{{ vault_db_main_password }}"
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var prod = profiles.FirstOrDefault(p => p.Name.Contains("正式"));
        Assert.NotNull(prod);
        Assert.Equal("GMACO", prod.Database);
    }

    [Fact]
    public async Task SyncAsync_DatabaseByEnv_StagingUsesStagingKey()
    {
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_gmaco:
                      hosts:
                        gmaco-staging:
                          env: staging
                      vars:
                        mssql_host: 192.168.1.250
                        customer: gmaco
            """);

        WriteFile("customer_gmaco/database.yml", """
            main_sql_database_by_env:
              prod: "GMACO"
              staging: "gmaco-staging"
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var staging = profiles.FirstOrDefault(p => p.Name.Contains("預備"));
        Assert.NotNull(staging);
        Assert.Equal("gmaco-staging", staging.Database);
    }

    [Fact]
    public async Task SyncAsync_DatabaseByEnvInHostsYml_IsUsed()
    {
        // jiathai 案例：by_env 直接定義在 hosts.yml 的 group vars
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_jiaco:
                      hosts:
                        jiaco-production:
                          env: production
                      vars:
                        mssql_host: 192.168.1.14
                        customer: jiaco
                        main_sql_database_by_env:
                          staging: JIACO-Staging
                          prod: JIACO
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var prod = profiles.FirstOrDefault();
        Assert.NotNull(prod);
        Assert.Equal("JIACO", prod.Database);
    }

    [Fact]
    public async Task SyncAsync_OverrideDatabaseWinsOverByEnv()
    {
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_winco:
                      hosts:
                        winco-production:
                          env: production
                      vars:
                        mssql_host: 192.168.1.90
                        customer: winco
            """);

        WriteFile("customer_winco/database.yml", """
            main_sql_database_by_env:
              prod: "from-by-env"
            """);

        WriteFile("customer_winco_production/database.yml", """
            main_sql_override:
              database: "from-override"
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var prod = profiles.FirstOrDefault();
        Assert.NotNull(prod);
        Assert.Equal("from-override", prod.Database);
    }

    [Fact]
    public async Task SyncAsync_NoDatabaseNameAnywhere_SkipsCustomer()
    {
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_onboarding:
                      hosts:
                        onboarding-production:
                          env: production
                      vars:
                        mssql_host: 192.168.1.10
                        customer: onboarding
            """);

        WriteFile("customer_onboarding_production/database.yml", """
            main_sql_override:
              username: "{{ sql.admin.username }}"
            """);

        var sut = CreateSut(_repoRoot);
        var result = await sut.SyncAsync();

        Assert.Empty(result.Profiles);
        Assert.Contains("onboarding-production", result.SkippedEntries);
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
        var profiles = (await sut.SyncAsync()).Profiles;

        var staging = profiles.FirstOrDefault();
        Assert.NotNull(staging);
        Assert.Equal("env_password", staging.Password);
    }

    [Fact]
    public async Task SyncAsync_StagingEnv_SetsEnvironmentToStagingAndNameSuffixIsPreparatory()
    {
        WriteHostsYml("""
            all:
              children:
                customer_gma:
                  hosts:
                    gma-staging:
                      env: staging
                  vars:
                    mssql_host: 192.168.1.60
                    tailscale_ip: 100.6.6.6
                    customer: gma
            """);

        WriteFile("customer_gma_staging/database.yml", """
            main_sql_override:
              database: "gma-staging-db"
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var staging = profiles.FirstOrDefault();
        Assert.NotNull(staging);
        Assert.Equal(DatabaseEnvironment.Staging, staging.Environment);
        Assert.EndsWith("- 預備", staging.Name);
    }

    [Fact]
    public async Task SyncAsync_PartialByEnvMap_MissingProdKey_OnlyStagingProducedAndProdSkipped()
    {
        // 真實形狀：customer_waydosoft01/02 的 main_sql_database_by_env 只有 staging，沒有 prod
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_waydosoft01:
                      hosts:
                        waydosoft01-production:
                          env: production
                        waydosoft01-staging:
                          env: staging
                      vars:
                        mssql_host: 192.168.1.70
                        customer: waydosoft01
            """);

        WriteFile("customer_waydosoft01/database.yml", """
            main_sql_database_by_env:
              staging: "waydosoft01-staging-db"
            """);

        var sut = CreateSut(_repoRoot);
        var result = await sut.SyncAsync();

        Assert.Single(result.Profiles);
        Assert.Equal("waydosoft01-staging-db", result.Profiles[0].Database);
        Assert.Contains("waydosoft01-production", result.SkippedEntries);
    }

    [Fact]
    public async Task SyncAsync_CustomerLevelByEnv_WinsOverHostsLevelByEnv()
    {
        // customer 層 group_vars 的 database.yml 與 hosts.yml group vars 同時定義
        // main_sql_database_by_env 時，customer 層（tier2）應優先於 hosts.yml（tier3）。
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_tierco:
                      hosts:
                        tierco-production:
                          env: production
                      vars:
                        mssql_host: 192.168.1.80
                        customer: tierco
                        main_sql_database_by_env:
                          prod: "from-hosts-level"
            """);

        WriteFile("customer_tierco/database.yml", """
            main_sql_database_by_env:
              prod: "from-customer-level"
            """);

        var sut = CreateSut(_repoRoot);
        var profiles = (await sut.SyncAsync()).Profiles;

        var prod = profiles.FirstOrDefault();
        Assert.NotNull(prod);
        Assert.Equal("from-customer-level", prod.Database);
    }

    [Fact]
    public async Task SyncAsync_ByEnvIsStringNotMap_SkipsCustomerWithoutThrowing()
    {
        WriteHostsYml("""
            all:
              children:
                customers:
                  children:
                    customer_badtype:
                      hosts:
                        badtype-production:
                          env: production
                      vars:
                        mssql_host: 192.168.1.90
                        customer: badtype
                        main_sql_database_by_env: "not-a-map"
            """);

        var sut = CreateSut(_repoRoot);
        var result = await sut.SyncAsync();

        Assert.Empty(result.Profiles);
        Assert.Contains("badtype-production", result.SkippedEntries);
    }
}
