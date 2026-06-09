using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class DatabaseEnvironmentInferenceTests
{
    [Theory]
    [InlineData("Foo - 正式", DatabaseEnvironment.Production)]
    [InlineData("Foo - 測試", DatabaseEnvironment.Testing)]
    [InlineData("Foo-Staging", DatabaseEnvironment.Staging)]
    [InlineData("", DatabaseEnvironment.Staging)]
    [InlineData(null, DatabaseEnvironment.Staging)]
    public void FromName_應依關鍵字推斷(string? name, DatabaseEnvironment expected)
    {
        Assert.Equal(expected, DatabaseEnvironmentInference.FromName(name));
    }
}
