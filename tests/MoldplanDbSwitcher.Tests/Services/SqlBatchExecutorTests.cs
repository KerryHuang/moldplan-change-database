using MoldplanDbSwitcher.Services;
using Xunit;

namespace MoldplanDbSwitcher.Tests.Services;

public class SqlBatchExecutorTests
{
    [Fact]
    public void SplitBatches_SimpleGoSeparated_ReturnsTwo()
    {
        const string sql = "SELECT 1;\nGO\nSELECT 2;\nGO";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
        Assert.Contains("SELECT 1", batches[0]);
        Assert.Contains("SELECT 2", batches[1]);
    }

    [Fact]
    public void SplitBatches_GoInsideString_NotSplit()
    {
        const string sql = "PRINT 'this has GO inside';\nGO\nPRINT 'second';";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
        Assert.Contains("this has GO inside", batches[0]);
    }

    [Fact]
    public void SplitBatches_GoIndented_StillSplits()
    {
        const string sql = "SELECT 1;\n  GO  \nSELECT 2;";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Equal(2, batches.Count);
    }

    [Fact]
    public void SplitBatches_EmptyBatches_Skipped()
    {
        const string sql = "GO\nGO\nSELECT 1;\nGO";
        var batches = SqlBatchExecutor.SplitBatches(sql);
        Assert.Single(batches);
    }
}
