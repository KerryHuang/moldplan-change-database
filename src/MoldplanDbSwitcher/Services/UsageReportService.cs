using ClosedXML.Excel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UsageReportService : IUsageReportService
{
    private readonly IUsageQueryService _usageQuery;

    private static readonly XLColor HeaderBg = XLColor.FromHtml("#4472C4");
    private static readonly XLColor HeaderFg = XLColor.White;

    public UsageReportService(IUsageQueryService usageQuery)
    {
        _usageQuery = usageQuery;
    }

    public async Task<UsageReportData> QueryAllAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null)
    {
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

        // 取得所有客戶名稱（保持插入順序，去重）
        var customers = data.Rows.Select(r => r.CustomerName).Distinct().ToList();

        // 取得所有程式（依程式編號排序）
        var programs = data.Rows
            .Select(r => (r.Entry.ProgNo, r.Entry.ProgName))
            .Distinct()
            .OrderBy(p => p.ProgNo)
            .ToList();

        // 建立查詢字典：(CustomerName, ProgNo) -> Count
        var lookup = data.Rows.ToDictionary(
            r => (r.CustomerName, r.Entry.ProgNo),
            r => r.Entry.Count);

        // 標題列：程式編號 | 程式名稱 | 客戶1 | 客戶2 | ... | 合計
        int colCount = 2 + customers.Count + 1;
        ws.Cell(1, 1).Value = "程式編號";
        ws.Cell(1, 2).Value = "程式名稱";
        for (int i = 0; i < customers.Count; i++)
            ws.Cell(1, 3 + i).Value = customers[i];
        ws.Cell(1, 2 + customers.Count + 1).Value = "合計";

        // 標題列樣式
        var headerRange = ws.Range(1, 1, 1, colCount);
        headerRange.Style.Fill.BackgroundColor = HeaderBg;
        headerRange.Style.Font.FontColor = HeaderFg;
        headerRange.Style.Font.Bold = true;
        headerRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        headerRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;

        // 資料列
        int row = 2;
        foreach (var (progNo, progName) in programs)
        {
            ws.Cell(row, 1).Value = progNo;
            ws.Cell(row, 2).Value = progName;

            int total = 0;
            for (int i = 0; i < customers.Count; i++)
            {
                var count = lookup.TryGetValue((customers[i], progNo), out var c) ? c : 0;
                ws.Cell(row, 3 + i).Value = count;
                total += count;
            }
            ws.Cell(row, 2 + customers.Count + 1).Value = total;
            row++;
        }

        // 框線與 AutoFilter
        if (row > 2)
        {
            var dataRange = ws.Range(1, 1, row - 1, colCount);
            dataRange.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            dataRange.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
            dataRange.SetAutoFilter();
        }

        ws.Columns().AdjustToContents(5.0, 40.0);
        wb.SaveAs(path);
        return Task.CompletedTask;
    }
}
