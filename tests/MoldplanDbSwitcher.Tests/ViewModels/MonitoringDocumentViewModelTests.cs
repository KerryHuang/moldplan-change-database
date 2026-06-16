using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels.Documents;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class MonitoringDocumentViewModelTests
{
    private static MonitoringDocumentViewModel Create(IJobMonitorService? monitor = null)
    {
        if (monitor is null)
        {
            monitor = Substitute.For<IJobMonitorService>();
            monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>());
            monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(new List<RefreshLogEntry>());
        }
        return new MonitoringDocumentViewModel(_ => monitor, initialConnectionString: "Server=x;Database=d;");
    }

    [Fact]
    public void DocumentType_And_Title()
    {
        var vm = Create();
        Assert.Equal("ReportingMonitor", vm.DocumentType);
        Assert.Equal("Reporting 監控", vm.Title);
        Assert.True(vm.CanClose);
        Assert.Equal(30, vm.RefreshIntervalSeconds);
    }

    [Fact]
    public async Task Refresh_LoadsJobsRefreshLog_AndComputesSummary()
    {
        var monitor = Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>
        {
            new("A", true, null, "成功", null, null),
            new("B", true, null, "失敗", null, null),
        });
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>())
               .Returns(new List<RefreshLogEntry> { new(System.DateTime.Now, 100, 5, "Success", null) });
        var vm = Create(monitor);

        await vm.RefreshCommand.ExecuteAsync(null);

        Assert.Equal(2, vm.Jobs.Count);
        Assert.Single(vm.RefreshLog);
        Assert.Equal(2, vm.Summary.TotalJobs);
        Assert.Equal(1, vm.Summary.FailedCount);
    }

    [Fact]
    public async Task TriggerDailyJob_CallsServiceWithDailyJobName()
    {
        var monitor = Substitute.For<IJobMonitorService>();
        monitor.ListJobsAsync(Arg.Any<CancellationToken>()).Returns(new List<AgentJobStatus>());
        monitor.GetRefreshLogAsync(Arg.Any<int>(), Arg.Any<CancellationToken>()).Returns(new List<RefreshLogEntry>());
        var vm = Create(monitor);

        await vm.TriggerDailyJobCommand.ExecuteAsync(null);

        await monitor.Received().TriggerJobAsync("Reporting_DailyRefresh_MoldPlan", Arg.Any<CancellationToken>());
    }
}
