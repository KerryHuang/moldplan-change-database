using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportingDeployViewModelTests
{
    private static ReportingDeployViewModel CreateSut(
        IReportingObjectService? objects = null,
        IReportingDeployService? deploy = null)
    {
        if (objects == null)
        {
            objects = Substitute.For<IReportingObjectService>();
            objects.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            objects.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            objects.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        }
        deploy ??= Substitute.For<IReportingDeployService>();
        return new ReportingDeployViewModel(_ => objects, _ => deploy, "conn", "MoldPlan");
    }

    [Fact]
    public async Task ScanEnvironmentAsync_PopulatesStatus()
    {
        var objects = Substitute.For<IReportingObjectService>();
        objects.SchemaExistsAsync(Arg.Any<CancellationToken>()).Returns(true);
        objects.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "T1", ReportingObjectKind.BaseTable, null)
            });
        objects.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        var sut = CreateSut(objects);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.True(sut.SchemaExists);
        Assert.Equal(1, sut.TableCount);
    }

    [Fact]
    public async Task DeployAllAsync_RunsAllSteps()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        // 回傳 7 個成功步驟（01→07 序列）
        var successSteps = Enumerable.Range(1, 7)
            .Select(i => new DeployStep($"0{i}.sql", $"step{i}", DeployStatus.Success, null))
            .ToList<DeployStep>();
        deploy.DeployAllAsync(
                Arg.Any<ReportingDeployParameters>(),
                Arg.Any<IProgress<DeployStep>>(),
                Arg.Any<CancellationToken>())
            .Returns(successSteps);
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Equal(7, sut.Steps.Count);
        Assert.All(sut.Steps, s => Assert.Equal(DeployStatus.Success, s.Status));
    }

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
        var objects = Substitute.For<IReportingObjectService>();
        objects.SchemaExistsAsync(Arg.Any<CancellationToken>()).Returns(true);
        objects.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(Enumerable.Range(1, ReportingDeployViewModel.ExpectedTableCount)
                .Select(i => new ReportingObject("Reporting", $"T{i}", ReportingObjectKind.BaseTable, null))
                .ToList<ReportingObject>());
        objects.ListViewsAsync(Arg.Any<CancellationToken>())
            .Returns(Enumerable.Range(1, ReportingDeployViewModel.ExpectedViewCount)
                .Select(i => new ReportingObject("Reporting", $"V{i}", ReportingObjectKind.View, null))
                .ToList<ReportingObject>());
        objects.ListProceduresAsync(Arg.Any<CancellationToken>())
            .Returns(Enumerable.Range(1, ReportingDeployViewModel.ExpectedProcedureCount)
                .Select(i => new ReportingObject("Reporting", $"P{i}", ReportingObjectKind.Procedure, null))
                .ToList<ReportingObject>());
        var sut = CreateSut(objects);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.True(sut.IsFullyDeployed);
        Assert.False(sut.CanDeployAll);
        Assert.True(sut.CanDropAll);
    }

    [Fact]
    public async Task IsFullyDeployed_PartialDeployment_ReturnsFalse()
    {
        var objects = Substitute.For<IReportingObjectService>();
        objects.SchemaExistsAsync(Arg.Any<CancellationToken>()).Returns(true);
        objects.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "T1", ReportingObjectKind.BaseTable, null)
            });
        objects.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        var sut = CreateSut(objects);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.False(sut.IsFullyDeployed);
        Assert.True(sut.CanDeployAll);
        Assert.True(sut.CanDropAll);
    }

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
        var objects = Substitute.For<IReportingObjectService>();
        objects.SchemaExistsAsync(Arg.Any<CancellationToken>()).Returns(false);
        objects.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        var sut = CreateSut(objects);

        await sut.ScanEnvironmentCommand.ExecuteAsync(null);

        Assert.False(sut.CanDropAll);
        Assert.True(sut.CanDeployAll);
    }

    [Fact]
    public async Task DeployAllAsync_StopsOnFailure_ByReturningFailedSteps()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        // 服務在第 1 步即失敗，只回傳 1 個步驟
        var failedSteps = new List<DeployStep>
        {
            new("01.sql", "schema", DeployStatus.Failed, "boom")
        };
        deploy.DeployAllAsync(
                Arg.Any<ReportingDeployParameters>(),
                Arg.Any<IProgress<DeployStep>>(),
                Arg.Any<CancellationToken>())
            .Returns(failedSteps);
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Single(sut.Steps);
        Assert.Equal(DeployStatus.Failed, sut.Steps[0].Status);
    }

    [Fact]
    public async Task UseConnectionAsync_ActiveConnection_DelegatesToStringOverload()
    {
        // 驗證 ActiveConnection 多載將 Database 欄位傳給兩參數的字串多載，使 TargetDatabaseName 被更新
        var sut = CreateSut();
        var connection = new ActiveConnection("Server=tcp:h;Database=ignored", "TargetMainDb", null);

        await sut.UseConnectionAsync(connection);

        Assert.Equal("TargetMainDb", sut.TargetDatabaseName);
    }
}
