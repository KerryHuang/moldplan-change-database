using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SqlConnectionTester : IConnectionTester
{
    /// <summary>探測用的連線 timeout。比一般查詢的 10 秒短，因為只要判斷通不通。</summary>
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
        catch
        {
            return false;
        }
    }
}
