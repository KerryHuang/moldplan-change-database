using System.Linq;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class EmbeddedReportingScriptsTests
{
    [Theory]
    [InlineData("01_Reporting_Create_Database.sql")]
    [InlineData("02_Reporting_Create_Schema.sql")]
    [InlineData("03_Reporting_Create_Tables.sql")]
    [InlineData("04_Reporting_Create_Views.sql")]
    [InlineData("05_Reporting_Create_StoredProcedures.sql")]
    [InlineData("06_Reporting_DailyRefresh_Job.sql")]
    [InlineData("07_Reporting_HourlyRefresh_Job.sql")]
    [InlineData("98_Reporting_Drop_All.sql")]
    [InlineData("99_Reporting_Monitor.sql")]
    public void EmbeddedScript_IsPresent_AndNonEmpty(string fileName)
    {
        var asm = typeof(MoldplanDbSwitcher.Services.ReportingScriptProvider).Assembly;
        var name = asm.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith(fileName, System.StringComparison.OrdinalIgnoreCase));
        Assert.NotNull(name);
        using var s = asm.GetManifestResourceStream(name!);
        Assert.NotNull(s);
        using var r = new System.IO.StreamReader(s!);
        var content = r.ReadToEnd();
        Assert.False(string.IsNullOrWhiteSpace(content));
        Assert.False(content.StartsWith('﻿'), "不應含 BOM");
    }
}
