using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;
using System.Collections.Generic;
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
