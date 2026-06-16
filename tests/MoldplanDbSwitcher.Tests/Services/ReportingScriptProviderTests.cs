using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingScriptProviderTests
{
    private static ReportingScriptProvider Embedded() => new(externalOverrideDir: null);

    [Fact]
    public void GetScript_Embedded_ReturnsContentByFileNumber()
    {
        var s = Embedded().GetScript(2);
        Assert.Equal(2, s.FileNumber);
        Assert.Contains("Reporting", s.Content);
    }

    [Fact]
    public void Render_ReplacesBothPlaceholders()
    {
        var sql = Embedded().Render(4, new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging"));
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.DoesNotContain("<<MAINDB>>", sql);
        Assert.Contains("gma-staging", sql);
    }

    [Fact]
    public void Render_JobScript_SubstitutesDatabaseAndOwner()
    {
        var sql = Embedded().Render(6, new ReportingDeployParameters("MoldPlan-Reporting", "gma-staging", JobOwner: "deployer"));
        Assert.DoesNotContain("<<Database>>", sql);
        Assert.Contains("MoldPlan-Reporting", sql);
        Assert.Contains("N'deployer'", sql);
    }

    [Fact]
    public void Render_EmptyTarget_Throws()
    {
        Assert.Throws<System.ArgumentException>(() =>
            Embedded().Render(2, new ReportingDeployParameters("", "main")));
    }

    [Fact]
    public void ExternalOverride_WhenFileExists_PrefersExternalContent()
    {
        var dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), System.IO.Path.GetRandomFileName());
        System.IO.Directory.CreateDirectory(dir);
        try
        {
            System.IO.File.WriteAllText(System.IO.Path.Combine(dir, "02_Override.sql"), "USE [<<Database>>]; -- EXTERNAL");
            var sql = new ReportingScriptProvider(externalOverrideDir: dir)
                .Render(2, new ReportingDeployParameters("DB", "main"));
            Assert.Contains("EXTERNAL", sql);
        }
        finally { System.IO.Directory.Delete(dir, true); }
    }

    [Fact]
    public void ListAvailable_Embedded_ReturnsNineScripts()
    {
        Assert.Equal(9, Embedded().ListAvailable().Count);
    }
}
