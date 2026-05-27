using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace MoldplanDbSwitcher.Services;

public class SqlBatchExecutor : ISqlBatchExecutor
{
    private static readonly Regex GoLineRegex = new(
        @"^\s*GO\s*(?:--.*)?$",
        RegexOptions.IgnoreCase | RegexOptions.Multiline | RegexOptions.Compiled);

    public static IReadOnlyList<string> SplitBatches(string sql)
    {
        var batches = new List<string>();
        var lines = sql.Split('\n');
        var current = new System.Text.StringBuilder();
        var inSingleQuote = false;

        foreach (var rawLine in lines)
        {
            var line = rawLine.TrimEnd('\r');
            if (!inSingleQuote && GoLineRegex.IsMatch(line))
            {
                var batch = current.ToString().Trim();
                if (batch.Length > 0) batches.Add(batch);
                current.Clear();
                continue;
            }

            foreach (var c in line)
                if (c == '\'') inSingleQuote = !inSingleQuote;

            current.AppendLine(line);
        }

        var last = current.ToString().Trim();
        if (last.Length > 0) batches.Add(last);
        return batches;
    }

    public async Task<IReadOnlyList<BatchResult>> ExecuteAsync(
        SqlConnection connection, string sql, IProgress<BatchResult>? progress = null, CancellationToken ct = default)
    {
        var batches = SplitBatches(sql);
        var results = new List<BatchResult>();
        if (connection.State != System.Data.ConnectionState.Open)
            await connection.OpenAsync(ct);

        for (var i = 0; i < batches.Count; i++)
        {
            BatchResult result;
            try
            {
                await using var cmd = connection.CreateCommand();
                cmd.CommandText = batches[i];
                cmd.CommandTimeout = 300;
                var affected = await cmd.ExecuteNonQueryAsync(ct);
                result = new BatchResult(i, true, null, affected);
            }
            catch (Exception ex)
            {
                result = new BatchResult(i, false, ex.Message, null);
            }

            results.Add(result);
            progress?.Report(result);
            if (!result.Success) break;
        }
        return results;
    }
}
