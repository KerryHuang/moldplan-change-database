using ClosedXML.Excel;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class FeatureReportService : IFeatureReportService
{
    private readonly IFeatureQueryService _featureQuery;

    // 顏色常數
    private static readonly XLColor HeaderBg = XLColor.FromHtml("#4472C4");
    private static readonly XLColor HeaderFg = XLColor.White;
    private static readonly XLColor GreenBg = XLColor.FromHtml("#C6EFCE");
    private static readonly XLColor RedBg = XLColor.FromHtml("#FFC7CE");
    private static readonly XLColor YellowBg = XLColor.FromHtml("#FFFF00");
    private static readonly XLColor GreenFont = XLColor.FromHtml("#006100");
    private static readonly XLColor RedFont = XLColor.FromHtml("#9C0006");

    public FeatureReportService(IFeatureQueryService featureQuery)
    {
        _featureQuery = featureQuery;
    }

    public async Task<FeatureReportData> QueryAllCustomerFeaturesAsync(
        IReadOnlyList<ConnectionProfile> profiles,
        IProgress<string>? progress = null)
    {
        var result = new FeatureReportData();

        for (int i = 0; i < profiles.Count; i++)
        {
            var profile = profiles[i];
            progress?.Report($"正在查詢第 {i + 1}/{profiles.Count} 個客戶：{profile.Name}...");

            try
            {
                var features = await _featureQuery.QueryFeaturesAsync(profile);
                if (features.Count == 0)
                {
                    result.SkippedConnections.Add(profile.Name);
                    continue;
                }
                var customer = CustomerFeatureData.FromConnectionName(profile.Name, profile.Database);
                customer.Features = features;
                result.Customers.Add(customer);
            }
            catch
            {
                result.FailedConnections.Add(profile.Name);
            }
        }

        return result;
    }

    public Task ExportToExcelAsync(string path, FeatureReportData data)
    {
        using var wb = new XLWorkbook();
        var customers = data.Customers;
        var codes = customers.Select(c => c.Code).ToList();

        var allFeatures = customers
            .SelectMany(c => c.Features)
            .GroupBy(f => (f.SysType, f.ItemId))
            .Select(g => g.First())
            .OrderBy(f => f.SysType)
            .ThenBy(f => f.ItemId)
            .ToList();

        var lookup = new Dictionary<(string Code, string ItemId), string>();
        var customerItemIds = new Dictionary<string, HashSet<string>>();
        foreach (var c in customers)
        {
            customerItemIds[c.Code] = c.Features.Select(f => f.ItemId).ToHashSet();
            foreach (var f in c.Features)
                lookup[(c.Code, f.ItemId)] = f.OpenYn;
        }

        WriteSheet1CustomerSummary(wb, customers);
        WriteSheet2OpenedFeatures(wb, allFeatures, customers, codes, lookup, customerItemIds);
        WriteSheet3AllShared(wb, allFeatures, customers, codes, lookup, customerItemIds);
        WriteSheet4PerCustomerOpened(wb, customers);
        WriteSheet5DiffFeatures(wb, allFeatures, customers, codes, lookup, customerItemIds);
        WriteSheet6FullDetail(wb, allFeatures, customers, codes, lookup, customerItemIds);
        WriteSheet7UniqueFeatures(wb, allFeatures, customers, customerItemIds);
        WriteSheet8PivotData(wb, customers);

        wb.SaveAs(path);
        return Task.CompletedTask;
    }

    // === 共用格式化方法 ===

    private static void StyleHeaderRow(IXLWorksheet ws, int row, int colCount)
    {
        var range = ws.Range(row, 1, row, colCount);
        range.Style.Fill.BackgroundColor = HeaderBg;
        range.Style.Font.FontColor = HeaderFg;
        range.Style.Font.Bold = true;
        range.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        range.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
    }

    private static void StyleSubHeaderRow(IXLWorksheet ws, int row, int colCount)
    {
        var range = ws.Range(row, 1, row, colCount);
        range.Style.Fill.BackgroundColor = XLColor.FromHtml("#D9E2F3");
        range.Style.Font.Bold = true;
        range.Style.Font.FontColor = XLColor.FromHtml("#44546A");
        range.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        range.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
    }

    private static void StyleValueCell(IXLCell cell, string value)
    {
        switch (value)
        {
            case "Y":
                cell.Style.Fill.BackgroundColor = GreenBg;
                cell.Style.Font.FontColor = GreenFont;
                break;
            case "N":
                cell.Style.Fill.BackgroundColor = RedBg;
                cell.Style.Font.FontColor = RedFont;
                break;
        }
        cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
    }

    private static void AddAutoFilter(IXLWorksheet ws, int headerRow, int lastRow, int colCount)
    {
        if (lastRow > headerRow)
            ws.Range(headerRow, 1, lastRow, colCount).SetAutoFilter();
    }

    private static void AutoFitColumns(IXLWorksheet ws)
    {
        ws.Columns().AdjustToContents(5.0, 40.0);
    }

    private static void StyleDataRange(IXLWorksheet ws, int headerRow, int lastRow, int colCount)
    {
        if (lastRow >= headerRow)
        {
            var range = ws.Range(headerRow, 1, lastRow, colCount);
            range.Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            range.Style.Border.InsideBorder = XLBorderStyleValues.Thin;
        }
    }

    private static void WriteLegend(IXLWorksheet ws, bool includeDiff = false)
    {
        ws.Cell(1, 1).Value = "顏色標記說明";
        ws.Cell(1, 1).Style.Font.Bold = true;

        ws.Cell(2, 1).Value = "Y";
        ws.Cell(2, 2).Value = "已開啟";
        ws.Cell(2, 1).Style.Fill.BackgroundColor = GreenBg;
        ws.Cell(2, 1).Style.Font.FontColor = GreenFont;
        ws.Cell(2, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        ws.Range(2, 1, 2, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;

        ws.Cell(3, 1).Value = "N";
        ws.Cell(3, 2).Value = "未開啟";
        ws.Cell(3, 1).Style.Fill.BackgroundColor = RedBg;
        ws.Cell(3, 1).Style.Font.FontColor = RedFont;
        ws.Cell(3, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        ws.Range(3, 1, 3, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;

        ws.Cell(4, 1).Value = "-";
        ws.Cell(4, 2).Value = "該客戶無此功能";
        ws.Cell(4, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        ws.Range(4, 1, 4, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;

        if (includeDiff)
        {
            ws.Cell(5, 1).Value = "差異";
            ws.Cell(5, 2).Value = "各客戶間設定不一致（黃底標記於模組/ITEM_ID/功能名稱欄）";
            ws.Cell(5, 1).Style.Fill.BackgroundColor = YellowBg;
            ws.Cell(5, 1).Style.Font.Bold = true;
            ws.Cell(5, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
            ws.Range(5, 1, 5, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
        }
    }

    private static void WriteCrossTableHeader(IXLWorksheet ws, int row, List<string> codes)
    {
        ws.Cell(row, 1).Value = "模組";
        ws.Cell(row, 2).Value = "ITEM_ID";
        ws.Cell(row, 3).Value = "功能名稱";
        for (int i = 0; i < codes.Count; i++)
            ws.Cell(row, 4 + i).Value = codes[i];

        StyleHeaderRow(ws, row, 3 + codes.Count);
    }

    private static string GetCellValue(string code, string itemId,
        Dictionary<(string, string), string> lookup, Dictionary<string, HashSet<string>> customerItemIds)
    {
        if (!customerItemIds[code].Contains(itemId))
            return "-";
        return lookup.TryGetValue((code, itemId), out var val) ? val : "-";
    }

    // === Sheet 1: 客戶總覽 ===

    private static void WriteSheet1CustomerSummary(IXLWorkbook wb, List<CustomerFeatureData> customers)
    {
        var ws = wb.Worksheets.Add("客戶總覽");
        var headers = new[] { "代碼", "客戶名稱", "資料庫", "功能總數", "已開啟(Y)", "未開啟(N)", "開啟率" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(1, i + 1).Value = headers[i];
        StyleHeaderRow(ws, 1, headers.Length);

        for (int i = 0; i < customers.Count; i++)
        {
            var c = customers[i];
            var row = i + 2;
            var total = c.Features.Count;
            var opened = c.Features.Count(f => f.OpenYn == "Y");
            var closed = total - opened;

            ws.Cell(row, 1).Value = c.Code;
            ws.Cell(row, 2).Value = c.CustomerName;
            ws.Cell(row, 3).Value = c.Database;
            ws.Cell(row, 4).Value = total;
            ws.Cell(row, 5).Value = opened;
            ws.Cell(row, 6).Value = closed;
            ws.Cell(row, 7).Value = total > 0 ? (double)opened / total : 0;
            ws.Cell(row, 7).Style.NumberFormat.Format = "0.0%";

            // 數字欄置中
            for (int col = 4; col <= 7; col++)
                ws.Cell(row, col).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        }

        var lastDataRow = customers.Count + 1;
        // 加框線
        if (customers.Count > 0)
            ws.Range(1, 1, lastDataRow, headers.Length).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;

        // 顏色標記說明（在資料下方空兩行）
        var legendStart = lastDataRow + 2;
        ws.Cell(legendStart, 1).Value = "顏色標記說明";
        ws.Cell(legendStart, 1).Style.Font.Bold = true;

        ws.Cell(legendStart + 1, 1).Value = "Y";
        ws.Cell(legendStart + 1, 2).Value = "已開啟";
        ws.Cell(legendStart + 1, 1).Style.Fill.BackgroundColor = GreenBg;
        ws.Cell(legendStart + 1, 1).Style.Font.FontColor = GreenFont;

        ws.Cell(legendStart + 2, 1).Value = "N";
        ws.Cell(legendStart + 2, 2).Value = "未開啟";
        ws.Cell(legendStart + 2, 1).Style.Fill.BackgroundColor = RedBg;
        ws.Cell(legendStart + 2, 1).Style.Font.FontColor = RedFont;

        ws.Cell(legendStart + 3, 1).Value = "-";
        ws.Cell(legendStart + 3, 2).Value = "該客戶無此功能";

        ws.Cell(legendStart + 4, 1).Value = "差異";
        ws.Cell(legendStart + 4, 2).Value = "各客戶間設定不一致（黃底標記於模組/ITEM_ID/功能名稱欄）";
        ws.Cell(legendStart + 4, 1).Style.Fill.BackgroundColor = YellowBg;
        ws.Cell(legendStart + 4, 1).Style.Font.Bold = true;

        // 說明框線
        for (int r = legendStart + 1; r <= legendStart + 4; r++)
        {
            ws.Range(r, 1, r, 2).Style.Border.OutsideBorder = XLBorderStyleValues.Thin;
            ws.Cell(r, 1).Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
        }

        AutoFitColumns(ws);
    }

    // === Sheet 2: 已開啟功能 ===

    private static void WriteSheet2OpenedFeatures(IXLWorkbook wb, List<FeatureEntry> allFeatures,
        List<CustomerFeatureData> customers, List<string> codes,
        Dictionary<(string, string), string> lookup, Dictionary<string, HashSet<string>> customerItemIds)
    {
        var ws = wb.Worksheets.Add("已開啟功能");
        int colCount = 3 + codes.Count;

        WriteLegend(ws);
        ws.Cell(5, 1).Value = "※ 僅顯示 OPEN_YN = Y 的功能";
        ws.Cell(5, 1).Style.Font.Italic = true;
        WriteCrossTableHeader(ws, 6, codes);

        int row = 7;
        foreach (var f in allFeatures)
        {
            var hasY = codes.Any(code => lookup.TryGetValue((code, f.ItemId), out var v) && v == "Y");
            if (!hasY) continue;

            ws.Cell(row, 1).Value = f.SysType;
            ws.Cell(row, 2).Value = f.ItemId;
            ws.Cell(row, 3).Value = f.ItemDesc;
            for (int i = 0; i < codes.Count; i++)
            {
                var val = GetCellValue(codes[i], f.ItemId, lookup, customerItemIds);
                var displayVal = val == "Y" ? "Y" : "";
                ws.Cell(row, 4 + i).Value = displayVal;
                if (val == "Y")
                    StyleValueCell(ws.Cell(row, 4 + i), "Y");
            }
            row++;
        }

        StyleDataRange(ws, 6, row - 1, colCount);
        AddAutoFilter(ws, 6, row - 1, colCount);
        AutoFitColumns(ws);
    }

    // === Sheet 3: 全客戶共有 ===

    private static void WriteSheet3AllShared(IXLWorkbook wb, List<FeatureEntry> allFeatures,
        List<CustomerFeatureData> customers, List<string> codes,
        Dictionary<(string, string), string> lookup, Dictionary<string, HashSet<string>> customerItemIds)
    {
        var ws = wb.Worksheets.Add("全客戶共有");
        ws.Cell(1, 1).Value = "全客戶共有功能（所有客戶皆開啟 Y）";
        ws.Cell(1, 1).Style.Font.Bold = true;
        ws.Cell(1, 1).Style.Font.FontColor = XLColor.FromHtml("#44546A");

        var headers = new[] { "模組", "ITEM_ID", "功能名稱" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(2, i + 1).Value = headers[i];
        StyleHeaderRow(ws, 2, headers.Length);

        int row = 3;
        foreach (var f in allFeatures)
        {
            var allY = codes.All(code =>
                lookup.TryGetValue((code, f.ItemId), out var v) && v == "Y");
            if (!allY) continue;

            ws.Cell(row, 1).Value = f.SysType;
            ws.Cell(row, 2).Value = f.ItemId;
            ws.Cell(row, 3).Value = f.ItemDesc;
            row++;
        }

        StyleDataRange(ws, 2, row - 1, headers.Length);
        AddAutoFilter(ws, 2, row - 1, headers.Length);
        AutoFitColumns(ws);
    }

    // === Sheet 4: 各客戶已開啟 ===

    private static void WriteSheet4PerCustomerOpened(IXLWorkbook wb, List<CustomerFeatureData> customers)
    {
        var ws = wb.Worksheets.Add("各客戶已開啟");
        ws.Cell(1, 1).Value = "各客戶已開啟功能清單";
        ws.Cell(1, 1).Style.Font.Bold = true;
        ws.Cell(2, 1).Value = "每個客戶獨立列出其 OPEN_YN = Y 的功能";
        ws.Cell(2, 1).Style.Font.Italic = true;

        int row = 4;
        foreach (var c in customers)
        {
            ws.Cell(row, 1).Value = $"{c.Code}（{c.CustomerName}）";
            ws.Cell(row, 1).Style.Font.Bold = true;
            ws.Cell(row, 1).Style.Font.FontColor = XLColor.FromHtml("#44546A");
            row++;

            int headerRow = row;
            ws.Cell(row, 1).Value = "模組";
            ws.Cell(row, 2).Value = "ITEM_ID";
            ws.Cell(row, 3).Value = "功能名稱";
            StyleSubHeaderRow(ws, row, 3);
            row++;

            foreach (var f in c.Features.Where(f => f.OpenYn == "Y").OrderBy(f => f.SysType).ThenBy(f => f.ItemId))
            {
                ws.Cell(row, 1).Value = f.SysType;
                ws.Cell(row, 2).Value = f.ItemId;
                ws.Cell(row, 3).Value = f.ItemDesc;
                row++;
            }

            StyleDataRange(ws, headerRow, row - 1, 3);
            row++; // blank line
        }

        AutoFitColumns(ws);
    }

    // === Sheet 5: 差異功能 ===

    private static void WriteSheet5DiffFeatures(IXLWorkbook wb, List<FeatureEntry> allFeatures,
        List<CustomerFeatureData> customers, List<string> codes,
        Dictionary<(string, string), string> lookup, Dictionary<string, HashSet<string>> customerItemIds)
    {
        var ws = wb.Worksheets.Add("差異功能");
        int colCount = 3 + codes.Count;

        WriteLegend(ws, includeDiff: true);
        WriteCrossTableHeader(ws, 6, codes);

        int row = 7;
        foreach (var f in allFeatures)
        {
            var values = codes.Select(code => GetCellValue(code, f.ItemId, lookup, customerItemIds)).ToList();
            var distinct = values.Distinct().Count();
            if (distinct <= 1) continue;

            ws.Cell(row, 1).Value = f.SysType;
            ws.Cell(row, 2).Value = f.ItemId;
            ws.Cell(row, 3).Value = f.ItemDesc;
            // 差異行的模組/ITEM_ID/功能名稱欄黃底
            for (int col = 1; col <= 3; col++)
                ws.Cell(row, col).Style.Fill.BackgroundColor = YellowBg;

            for (int i = 0; i < codes.Count; i++)
            {
                ws.Cell(row, 4 + i).Value = values[i];
                StyleValueCell(ws.Cell(row, 4 + i), values[i]);
            }
            row++;
        }

        StyleDataRange(ws, 6, row - 1, colCount);
        AddAutoFilter(ws, 6, row - 1, colCount);
        AutoFitColumns(ws);
    }

    // === Sheet 6: 完整明細 ===

    private static void WriteSheet6FullDetail(IXLWorkbook wb, List<FeatureEntry> allFeatures,
        List<CustomerFeatureData> customers, List<string> codes,
        Dictionary<(string, string), string> lookup, Dictionary<string, HashSet<string>> customerItemIds)
    {
        var ws = wb.Worksheets.Add("完整明細");
        int colCount = 3 + codes.Count;

        WriteLegend(ws, includeDiff: true);
        WriteCrossTableHeader(ws, 6, codes);

        int row = 7;
        foreach (var f in allFeatures)
        {
            ws.Cell(row, 1).Value = f.SysType;
            ws.Cell(row, 2).Value = f.ItemId;
            ws.Cell(row, 3).Value = f.ItemDesc;

            var values = codes.Select(code => GetCellValue(code, f.ItemId, lookup, customerItemIds)).ToList();
            var isDiff = values.Distinct().Count() > 1;

            // 差異行黃底標記模組/ITEM_ID/功能名稱欄
            if (isDiff)
            {
                for (int col = 1; col <= 3; col++)
                    ws.Cell(row, col).Style.Fill.BackgroundColor = YellowBg;
            }

            for (int i = 0; i < codes.Count; i++)
            {
                ws.Cell(row, 4 + i).Value = values[i];
                StyleValueCell(ws.Cell(row, 4 + i), values[i]);
            }
            row++;
        }

        StyleDataRange(ws, 6, row - 1, colCount);
        AddAutoFilter(ws, 6, row - 1, colCount);
        AutoFitColumns(ws);
    }

    // === Sheet 7: 獨有功能 ===

    private static void WriteSheet7UniqueFeatures(IXLWorkbook wb, List<FeatureEntry> allFeatures,
        List<CustomerFeatureData> customers, Dictionary<string, HashSet<string>> customerItemIds)
    {
        var ws = wb.Worksheets.Add("獨有功能");
        var headers = new[] { "客戶", "模組", "ITEM_ID", "功能名稱" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(1, i + 1).Value = headers[i];
        StyleHeaderRow(ws, 1, headers.Length);

        int row = 2;
        foreach (var f in allFeatures)
        {
            var owners = customers.Where(c => customerItemIds[c.Code].Contains(f.ItemId)).ToList();
            if (owners.Count != 1) continue;

            ws.Cell(row, 1).Value = owners[0].Code;
            ws.Cell(row, 2).Value = f.SysType;
            ws.Cell(row, 3).Value = f.ItemId;
            ws.Cell(row, 4).Value = f.ItemDesc;
            row++;
        }

        StyleDataRange(ws, 1, row - 1, headers.Length);
        AddAutoFilter(ws, 1, row - 1, headers.Length);
        AutoFitColumns(ws);
    }

    // === Sheet 8: 樞紐分析用資料 ===

    private static void WriteSheet8PivotData(IXLWorkbook wb, List<CustomerFeatureData> customers)
    {
        var ws = wb.Worksheets.Add("樞紐分析用資料");
        ws.Cell(1, 1).Value = "此頁為扁平格式資料，可用於建立樞紐分析表（Pivot Table）自由查詢";
        ws.Cell(1, 1).Style.Font.FontColor = XLColor.FromHtml("#44546A");
        ws.Cell(2, 1).Value = "建議：選取下方資料 → 插入 → 樞紐分析表，即可自由組合篩選條件";
        ws.Cell(2, 1).Style.Font.FontColor = XLColor.FromHtml("#44546A");

        var headers = new[] { "客戶代碼", "客戶名稱", "模組", "ITEM_ID", "功能名稱", "OPEN_YN" };
        for (int i = 0; i < headers.Length; i++)
            ws.Cell(4, i + 1).Value = headers[i];
        StyleHeaderRow(ws, 4, headers.Length);

        int row = 5;
        foreach (var c in customers)
        {
            foreach (var f in c.Features.OrderBy(f => f.SysType).ThenBy(f => f.ItemId))
            {
                ws.Cell(row, 1).Value = c.Code;
                ws.Cell(row, 2).Value = c.CustomerName;
                ws.Cell(row, 3).Value = f.SysType;
                ws.Cell(row, 4).Value = f.ItemId;
                ws.Cell(row, 5).Value = f.ItemDesc;
                ws.Cell(row, 6).Value = f.OpenYn;
                StyleValueCell(ws.Cell(row, 6), f.OpenYn);
                row++;
            }
        }

        StyleDataRange(ws, 4, row - 1, headers.Length);
        AddAutoFilter(ws, 4, row - 1, headers.Length);
        AutoFitColumns(ws);
    }
}
