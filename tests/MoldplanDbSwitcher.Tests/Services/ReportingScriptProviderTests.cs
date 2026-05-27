using System;
using System.IO;
using System.Linq;
using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class ReportingScriptProviderTests : IDisposable
{
    private readonly string _tempDir;

    public ReportingScriptProviderTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), "rsp_" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir)) Directory.Delete(_tempDir, true);
    }

    [Fact]
    public void GetScript_ExistingFile_ReturnsContent()
    {
        File.WriteAllText(Path.Combine(_tempDir, "01_Reporting_Create_Schema.sql"), "CREATE SCHEMA Reporting;");
        var sut = new ReportingScriptProvider(_tempDir);

        var script = sut.GetScript(1);

        Assert.Equal(1, script.FileNumber);
        Assert.Equal("01_Reporting_Create_Schema.sql", script.FileName);
        Assert.Contains("CREATE SCHEMA Reporting", script.Content);
    }

    [Fact]
    public void RenderJobScript_ReplacesChangeMePlaceholder()
    {
        File.WriteAllText(Path.Combine(_tempDir, "05_Reporting_DailyRefresh_Job.sql"),
            "DECLARE @DatabaseName NVARCHAR(128) = N'<<CHANGE_ME>>';");
        var sut = new ReportingScriptProvider(_tempDir);

        var rendered = sut.RenderJobScript(5, "MoldPlan", "sa");

        Assert.Contains("N'MoldPlan'", rendered);
        Assert.DoesNotContain("<<CHANGE_ME>>", rendered);
    }

    [Fact]
    public void RenderJobScript_EmptyDatabaseName_Throws()
    {
        var sut = new ReportingScriptProvider(_tempDir);
        Assert.Throws<ArgumentException>(() => sut.RenderJobScript(5, "", "sa"));
    }

    [Fact]
    public void GetScript_MissingFile_Throws()
    {
        var sut = new ReportingScriptProvider(_tempDir);
        Assert.Throws<FileNotFoundException>(() => sut.GetScript(1));
    }

    [Fact]
    public void ListAvailable_ReturnsAllNumbered()
    {
        File.WriteAllText(Path.Combine(_tempDir, "01_a.sql"), "a");
        File.WriteAllText(Path.Combine(_tempDir, "02_b.sql"), "b");
        File.WriteAllText(Path.Combine(_tempDir, "README.md"), "skip");
        var sut = new ReportingScriptProvider(_tempDir);

        var list = sut.ListAvailable();

        Assert.Equal(2, list.Count);
        Assert.Equal(new[] { 1, 2 }, list.Select(s => s.FileNumber));
    }
}
