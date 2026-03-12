using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface ISqlConnectionFactory
{
    SqlConnection Create(ConnectionProfile profile);
}
