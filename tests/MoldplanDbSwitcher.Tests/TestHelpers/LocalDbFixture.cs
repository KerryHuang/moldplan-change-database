using Microsoft.Data.SqlClient;
using Xunit;

namespace MoldplanDbSwitcher.Tests.TestHelpers;

public class LocalDbFixture : IAsyncLifetime
{
    public string DatabaseName { get; } = "MoldplanTest_" + Guid.NewGuid().ToString("N").Substring(0, 8);
    public string MasterConnectionString => "Server=(localdb)\\MSSQLLocalDB;Database=master;Integrated Security=true;TrustServerCertificate=true;";
    public string ConnectionString => $"Server=(localdb)\\MSSQLLocalDB;Database={DatabaseName};Integrated Security=true;TrustServerCertificate=true;";

    public async Task InitializeAsync()
    {
        await using var conn = new SqlConnection(MasterConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = $"CREATE DATABASE [{DatabaseName}];";
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task DisposeAsync()
    {
        await using var conn = new SqlConnection(MasterConnectionString);
        await conn.OpenAsync();
        await using var cmd = conn.CreateCommand();
        cmd.CommandText = $"ALTER DATABASE [{DatabaseName}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{DatabaseName}];";
        try { await cmd.ExecuteNonQueryAsync(); } catch { /* best effort */ }
    }

    public SqlConnection CreateConnection() => new(ConnectionString);
}
