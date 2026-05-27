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
