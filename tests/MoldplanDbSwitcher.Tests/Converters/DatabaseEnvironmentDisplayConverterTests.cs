using System.Globalization;
using Xunit;
using MoldplanDbSwitcher.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Converters;

public class DatabaseEnvironmentDisplayConverterTests
{
    private readonly DatabaseEnvironmentDisplayConverter _c = new();

    [Theory]
    [InlineData(DatabaseEnvironment.Development, "開發環境")]
    [InlineData(DatabaseEnvironment.Testing, "測試環境")]
    [InlineData(DatabaseEnvironment.Staging, "預備環境")]
    [InlineData(DatabaseEnvironment.Production, "正式環境")]
    public void Convert_列舉_應為繁中(DatabaseEnvironment env, string expected)
    {
        Assert.Equal(expected, _c.Convert(env, typeof(string), null, CultureInfo.InvariantCulture));
    }
}
