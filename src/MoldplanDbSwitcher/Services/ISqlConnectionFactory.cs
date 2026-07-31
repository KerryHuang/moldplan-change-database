using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface ISqlConnectionFactory
{
    /// <summary>建立連線。connectTimeoutSeconds 為 null 時使用預設的 10 秒。</summary>
    SqlConnection Create(ConnectionProfile profile, int? connectTimeoutSeconds = null);
}
