using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using System.Collections.Generic;
using System.Linq;
using NSubstitute;
using Xunit;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ReportingQueryViewModelTests
{
    private static (IReportingObjectService objects, IReportingQueryService query, ReportingQueryViewModel vm) Create()
    {
        var objects = Substitute.For<IReportingObjectService>();
        var query = Substitute.For<IReportingQueryService>();
        objects.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        objects.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
        var vm = new ReportingQueryViewModel(_ => objects, _ => query, "test");
        return (objects, query, vm);
    }

    [Fact]
    public async Task LoadObjectsAsync_PopulatesGroupedNodes()
    {
        var (objects, _, vm) = Create();
        objects.ListTablesAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "SalesOrderRowData", ReportingObjectKind.BaseTable, null),
                new("Reporting", "RefreshLog", ReportingObjectKind.SystemTable, null)
            });
        objects.ListViewsAsync(Arg.Any<CancellationToken>())
            .Returns(new List<ReportingObject> {
                new("Reporting", "SalesOrderRowDataView", ReportingObjectKind.View, null)
            });

        await vm.LoadObjectsCommand.ExecuteAsync(null);

        Assert.Equal(3, vm.Objects.Count);
        Assert.Contains(vm.Objects, o => o.Name == "SalesOrderRowData");
    }

    [Fact]
    public async Task QueryAsync_PopulatesGrid()
    {
        var (_, query, vm) = Create();
        query.QueryTopNAsync("T1", 100, Arg.Any<IEnumerable<QueryFilterRow>>(), Arg.Any<IEnumerable<QuerySortRow>>(), Arg.Any<IEnumerable<string>?>(), Arg.Any<CancellationToken>())
            .Returns(new QueryResult(new[] { "Id", "Name" },
                new List<IReadOnlyList<object?>> { new object?[] { 1, "a" } }));
        vm.SelectedObject = new ReportingObject("Reporting", "T1", ReportingObjectKind.BaseTable, null);
        vm.TopN = 100;

        await vm.QueryCommand.ExecuteAsync(null);

        Assert.Equal(2, vm.ResultColumns.Count);
        Assert.Single(vm.ResultRows);
    }

    [Fact]
    public async Task Query_PassesCheckedProjectionColumns()
    {
        var (objects, query, vm) = Create();
        objects.GetColumnsAsync("T1", Arg.Any<CancellationToken>())
            .Returns(new List<ReportingColumn>
            {
                new("c1", "int", false, null),
                new("c2", "nvarchar", true, null),
                new("c3", "datetime", true, null),
            });
        query.QueryTopNAsync("T1", Arg.Any<int>(), Arg.Any<IEnumerable<QueryFilterRow>>(), Arg.Any<IEnumerable<QuerySortRow>>(), Arg.Any<IEnumerable<string>?>(), Arg.Any<CancellationToken>())
            .Returns(new QueryResult(System.Array.Empty<string>(), System.Array.Empty<IReadOnlyList<object?>>()));

        // 設定物件會觸發背景的 LoadObjectDetailAsync（填 ProjectionColumns）與自動查詢；
        // 稍候讓背景填充完成後，再手動覆寫欄位勾選，避免背景的 Clear/Add 蓋掉我們的設定。
        vm.SelectedObject = new ReportingObject("Reporting", "T1", ReportingObjectKind.BaseTable, null);
        await Task.Delay(50);

        vm.ProjectionColumns.Clear();
        vm.ProjectionColumns.Add(new ColumnSelectionItem("c1", "int") { IsSelected = true });
        vm.ProjectionColumns.Add(new ColumnSelectionItem("c2", "nvarchar") { IsSelected = false });
        vm.ProjectionColumns.Add(new ColumnSelectionItem("c3", "datetime") { IsSelected = true });

        await vm.QueryCommand.ExecuteAsync(null);

        // 以 Received 比對「曾有一次查詢帶入 [c1,c3]」——不受背景查詢呼叫順序影響。
        await query.Received().QueryTopNAsync("T1", Arg.Any<int>(),
            Arg.Any<IEnumerable<QueryFilterRow>>(), Arg.Any<IEnumerable<QuerySortRow>>(),
            Arg.Is<IEnumerable<string>>(c => c != null && c.SequenceEqual(new[] { "c1", "c3" })),
            Arg.Any<CancellationToken>());
    }

    [Fact]
    public void ProjectionHeader_ReflectsSelectedCount()
    {
        var (_, _, vm) = Create();
        vm.RebuildProjection(new[]
        {
            new ReportingColumn("c1", "int", false, null),
            new ReportingColumn("c2", "int", false, null),
            new ReportingColumn("c3", "int", false, null),
        });
        Assert.Contains("3/3", vm.ProjectionHeader);

        vm.ProjectionColumns[1].IsSelected = false;
        Assert.Contains("2/3", vm.ProjectionHeader);

        vm.ClearAllColumnsCommand.Execute(null);
        Assert.Contains("0/3", vm.ProjectionHeader);
    }

    [Fact]
    public void DocumentType_And_Title_AreSet()
    {
        var (_, _, vm) = Create();
        Assert.Equal("ReportingQuery", vm.DocumentType);
        Assert.Equal("Reporting 查詢", vm.Title);
        Assert.True(vm.CanClose);
    }

    [Fact]
    public async Task UseConnectionAsync_SwapsServicesAndReloads()
    {
        var calls = new List<string>();
        Func<string, IReportingObjectService> oFactory = cs =>
        {
            calls.Add($"obj:{cs}");
            var s = Substitute.For<IReportingObjectService>();
            s.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            s.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            s.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            return s;
        };
        Func<string, IReportingQueryService> qFactory = _ => Substitute.For<IReportingQueryService>();
        var vm = new ReportingQueryViewModel(oFactory, qFactory, "first");

        await vm.UseConnectionAsync("second");

        Assert.Contains("obj:first", calls);
        Assert.Contains("obj:second", calls);
    }

    [Fact]
    public async Task UseConnectionAsync_ActiveConnection_DelegatesToStringOverload()
    {
        // 驗證 ActiveConnection 多載將 ConnectionString 傳給單參數字串多載，使物件工廠以新連線字串被呼叫
        var calls = new List<string>();
        Func<string, IReportingObjectService> oFactory = cs =>
        {
            calls.Add($"obj:{cs}");
            var s = Substitute.For<IReportingObjectService>();
            s.ListTablesAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            s.ListViewsAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            s.ListProceduresAsync(Arg.Any<CancellationToken>()).Returns(new List<ReportingObject>());
            return s;
        };
        Func<string, IReportingQueryService> qFactory = _ => Substitute.For<IReportingQueryService>();
        var vm = new ReportingQueryViewModel(oFactory, qFactory, "first");
        var connection = new ActiveConnection("Server=tcp:new;Database=Reporting", "Reporting", null);

        await vm.UseConnectionAsync(connection);

        Assert.Contains("obj:Server=tcp:new;Database=Reporting", calls);
    }
}
