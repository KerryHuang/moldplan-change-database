using System.Globalization;
using Xunit;
using MoldplanDbSwitcher.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Converters;

public class ConnectionProfileDisplayConverterTests
{
    private readonly ConnectionProfileDisplayConverter _c = new();

    private static ConnectionProfile P(string name, DatabaseEnvironment env, bool isDefault = false) =>
        new() { Name = name, Server = "s", Database = "d", Environment = env, IsDefault = isDefault };

    [Theory]
    [InlineData(DatabaseEnvironment.Development, "【開發】X")]
    [InlineData(DatabaseEnvironment.Testing, "【測試】X")]
    [InlineData(DatabaseEnvironment.Staging, "【預備】X")]
    [InlineData(DatabaseEnvironment.Production, "【正式】X")]
    public void Convert_非預設_應為環境標籤加名稱(DatabaseEnvironment env, string expected)
    {
        Assert.Equal(expected, _c.Convert(P("X", env), typeof(string), null, CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Convert_預設_應附加預設標記()
    {
        Assert.Equal("【正式】prod (預設)",
            _c.Convert(P("prod", DatabaseEnvironment.Production, isDefault: true), typeof(string), null, CultureInfo.InvariantCulture));
    }

    [Fact]
    public void Convert_非ConnectionProfile_回傳原值字串()
    {
        Assert.Equal("其他", _c.Convert("其他", typeof(string), null, CultureInfo.InvariantCulture));
    }
}
