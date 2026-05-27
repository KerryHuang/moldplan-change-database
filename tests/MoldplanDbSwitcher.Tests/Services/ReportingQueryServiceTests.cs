using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

[Trait("Category", "Integration")]
public class ReportingQueryServiceTests : IClassFixture<LocalDbFixture>
{
    private readonly LocalDbFixture _db;
    public ReportingQueryServiceTests(LocalDbFixture db) { _db = db; }

    private async Task SeedAsync(string sql)
    {
        await using var conn = _db.CreateConnection();
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        await cmd.ExecuteNonQueryAsync();
    }

    [Fact]
    public async Task QueryTopN_ReturnsRows()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT1') IS NOT NULL DROP TABLE Reporting.QT1;
            CREATE TABLE Reporting.QT1 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT1 VALUES (1,'a'),(2,'b'),(3,'c');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);

        var result = await sut.QueryTopNAsync("QT1", top: 10, where: null, orderBy: "Id");

        Assert.Equal(2, result.Columns.Count);
        Assert.Equal(3, result.Rows.Count);
    }

    [Fact]
    public async Task QueryTopN_InvalidObjectName_Throws()
    {
        var sut = new ReportingQueryService(_db.ConnectionString);
        await Assert.ThrowsAsync<ArgumentException>(
            () => sut.QueryTopNAsync("QT1; DROP TABLE QT1--", 10, (string?)null, null));
    }

    [Fact]
    public async Task QueryTopN_TopExceedsCap_Throws()
    {
        var sut = new ReportingQueryService(_db.ConnectionString);
        Assert.Equal(10000, ReportingQueryService.MaxTopN);
        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(
            () => sut.QueryTopNAsync("QT1", top: 99999, (string?)null, null));
    }

    [Fact]
    public async Task QueryTopN_WithFilters_EqualsFilter_ReturnsMatchedRows()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT2') IS NOT NULL DROP TABLE Reporting.QT2;
            CREATE TABLE Reporting.QT2 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT2 VALUES (1,'alpha'),(2,'beta'),(3,'alpha');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);
        var filters = new[]
        {
            new QueryFilterRow { ColumnName = "Name", Operator = FilterOperator.Equals, Value = "alpha" }
        };

        var result = await sut.QueryTopNAsync("QT2", top: 100, filters: filters, orderBy: "Id");

        Assert.Equal(2, result.Columns.Count);
        Assert.Equal(2, result.Rows.Count);
        Assert.All(result.Rows, r => Assert.Equal("alpha", r[1]));
    }

    [Fact]
    public async Task QueryTopN_WithFilters_ContainsFilter_ReturnsMatchedRows()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT3') IS NOT NULL DROP TABLE Reporting.QT3;
            CREATE TABLE Reporting.QT3 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT3 VALUES (1,'apple'),(2,'pineapple'),(3,'banana');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);
        var filters = new[]
        {
            new QueryFilterRow { ColumnName = "Name", Operator = FilterOperator.Contains, Value = "apple" }
        };

        var result = await sut.QueryTopNAsync("QT3", top: 100, filters: filters, orderBy: "Id");

        Assert.Equal(2, result.Rows.Count);
    }

    [Fact]
    public async Task QueryTopN_WithFilters_IsNullFilter_ReturnsNullRows()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT4') IS NOT NULL DROP TABLE Reporting.QT4;
            CREATE TABLE Reporting.QT4 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT4 VALUES (1, NULL),(2,'b');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);
        var filters = new[]
        {
            new QueryFilterRow { ColumnName = "Name", Operator = FilterOperator.IsNull }
        };

        var result = await sut.QueryTopNAsync("QT4", top: 100, filters: filters, orderBy: null);

        Assert.Single(result.Rows);
        Assert.Null(result.Rows[0][1]);
    }
}
