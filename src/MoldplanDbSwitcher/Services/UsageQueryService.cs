using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UsageQueryService : IUsageQueryService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public UsageQueryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<List<UsageEntry>> QueryUsageAsync(
        ConnectionProfile profile, DateTime startDate, DateTime endDate)
    {
        const string sql = """
            SELECT
                RTRIM(A.PROG_NO),
                RTRIM(D.ITEM_DESC),
                ROUND(SUM(
                    DATEDIFF(SECOND,
                        CAST(RTRIM(A.TIME1)    AS TIME),
                        CAST(RTRIM(A.TIME_OUT) AS TIME)
                    ) / 60.0
                ), 2),
                COUNT(*)
            FROM SYS030 A
            INNER JOIN SYS013 D
                ON RTRIM(A.PROG_NO) = RTRIM(D.ITEM_ID)
               AND D.DEL_MARK = 'N'
            WHERE A.DEL_MARK  = 'N'
              AND A.ON_LINE   = 'X'
              AND A.TIME_OUT  > A.TIME1
              AND A.TIME_OUT  <> ' '
              AND A.LOG_DATE1 >= @StartDate
              AND A.LOG_DATE1 <  DATEADD(DAY, 1, @EndDate)
            GROUP BY
                RTRIM(A.PROG_NO),
                RTRIM(D.ITEM_DESC)
            HAVING ROUND(SUM(DATEDIFF(SECOND,
                CAST(RTRIM(A.TIME1) AS TIME),
                CAST(RTRIM(A.TIME_OUT) AS TIME)
            ) / 60.0), 2) > 0
            ORDER BY 3 DESC
            """;

        var results = new List<UsageEntry>();

        using var connection = _connectionFactory.Create(profile);
        await connection.OpenAsync();

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@StartDate", startDate.Date);
        command.Parameters.AddWithValue("@EndDate", endDate.Date);

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new UsageEntry
            {
                ProgNo = reader.GetString(0),
                ProgName = reader.GetString(1),
                UsageMinutes = reader.GetDecimal(2),
                Count = reader.GetInt32(3)
            });
        }

        return results;
    }
}
