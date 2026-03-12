using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class FeatureQueryService : IFeatureQueryService
{
    private readonly ISqlConnectionFactory _connectionFactory;

    public FeatureQueryService(ISqlConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<List<FeatureEntry>> QueryFeaturesAsync(ConnectionProfile profile)
    {
        const string sql = """
            SELECT SYS_TYPE, ITEM_ID, ITEM_DESC, APP_FILE, OPEN_YN
            FROM SYS013
            WHERE APP_FILE != 'XXX' AND ITEM_DESC != '-'
            ORDER BY SYS_TYPE, ITEM_ID
            """;

        var features = new List<FeatureEntry>();

        using var connection = _connectionFactory.Create(profile);
        await connection.OpenAsync();

        using var command = new SqlCommand(sql, connection);
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            features.Add(new FeatureEntry
            {
                SysType = reader.GetString(0),
                ItemId = reader.GetString(1),
                ItemDesc = reader.GetString(2),
                AppFile = reader.GetString(3),
                OpenYn = reader.GetString(4)
            });
        }

        return features;
    }
}
