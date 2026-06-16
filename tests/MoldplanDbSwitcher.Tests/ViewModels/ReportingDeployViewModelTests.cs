using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportingDeployViewModelTests
{
    private static IReportingDeployService DefaultDeploy()
    {
        var d = Substitute.For<IReportingDeployService>();
        d.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(false, false, 0, 0, 0));
        return d;
    }

    private static ReportingDeployViewModel CreateViewModel(IReportingDeployService? deploy = null)
    {
        deploy ??= DefaultDeploy();
        return new ReportingDeployViewModel(_ => deploy, "conn", "MoldPlan-Reporting");
    }

    // 保留舊名稱以相容舊有呼叫
    private static ReportingDeployViewModel CreateSut(
        IReportingObjectService? objects = null,
        IReportingDeployService? deploy = null)
        => CreateViewModel(deploy);

    // ── Scan ────────────────────────────────────────────────────────────────

    [Fact]
    public async Task ScanEnvironmentAsync_PopulatesStatus()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(true, true, 1, 0, 0));
        var sut = CreateViewModel(deploy);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.True(sut.SchemaExists);
        Assert.Equal(1, sut.TableCount);
    }

    // ── DeployAll ───────────────────────────────────────────────────────────

    [Fact]
    public async Task DeployAllAsync_RunsAllSteps()
    {
        var deploy = DefaultDeploy();
        // 透過 progress 回報 7 個成功步驟（01→07 序列）
        var successSteps = Enumerable.Range(1, 7)
            .Select(i => new DeployStep($"0{i}.sql", $"step{i}", DeployStatus.Success, null))
            .ToList<DeployStep>();
        deploy.DeployAllAsync(
                Arg.Any<ReportingDeployParameters>(),
                Arg.Any<IProgress<DeployStep>?>(),
                Arg.Any<CancellationToken>())
            .Returns(ci =>
            {
                var prog = ci.ArgAt<IProgress<DeployStep>?>(1);
                foreach (var s in successSteps) prog?.Report(s);
                return (IReadOnlyList<DeployStep>)successSteps;
            });
        var sut = CreateViewModel(deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Equal(7, sut.Steps.Count);
        Assert.All(sut.Steps, s => Assert.Equal(DeployStatus.Success, s.Status));
    }

    [Fact]
    public async Task DeployAll_PassesTargetAndSource_AndPopulatesStepsFromResult()
    {
        var deploy = DefaultDeploy();
        deploy.DeployAllAsync(
                Arg.Any<ReportingDeployParameters>(),
                Arg.Any<IProgress<DeployStep>?>(),
                Arg.Any<CancellationToken>())
            .Returns((IReadOnlyList<DeployStep>)new List<DeployStep>
            {
                new("01.sql", "建庫", DeployStatus.Success, null)
            });
        var vm = CreateViewModel(deploy);
        vm.TargetDatabaseName = "MoldPlan-Reporting";
        vm.SourceDatabaseName = "gma-staging";

        await vm.DeployAllCommand.ExecuteAsync(null);

        await deploy.Received().DeployAllAsync(
            Arg.Is<ReportingDeployParameters>(p =>
                p.TargetDatabase == "MoldPlan-Reporting" && p.SourceDatabase == "gma-staging"),
            Arg.Any<IProgress<DeployStep>?>(), Arg.Any<CancellationToken>());
        Assert.Single(vm.Steps, s => s.FileName == "01.sql");
        Assert.Equal(DeployStatus.Success, vm.Steps.Single(s => s.FileName == "01.sql").Status);
    }

    // ── IsFullyDeployed ─────────────────────────────────────────────────────

    [Fact]
    public void IsFullyDeployed_InitiallyFalse()
    {
        var sut = CreateSut();
        Assert.False(sut.IsFullyDeployed);
        Assert.True(sut.CanDeployAll);
        Assert.False(sut.CanDropAll);
    }

    [Fact]
    public async Task IsFullyDeployed_AfterScanWithFullCounts_ReturnsTrue()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(
                true, true,
                ReportingDeployViewModel.ExpectedTableCount,
                ReportingDeployViewModel.ExpectedViewCount,
                ReportingDeployViewModel.ExpectedProcedureCount));
        var sut = CreateViewModel(deploy);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.True(sut.IsFullyDeployed);
        Assert.False(sut.CanDeployAll);
        Assert.True(sut.CanDropAll);
    }

    [Fact]
    public async Task IsFullyDeployed_PartialDeployment_ReturnsFalse()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(true, true, 1, 0, 0));
        var sut = CreateViewModel(deploy);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.False(sut.IsFullyDeployed);
        Assert.True(sut.CanDeployAll);
        Assert.True(sut.CanDropAll);
    }

    // ── Misc ────────────────────────────────────────────────────────────────

    [Fact]
    public void DocumentType_And_Title_AreSet()
    {
        var vm = CreateSut();
        Assert.Equal("ReportingDeploy", vm.DocumentType);
        Assert.Equal("Reporting 部署", vm.Title);
        Assert.True(vm.CanClose);
    }

    [Fact]
    public async Task CanDropAll_NothingDeployed_ReturnsFalse()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.ScanInstallStatusAsync(Arg.Any<CancellationToken>())
            .Returns(new ReportingInstallStatus(false, false, 0, 0, 0));
        var sut = CreateViewModel(deploy);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.False(sut.CanDropAll);
        Assert.True(sut.CanDeployAll);
    }

    [Fact]
    public async Task DeployAllAsync_StopsOnFailure_ByReturningFailedSteps()
    {
        var deploy = DefaultDeploy();
        // 服務在第 1 步即失敗，透過 progress 回報後中止
        var failedStep = new DeployStep("01.sql", "schema", DeployStatus.Failed, "boom");
        deploy.DeployAllAsync(
                Arg.Any<ReportingDeployParameters>(),
                Arg.Any<IProgress<DeployStep>?>(),
                Arg.Any<CancellationToken>())
            .Returns(ci =>
            {
                var prog = ci.ArgAt<IProgress<DeployStep>?>(1);
                prog?.Report(failedStep);
                return (IReadOnlyList<DeployStep>)new List<DeployStep> { failedStep };
            });
        var sut = CreateViewModel(deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Single(sut.Steps);
        Assert.Equal(DeployStatus.Failed, sut.Steps[0].Status);
    }

    [Fact]
    public async Task UseConnectionAsync_ActiveConnection_DelegatesToStringOverload()
    {
        // 驗證 ActiveConnection 多載將 Database 欄位傳給兩參數的字串多載，使 SourceDatabaseName 被更新
        var sut = CreateSut();
        var connection = new ActiveConnection("Server=tcp:h;Database=ignored", "TargetMainDb", null);

        await sut.UseConnectionAsync(connection);

        Assert.Equal("TargetMainDb", sut.SourceDatabaseName);
    }

    // ── ExportSql ───────────────────────────────────────────────────────────

    [Fact]
    public async Task ExportSql_WritesGeneratedSqlToCallback()
    {
        var deploy = DefaultDeploy();
        deploy.GenerateExportSql(Arg.Any<ReportingDeployParameters>(), Arg.Any<bool>()).Returns("-- SQL");
        var vm = CreateViewModel(deploy);
        string? written = null;
        vm.SaveExportSqlCallback = (content) => { written = content; return Task.FromResult<string?>("C:/x.sql"); };
        await vm.ExportSqlCommand.ExecuteAsync(null);
        Assert.Equal("-- SQL", written);
    }
}
