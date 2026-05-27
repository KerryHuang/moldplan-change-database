using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingScriptProvider : IReportingScriptProvider
{
    private readonly string _scriptsDir;

    public ReportingScriptProvider(string scriptsDir)
    {
        _scriptsDir = scriptsDir;
    }

    public ReportingScript GetScript(int fileNumber)
    {
        var prefix = fileNumber.ToString("D2") + "_";
        var file = Directory.EnumerateFiles(_scriptsDir, "*.sql")
            .FirstOrDefault(f => Path.GetFileName(f).StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
            ?? throw new FileNotFoundException($"找不到編號 {fileNumber:D2} 的腳本", _scriptsDir);
        return new ReportingScript(fileNumber, Path.GetFileName(file), File.ReadAllText(file));
    }

    public string RenderJobScript(int fileNumber, string databaseName, string jobOwner)
    {
        if (string.IsNullOrWhiteSpace(databaseName))
            throw new ArgumentException("databaseName 不可為空", nameof(databaseName));
        var script = GetScript(fileNumber);
        return script.Content
            .Replace("<<CHANGE_ME>>", databaseName)
            .Replace("@JobOwner = N'sa'", $"@JobOwner = N'{jobOwner}'");
    }

    public IReadOnlyList<ReportingScript> ListAvailable()
    {
        if (!Directory.Exists(_scriptsDir)) return Array.Empty<ReportingScript>();
        return Directory.EnumerateFiles(_scriptsDir, "*.sql")
            .Select(f => Path.GetFileName(f))
            .Where(n => n.Length >= 3 && char.IsDigit(n[0]) && char.IsDigit(n[1]) && n[2] == '_')
            .Select(n => GetScript(int.Parse(n.Substring(0, 2))))
            .OrderBy(s => s.FileNumber)
            .ToList();
    }
}
