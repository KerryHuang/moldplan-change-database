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
            TrustServerCertificate = true,
            ConnectTimeout = 10
        };

        if (profile.AuthType == AuthenticationType.SqlServerAuthentication)
        {
            builder.UserID = profile.Username;
            builder.Password = profile.Password;
        }
        else
        {
            builder.IntegratedSecurity = true;
        }

        return new SqlConnection(builder.ConnectionString);
    }
}
