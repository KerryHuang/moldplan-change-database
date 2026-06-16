using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ReportingScriptProvider : IReportingScriptProvider
{
    private const string EmbeddedPrefix = "MoldplanDbSwitcher.Scripts.Reporting.";
    private readonly string? _externalOverrideDir;
    private static readonly Assembly Asm = typeof(ReportingScriptProvider).Assembly;

    public ReportingScriptProvider(string? externalOverrideDir)
    {
        _externalOverrideDir = externalOverrideDir;
    }

    public ReportingScript GetScript(int fileNumber)
    {
        var prefix = fileNumber.ToString("D2") + "_";

        if (!string.IsNullOrWhiteSpace(_externalOverrideDir) && Directory.Exists(_externalOverrideDir))
        {
            var ext = Directory.EnumerateFiles(_externalOverrideDir, "*.sql")
                .FirstOrDefault(f => Path.GetFileName(f).StartsWith(prefix, StringComparison.OrdinalIgnoreCase));
            if (ext != null)
                return new ReportingScript(fileNumber, Path.GetFileName(ext), StripBom(File.ReadAllText(ext)));
        }

        var resName = Asm.GetManifestResourceNames()
            .FirstOrDefault(n => n.StartsWith(EmbeddedPrefix + prefix, StringComparison.OrdinalIgnoreCase))
            ?? throw new FileNotFoundException($"找不到編號 {fileNumber:D2} 的內嵌腳本");
        using var s = Asm.GetManifestResourceStream(resName)!;
        using var r = new StreamReader(s);
        var fileName = resName.Substring(EmbeddedPrefix.Length);
        return new ReportingScript(fileNumber, fileName, StripBom(r.ReadToEnd()));
    }

    public string Render(int fileNumber, ReportingDeployParameters p)
    {
        if (string.IsNullOrWhiteSpace(p.TargetDatabase))
            throw new ArgumentException("TargetDatabase 不可為空", nameof(p));
        var content = GetScript(fileNumber).Content
            .Replace("<<Database>>", p.TargetDatabase)
            .Replace("<<MAINDB>>", p.SourceDatabase ?? "");
        // 替換 Job 腳本中的 @JobOwner DECLARE 值（格式：DECLARE @JobOwner NVARCHAR(128) = N'...'）
        content = Regex.Replace(
            content,
            @"(@JobOwner\s+NVARCHAR\(\d+\)\s*=\s*N')[^']*(')",
            $"$1{p.JobOwner}$2",
            RegexOptions.IgnoreCase);
        return content;
    }

    public IReadOnlyList<ReportingScript> ListAvailable()
    {
        var numbers = Asm.GetManifestResourceNames()
            .Where(n => n.StartsWith(EmbeddedPrefix, StringComparison.OrdinalIgnoreCase) && n.EndsWith(".sql"))
            .Select(n => n.Substring(EmbeddedPrefix.Length))
            .Where(f => f.Length >= 3 && char.IsDigit(f[0]) && char.IsDigit(f[1]) && f[2] == '_')
            .Select(f => int.Parse(f.Substring(0, 2)))
            .Distinct().OrderBy(x => x);
        return numbers.Select(GetScript).ToList();
    }

    private static string StripBom(string s) => s.StartsWith('﻿') ? s.Substring(1) : s;
}
