using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using System.IO;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingDeployServiceTests : IClassFixture<LocalDbFixture>, IDisposable
{
    private readonly LocalDbFixture _db;
    private readonly string _scriptsDir;

    public ReportingDeployServiceTests(LocalDbFixture db)
    {
        _db = db;
        _scriptsDir = Path.Combine(Path.GetTempPath(), "rds_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_scriptsDir);
        // 建立簡易 schema 腳本供整合測試使用（LocalDB 無 SQL Agent，只測 schema）
        File.WriteAllText(Path.Combine(_scriptsDir, "02_Reporting_Create_Schema.sql"),
            "IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');\nGO");
    }

    public void Dispose() { if (Directory.Exists(_scriptsDir)) Directory.Delete(_scriptsDir, true); }

    [Fact]
    public async Task DeployAllAsync_WrongConfirmName_Throws()
    {
        var provider = new ReportingScriptProvider(_scriptsDir);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, new SqlBatchExecutor());
        var parameters = new ReportingDeployParameters(_db.DatabaseName, "source-db");

        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.DropAllAsync(parameters, confirmDatabaseName: "wrong-name"));
    }

    [Fact]
    public async Task ScanInstallStatusAsync_NonExistentDatabase_ReturnsFalse()
    {
        // 使用不存在的資料庫名稱連線字串
        var noDbCs = $"Server=(localdb)\\MSSQLLocalDB;Database=NonExistentDb_{Guid.NewGuid():N};Integrated Security=true;TrustServerCertificate=true;";
        var provider = new ReportingScriptProvider(_scriptsDir);
        var sut = new ReportingDeployService(noDbCs, provider, new SqlBatchExecutor());

        var status = await sut.ScanInstallStatusAsync();

        Assert.False(status.DatabaseExists);
        Assert.False(status.SchemaExists);
        Assert.Equal(0, status.TableCount);
    }

    [Fact]
    public async Task ScanInstallStatusAsync_DatabaseExistsNoSchema_ReturnsDbExistsOnly()
    {
        // LocalDbFixture 已建立測試資料庫，但尚未建 Reporting schema
        var provider = new ReportingScriptProvider(_scriptsDir);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, new SqlBatchExecutor());

        var status = await sut.ScanInstallStatusAsync();

        Assert.True(status.DatabaseExists);
        Assert.False(status.SchemaExists);
        Assert.Equal(0, status.TableCount);
        Assert.False(status.IsFullyDeployed);
    }
}
