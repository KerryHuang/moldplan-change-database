using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SqlConnectionTester : IConnectionTester
{
    /// <summary>
    /// 探測用的連線 timeout。比一般查詢的 10 秒短，因為只要判斷通不通。
    /// 注意：ADO.NET 以連線字串為 pool key，ConnectTimeout 不同即不同池，
    /// 因此預檢（5 秒）與查詢（10 秒）用的連線字串不同、不共用連線池，
    /// 預檢建立的連線不會被後續查詢重用——這是 5 秒需求的必然代價，不是錯誤。
    /// </summary>
    private const int ProbeTimeoutSeconds = 5;

    private readonly ISqlConnectionFactory _connectionFactory;

    public SqlConnectionTester(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<bool> CanConnectAsync(ConnectionProfile profile, CancellationToken ct = default)
    {
        try
        {
            await using var connection = _connectionFactory.Create(profile, ProbeTimeoutSeconds);
            await connection.OpenAsync(ct);
            return true;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            throw;
        }
        catch
        {
            return false;
        }
    }
}
