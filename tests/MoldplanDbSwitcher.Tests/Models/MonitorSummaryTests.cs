using System;
using System.Collections.Generic;
using MoldplanDbSwitcher.Models;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Models;

public class MonitorSummaryTests
{
    private static AgentJobStatus Job(string name, bool enabled, string outcome) =>
        new(name, enabled, null, outcome, null, null);

    [Fact]
    public void FromJobs_CountsSucceededFailedDisabled()
    {
        var jobs = new List<AgentJobStatus>
        {
            Job("A", true, "成功"),
            Job("B", true, "失敗"),
            Job("C", false, "成功"),
        };
        var s = MonitorSummary.FromJobs(jobs);
        Assert.Equal(2, s.SucceededCount);
        Assert.Equal(1, s.FailedCount);
        Assert.Equal(1, s.DisabledCount);
        Assert.Equal(3, s.TotalJobs);
    }

    [Fact]
    public void FromJobs_Empty_AllZero()
    {
        var s = MonitorSummary.FromJobs(new List<AgentJobStatus>());
        Assert.Equal(0, s.TotalJobs);
        Assert.Equal(0, s.FailedCount);
    }
}
