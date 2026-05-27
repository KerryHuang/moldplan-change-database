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
        deploy.DeploySchemaAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("01.sql", "schema", DeployStatus.Success, null));
        deploy.DeployTablesAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("02.sql", "tables", DeployStatus.Success, null));
        deploy.DeployViewsAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("03.sql", "views", DeployStatus.Success, null));
        deploy.DeployProceduresAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("04.sql", "sp", DeployStatus.Success, null));
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Equal(4, sut.Steps.Count);
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
    public async Task DeployAllAsync_StopsOnFailure()
    {
        var deploy = Substitute.For<IReportingDeployService>();
        deploy.DeploySchemaAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>())
            .Returns(new DeployStep("01.sql", "schema", DeployStatus.Failed, "boom"));
        var sut = CreateSut(deploy: deploy);

        await sut.DeployAllCommand.ExecuteAsync(null);

        Assert.Single(sut.Steps);
        await deploy.DidNotReceive().DeployTablesAsync(Arg.Any<IProgress<DeployStep>>(), Arg.Any<CancellationToken>());
    }
}
