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
        File.WriteAllText(Path.Combine(_scriptsDir, "01_Reporting_Create_Schema.sql"),
            "IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');\nGO");
    }

    public void Dispose() { if (Directory.Exists(_scriptsDir)) Directory.Delete(_scriptsDir, true); }

    [Fact]
    public async Task DeploySchema_CreatesReportingSchema()
    {
        var provider = new ReportingScriptProvider(_scriptsDir);
        var executor = new SqlBatchExecutor();
        var objectSvc = new ReportingObjectService(_db.ConnectionString);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, executor);

        var step = await sut.DeploySchemaAsync();

        Assert.Equal(DeployStatus.Success, step.Status);
        Assert.True(await objectSvc.SchemaExistsAsync());
    }

    [Fact]
    public async Task DropAllAsync_WrongConfirmName_Throws()
    {
        var provider = new ReportingScriptProvider(_scriptsDir);
        var sut = new ReportingDeployService(_db.ConnectionString, provider, new SqlBatchExecutor());
        await Assert.ThrowsAsync<InvalidOperationException>(
            () => sut.DropAllAsync(confirmDatabaseName: "wrong-name"));
    }
}
