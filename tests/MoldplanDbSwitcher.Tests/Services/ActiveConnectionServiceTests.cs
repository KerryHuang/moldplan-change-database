using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ActiveConnectionServiceTests
{
    [Fact]
    public void Current_InitiallyNull()
    {
        var svc = new ActiveConnectionService();
        Assert.Null(svc.Current);
    }

    [Fact]
    public void SetCurrent_UpdatesCurrent_AndRaisesChanged()
    {
        var svc = new ActiveConnectionService();
        ActiveConnection? raised = null;
        svc.Changed += c => raised = c;

        var conn = new ActiveConnection("cs", "db", null);
        svc.SetCurrent(conn);

        Assert.Same(conn, svc.Current);
        Assert.Same(conn, raised);
    }
}
