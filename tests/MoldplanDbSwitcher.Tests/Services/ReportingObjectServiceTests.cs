using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingObjectServiceTests : IClassFixture<LocalDbFixture>
{
    private readonly LocalDbFixture _db;
    public ReportingObjectServiceTests(LocalDbFixture db) { _db = db; }

    private async Task SeedAsync(string sql)
    {
        await using var conn = _db.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();
    }

    [Fact]
    public async Task SchemaExists_AfterCreate_ReturnsTrue()
    {
        await SeedAsync("IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');");
        var sut = new ReportingObjectService(_db.ConnectionString);

        var exists = await sut.SchemaExistsAsync();

        Assert.True(exists);
    }

    [Fact]
    public async Task ListTablesAsync_ClassifiesKnownTables()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.SalesOrderRowData') IS NULL CREATE TABLE Reporting.SalesOrderRowData (Id INT);
            IF OBJECT_ID('Reporting.MoldCostSummary') IS NULL CREATE TABLE Reporting.MoldCostSummary (Id INT);
            IF OBJECT_ID('Reporting.RefreshLog') IS NULL CREATE TABLE Reporting.RefreshLog (Id INT);
        ");
        var sut = new ReportingObjectService(_db.ConnectionString);

        var tables = await sut.ListTablesAsync();

        Assert.Contains(tables, t => t.Name == "SalesOrderRowData" && t.Kind == ReportingObjectKind.BaseTable);
        Assert.Contains(tables, t => t.Name == "MoldCostSummary" && t.Kind == ReportingObjectKind.SummaryTable);
        Assert.Contains(tables, t => t.Name == "RefreshLog" && t.Kind == ReportingObjectKind.SystemTable);
    }
}
