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
            new QueryFilterRow { SelectedColumn = new ReportingColumn("Name", "nvarchar(50)", true, null), Operator = FilterOperator.Equals, Value = "alpha" }
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
            new QueryFilterRow { SelectedColumn = new ReportingColumn("Name", "nvarchar(50)", true, null), Operator = FilterOperator.Contains, Value = "apple" }
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
            new QueryFilterRow { SelectedColumn = new ReportingColumn("Name", "nvarchar(50)", true, null), Operator = FilterOperator.IsNull }
        };

        var result = await sut.QueryTopNAsync("QT4", top: 100, filters: filters, orderBy: null);

        Assert.Single(result.Rows);
        Assert.Null(result.Rows[0][1]);
    }

    [Fact]
    public async Task QueryTopN_OrConnector_GroupsWithParens()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT5') IS NOT NULL DROP TABLE Reporting.QT5;
            CREATE TABLE Reporting.QT5 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT5 VALUES (1,'alpha'),(2,'beta'),(3,'gamma');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);
        var nameCol = new ReportingColumn("Name", "nvarchar(50)", true, null);
        var filters = new[]
        {
            new QueryFilterRow { SelectedColumn = nameCol, Operator = FilterOperator.Equals, Value = "alpha", Connector = FilterConnector.And },
            new QueryFilterRow { SelectedColumn = nameCol, Operator = FilterOperator.Equals, Value = "beta",  Connector = FilterConnector.Or },
        };
        var sorts = Array.Empty<QuerySortRow>();

        var result = await sut.QueryTopNAsync("QT5", top: 100, filters: filters, sorts: sorts);

        // SQL should use OR group in parens: ([Name] = @p0 OR [Name] = @p1)
        Assert.Contains("OR", result.ExecutedSql);
        Assert.Contains("(", result.ExecutedSql);
        Assert.Equal(2, result.Rows.Count);
    }

    [Fact]
    public async Task QueryTopN_MultipleSorts_BuildsOrderBy()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT6') IS NOT NULL DROP TABLE Reporting.QT6;
            CREATE TABLE Reporting.QT6 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT6 VALUES (2,'b'),(1,'a'),(3,'a');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);
        var sorts = new[]
        {
            new QuerySortRow { SelectedColumn = new ReportingColumn("Name", "nvarchar(50)", true, null), Direction = SortDirection.Ascending },
            new QuerySortRow { SelectedColumn = new ReportingColumn("Id",   "int",          true, null), Direction = SortDirection.Descending },
        };

        var result = await sut.QueryTopNAsync("QT6", top: 100, filters: Array.Empty<QueryFilterRow>(), sorts: sorts);

        Assert.Contains("[Name] ASC", result.ExecutedSql);
        Assert.Contains("[Id] DESC", result.ExecutedSql);
        // Rows should be sorted: Name ASC then Id DESC → (a,3),(a,1),(b,2)
        Assert.Equal(3, result.Rows.Count);
        Assert.Equal(3, result.Rows[0][0]); // Id=3 first (Name='a', Id DESC)
        Assert.Equal(1, result.Rows[1][0]); // Id=1 second
        Assert.Equal(2, result.Rows[2][0]); // Id=2 last (Name='b')
    }

    [Fact]
    public async Task QueryTopN_WithColumns_ProjectsSelectedColumns()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT7') IS NOT NULL DROP TABLE Reporting.QT7;
            CREATE TABLE Reporting.QT7 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT7 VALUES (1,'x'),(2,'y');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);

        var result = await sut.QueryTopNAsync(
            "QT7", 100,
            Array.Empty<QueryFilterRow>(),
            Array.Empty<QuerySortRow>(),
            columns: new[] { "Id", "Name" });

        Assert.Contains("[Id]", result.ExecutedSql);
        Assert.Contains("[Name]", result.ExecutedSql);
        Assert.DoesNotContain("TOP (100) *", result.ExecutedSql);
        Assert.Equal(2, result.Columns.Count);
        Assert.Equal(2, result.Rows.Count);
    }

    [Fact]
    public async Task QueryTopN_EmptyColumns_SelectsStar()
    {
        await SeedAsync(@"
            IF SCHEMA_ID('Reporting') IS NULL EXEC('CREATE SCHEMA Reporting');
            IF OBJECT_ID('Reporting.QT7') IS NOT NULL DROP TABLE Reporting.QT7;
            CREATE TABLE Reporting.QT7 (Id INT, Name NVARCHAR(50));
            INSERT INTO Reporting.QT7 VALUES (1,'x');
        ");
        var sut = new ReportingQueryService(_db.ConnectionString);

        var result = await sut.QueryTopNAsync(
            "QT7", 100,
            Array.Empty<QueryFilterRow>(),
            Array.Empty<QuerySortRow>(),
            columns: Array.Empty<string>());

        Assert.Contains("*", result.ExecutedSql);
    }

    [Fact]
    public async Task QueryTopN_InvalidColumnName_Throws()
    {
        var sut = new ReportingQueryService(_db.ConnectionString);

        await Assert.ThrowsAsync<ArgumentException>(() =>
            sut.QueryTopNAsync("QT7", 100,
                Array.Empty<QueryFilterRow>(),
                Array.Empty<QuerySortRow>(),
                columns: new[] { "x; DROP TABLE y" }));
    }
}
