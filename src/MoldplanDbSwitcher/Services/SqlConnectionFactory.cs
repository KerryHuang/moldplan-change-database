using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SqlConnectionFactory : ISqlConnectionFactory
{
    public SqlConnection Create(ConnectionProfile profile)
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = profile.Server,
            InitialCatalog = profile.Database,
            UserID = profile.Username,
            Password = profile.Password,
            TrustServerCertificate = true,
            ConnectTimeout = 10
        };

        return new SqlConnection(builder.ConnectionString);
    }
}
