using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ServerTxtEntryTests
{
    [Fact]
    public void Parse_ValidLine_ReturnsCorrectEntry()
    {
        var entry = ServerTxtEntry.Parse("mis,yuchiun-test,100.73.36.124,XXX,1");

        Assert.Equal("mis", entry.Field1);
        Assert.Equal("yuchiun-test", entry.DatabaseName);
        Assert.Equal("100.73.36.124", entry.ServerAddress);
        Assert.Equal("XXX", entry.Field4);
        Assert.Equal("1", entry.Field5);
    }

    [Fact]
    public void Parse_InvalidLine_ThrowsFormatException()
    {
        Assert.Throws<FormatException>(() => ServerTxtEntry.Parse("only,two"));
    }

    [Fact]
    public void ToLine_ReturnsCommaSeparated()
    {
        var entry = new ServerTxtEntry
        {
            Field1 = "mis",
            DatabaseName = "yuchiun",
            ServerAddress = "127.0.0.1",
            Field4 = "XXX",
            Field5 = "1"
        };

        Assert.Equal("mis,yuchiun,127.0.0.1,XXX,1", entry.ToLine());
    }

    [Fact]
    public void Parse_ThenToLine_Roundtrip()
    {
        var original = "mis,yuchiun-test,100.73.36.124,XXX,1";
        var entry = ServerTxtEntry.Parse(original);
        Assert.Equal(original, entry.ToLine());
    }
}
