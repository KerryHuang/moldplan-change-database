using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionProfileComparerTests
{
    private static ConnectionProfile P(string name, DatabaseEnvironment env, bool isDefault = false) =>
        new() { Name = name, Server = "s", Database = "d", Environment = env, IsDefault = isDefault };

    [Fact]
    public void 預設連線_排在非預設之前()
    {
        var list = new List<ConnectionProfile>
        {
            P("Zzz", DatabaseEnvironment.Development),
            P("Aaa", DatabaseEnvironment.Production, isDefault: true)
        };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal("Aaa", list[0].Name);
    }

    [Fact]
    public void 非預設_依環境列舉順序()
    {
        var list = new List<ConnectionProfile>
        {
            P("a", DatabaseEnvironment.Production),
            P("b", DatabaseEnvironment.Development),
            P("c", DatabaseEnvironment.Staging),
            P("d", DatabaseEnvironment.Testing)
        };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal(
            new[] { DatabaseEnvironment.Development, DatabaseEnvironment.Testing, DatabaseEnvironment.Staging, DatabaseEnvironment.Production },
            list.Select(p => p.Environment).ToArray());
    }

    [Fact]
    public void 同環境同預設_依名稱不分大小寫()
    {
        var list = new List<ConnectionProfile> { P("banana", DatabaseEnvironment.Staging), P("Apple", DatabaseEnvironment.Staging) };
        list.Sort(ConnectionProfileComparer.Instance);
        Assert.Equal("Apple", list[0].Name);
    }

    [Fact]
    public void Null_排最後()
    {
        var a = P("a", DatabaseEnvironment.Staging);
        Assert.True(ConnectionProfileComparer.Instance.Compare(a, null) < 0);
        Assert.True(ConnectionProfileComparer.Instance.Compare(null, a) > 0);
        Assert.Equal(0, ConnectionProfileComparer.Instance.Compare(null, null));
    }
}
