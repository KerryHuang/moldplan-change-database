using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingDeployServiceExportTests
{
    private static ReportingDeployService Create()
    {
        var provider = new ReportingScriptProvider(externalOverrideDir: null);
        var executor = Substitute.For<ISqlBatchExecutor>();
        return new ReportingDeployService(
            "Server=tcp:host;Database=MoldPlan-Reporting;User Id=sa;Password=x;TrustServerCertificate=True",
            provider, executor);
    }

    [Fact]
    public void GenerateExportSql_SubstitutesPlaceholders_AndOrders01To07()
    {
        var sql = Create().GenerateExportSql(new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging"));
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.DoesNotContain("<<MAINDB>>", sql);
        Assert.Contains("gma-staging", sql);
        Assert.True(sql.IndexOf("Create_Database", System.StringComparison.OrdinalIgnoreCase)
                  < sql.IndexOf("StoredProcedures", System.StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void GenerateExportSql_IncludeDrop_AppendsDropScript()
    {
        var sql = Create().GenerateExportSql(new ReportingDeployParameters("MoldPlan-Reporting", "main"), includeDrop: true);
        Assert.Contains("Drop", sql, System.StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task DropAllAsync_ConfirmNameMismatch_Throws()
    {
        var svc = Create();
        await Assert.ThrowsAsync<System.InvalidOperationException>(() =>
            svc.DropAllAsync(new ReportingDeployParameters("MoldPlan-Reporting", "main"), "WrongName"));
    }

    [Fact]
    public void GenerateExportSql_IncludeDropFalse_DoesNotContainDropBeforeCreate()
    {
        // 未勾選 includeDrop 時，輸出應只包含 01→07，不含 Drop 區塊在 Create 之前
        var sql = Create().GenerateExportSql(new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging"), includeDrop: false);
        // StoredProcedures（05）出現在 Create_Database（01）之後
        Assert.True(sql.IndexOf("Create_Database", System.StringComparison.OrdinalIgnoreCase)
                  < sql.IndexOf("StoredProcedures", System.StringComparison.OrdinalIgnoreCase));
        // 不包含 Drop 區塊標頭（98 腳本）
        Assert.DoesNotContain("=== 98_", sql, System.StringComparison.OrdinalIgnoreCase);
    }
}
