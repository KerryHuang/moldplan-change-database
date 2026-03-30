using ClosedXML.Excel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UsageReportService : IUsageReportService
{
    private readonly IConnectionSourceService _connectionSource;
    private readonly IUsageQueryService _usageQuery;

    private static readonly XLColor HeaderBg = XLColor.FromHtml("#4472C4");
    private static readonly XLColor HeaderFg = XLColor.White;

    public UsageReportService(IConnectionSourceService connectionSource, IUsageQueryService usageQuery)
    {
        _connectionSource = connectionSource;
        _usageQuery = usageQuery;
    }

    public async Task<UsageReportData> QueryAllAsync(IProgress<string>? progress = null)
    {
        var profiles = _connectionSource.LoadAllConnections();
        var result = new UsageReportData();

        var endDate = DateTime.Today;
        var startDate = endDate.AddMonths(-6);

        for (int i = 0; i < profiles.Count; i++)
        {
            var profile = profiles[i];
            progress?.Report($"正在查詢第 {i + 1}/{profiles.Count} 個客戶：{profile.Name}...");

            try
            {
                var entries = await _usageQuery.QueryUsageAsync(profile, startDate, endDate);
                if (entries.Count == 0)
                {
                    result.SkippedConnections.Add(profile.Name);
                    continue;
                }
                foreach (var entry in entries)
                    result.Rows.Add((profile.Name, entry));
            }
            catch
            {
                result.FailedConnections.Add(profile.Name);
            }
        }

        return result;
    }

    public Task ExportToExcelAsync(string path, UsageReportData data)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add("使用工時統計");

        var headers = new[] { "客戶", "程式編號", "程式名稱", "使用時間（分）", "次數" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(1, i + 1).Value = headers[i];

        var headerRange = ws.Range(1, 1, 1, headers.Length);
        headerRange.Style.Fill.BackgroundColor = HeaderBg;
        headerRange.Style.Font.FontColor = HeaderFg;
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

        int row = 2;
        foreach (var (customerName, entry) in data.Rows)
        {
            ws.Cell(row, 1).Value = customerName;
            ws.Cell(row, 2).Value = entry.ProgNo;
            ws.Cell(row, 3).Value = entry.ProgName;
            ws.Cell(row, 4).Value = entry.UsageMinutes;
            ws.Cell(row, 4).Style.NumberFormat.Format = "0.00";
            ws.Cell(row, 5).Value = entry.Count;
            row++;
        }

        if (row > 2)
        {
            var dataRange = ws.Range(1, 1, row - 1, headers.Length);
            dataRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            dataRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
            dataRange.SetAutoFilter();
        }

        ws.Columns().AdjustToContents(5.0, 40.0);
        wb.SaveAs(path);
        return Task.CompletedTask;
    }
}
