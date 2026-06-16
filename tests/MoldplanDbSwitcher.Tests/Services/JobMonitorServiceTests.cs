using System.Threading.Tasks;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Tests.TestHelpers;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class JobMonitorServiceTests
{
    [Theory]
    [InlineData("DROP TABLE x")]
    [InlineData("SomeOtherJob")]
    [InlineData("Reporting_DailyRefresh_MoldPlan; DROP")]
    public async Task TriggerJobAsync_NonWhitelistedName_Throws(string name)
    {
        var svc = new JobMonitorService("Server=tcp:nowhere;Database=d;User Id=sa;Password=x;TrustServerCertificate=True");
        await Assert.ThrowsAsync<System.InvalidOperationException>(() => svc.TriggerJobAsync(name));
    }
}

public class JobMonitorServiceIntegrationTests : IClassFixture<LocalDbFixture>
{
    private readonly LocalDbFixture _fixture;

    public JobMonitorServiceIntegrationTests(LocalDbFixture fixture)
    {
        _fixture = fixture;
    }

    [Fact]
    public async Task ListJobsAsync_AgainstMsdb_ReturnsListWithoutError()
    {
        // LocalDB msdb 通常沒有 Agent Jobs，預期回傳空清單不拋錯
        var connStr = "Server=(localdb)\\MSSQLLocalDB;Database=msdb;Integrated Security=True;TrustServerCertificate=True";
        var svc = new JobMonitorService(connStr);
        var result = await svc.ListJobsAsync();
        Assert.NotNull(result);
    }
}
