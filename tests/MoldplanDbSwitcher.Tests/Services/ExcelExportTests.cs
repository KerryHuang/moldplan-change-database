using ClosedXML.Excel;
using NSubstitute;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ExcelExportTests : IDisposable
{
    private readonly string _tempDir;
    private readonly FeatureReportService _sut;

    public ExcelExportTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_tempDir);

        var connectionSource = Substitute.For<IConnectionSourceService>();
        var featureQuery = Substitute.For<IFeatureQueryService>();
        _sut = new FeatureReportService(connectionSource, featureQuery);
    }

    public void Dispose()
    {
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, true);
    }

    private FeatureReportData CreateTestData()
    {
        var data = new FeatureReportData();

        var gma = CustomerFeatureData.FromConnectionName("Gma-Staging", "gma-staging");
        gma.Features = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" },
            new() { SysType = "刀具", ItemId = "TOL040", ItemDesc = "刀具使用記錄作業", AppFile = "TOL040", OpenYn = "Y" },
            new() { SysType = "外包", ItemId = "PUR050", ItemDesc = "外包出廠作業", AppFile = "PUR050", OpenYn = "N" },
            new() { SysType = "客戶關係", ItemId = "CRM010", ItemDesc = "客戶機會資料", AppFile = "CRM010", OpenYn = "Y" }
        };

        var wd01 = CustomerFeatureData.FromConnectionName("WayDoSoft01-Test", "wd01-test");
        wd01.Features = new List<FeatureEntry>
        {
            new() { SysType = "刀具", ItemId = "TOL010", ItemDesc = "刀具基本資料作業", AppFile = "TOL010", OpenYn = "Y" },
            new() { SysType = "刀具", ItemId = "TOL040", ItemDesc = "刀具使用記錄作業", AppFile = "TOL040", OpenYn = "N" },
            new() { SysType = "外包", ItemId = "PUR050", ItemDesc = "外包出廠作業", AppFile = "PUR050", OpenYn = "Y" }
        };

        data.Customers.Add(gma);
        data.Customers.Add(wd01);
        return data;
    }

    [Fact]
    public async Task ExportToExcelAsync_Creates8Sheets()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        Assert.Equal(8, wb.Worksheets.Count);
        Assert.Equal("客戶總覽", wb.Worksheets.Worksheet(1).Name);
        Assert.Equal("已開啟功能", wb.Worksheets.Worksheet(2).Name);
        Assert.Equal("全客戶共有", wb.Worksheets.Worksheet(3).Name);
        Assert.Equal("各客戶已開啟", wb.Worksheets.Worksheet(4).Name);
        Assert.Equal("差異功能", wb.Worksheets.Worksheet(5).Name);
        Assert.Equal("完整明細", wb.Worksheets.Worksheet(6).Name);
        Assert.Equal("獨有功能", wb.Worksheets.Worksheet(7).Name);
        Assert.Equal("樞紐分析用資料", wb.Worksheets.Worksheet(8).Name);
    }

    [Fact]
    public async Task ExportToExcelAsync_Sheet1_CustomerSummary()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        var ws = wb.Worksheets.Worksheet("客戶總覽");

        // Header
        Assert.Equal("代碼", ws.Cell(1, 1).GetString());
        Assert.Equal("開啟率", ws.Cell(1, 7).GetString());

        // Gma: 4 total, 3 Y, 1 N
        Assert.Equal("Gma", ws.Cell(2, 1).GetString());
        Assert.Equal(4, ws.Cell(2, 4).GetDouble());
        Assert.Equal(3, ws.Cell(2, 5).GetDouble());
        Assert.Equal(1, ws.Cell(2, 6).GetDouble());
    }

    [Fact]
    public async Task ExportToExcelAsync_Sheet3_AllCustomersShared()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        var ws = wb.Worksheets.Worksheet("全客戶共有");

        // TOL010 is Y in both → shared. TOL040 is Y/N → not shared.
        // Header at row 2
        Assert.Equal("模組", ws.Cell(2, 1).GetString());

        // Only TOL010 should be listed
        Assert.Equal("刀具", ws.Cell(3, 1).GetString());
        Assert.Equal("TOL010", ws.Cell(3, 2).GetString());
    }

    [Fact]
    public async Task ExportToExcelAsync_Sheet7_UniqueFeatures()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        var ws = wb.Worksheets.Worksheet("獨有功能");

        // CRM010 only exists in Gma
        Assert.Equal("客戶", ws.Cell(1, 1).GetString());
        Assert.Equal("Gma", ws.Cell(2, 1).GetString());
        Assert.Equal("CRM010", ws.Cell(2, 3).GetString());
    }

    [Fact]
    public async Task ExportToExcelAsync_Sheet6_FullDetail_DashForMissing()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        var ws = wb.Worksheets.Worksheet("完整明細");

        // Find CRM010 row — Gma has it (Y), WD01 doesn't (-)
        // Header at row 6 (after 5 legend rows)
        // Search for CRM010
        var found = false;
        for (int r = 7; r <= ws.LastRowUsed()!.RowNumber(); r++)
        {
            if (ws.Cell(r, 2).GetString() == "CRM010")
            {
                Assert.Equal("Y", ws.Cell(r, 4).GetString()); // Gma
                Assert.Equal("-", ws.Cell(r, 5).GetString()); // WD01
                found = true;
                break;
            }
        }
        Assert.True(found, "CRM010 should be in 完整明細");
    }

    [Fact]
    public async Task ExportToExcelAsync_Sheet8_PivotData()
    {
        var path = Path.Combine(_tempDir, "test.xlsx");
        var data = CreateTestData();

        await _sut.ExportToExcelAsync(path, data);

        using var wb = new XLWorkbook(path);
        var ws = wb.Worksheets.Worksheet("樞紐分析用資料");

        // Header at row 4
        Assert.Equal("客戶代碼", ws.Cell(4, 1).GetString());
        Assert.Equal("OPEN_YN", ws.Cell(4, 6).GetString());

        // Total rows = Gma(4) + WD01(3) = 7 data rows
        var lastRow = ws.LastRowUsed()!.RowNumber();
        Assert.Equal(11, lastRow); // 3 header + 1 col header + 7 data
    }
}
