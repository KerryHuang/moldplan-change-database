using System.Net.Http.Headers;
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class UpdateCheckService : IUpdateCheckService
{
    private const string RepoOwner = "KerryHuang";
    private const string RepoName = "moldplan-change-database";
    private const string UserAgent = "MoldplanDbSwitcher-UpdateCheck";

    private readonly HttpClient _http;
    private readonly Version _currentVersion;

    public UpdateCheckService(HttpClient http, Version currentVersion)
    {
        _http = http;
        _currentVersion = currentVersion;
    }

    public UpdateCheckService() : this(
        new HttpClient { Timeout = TimeSpan.FromSeconds(10) },
        System.Reflection.Assembly.GetExecutingAssembly().GetName().Version ?? new Version(0, 0, 0))
    { }

    public async Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(token)) return null;
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get,
                $"https://api.github.com/repos/{RepoOwner}/{RepoName}/releases/latest");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            req.Headers.UserAgent.ParseAdd(UserAgent);
            req.Headers.Accept.ParseAdd("application/vnd.github+json");

            using var resp = await _http.SendAsync(req, ct);
            if (!resp.IsSuccessStatusCode) return null;

            var json = await resp.Content.ReadAsStringAsync(ct);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var tagName = root.TryGetProperty("tag_name", out var t) ? t.GetString() : null;
            var htmlUrl = root.TryGetProperty("html_url", out var u) ? u.GetString() : null;
            var body = root.TryGetProperty("body", out var b) ? b.GetString() ?? "" : "";

            if (string.IsNullOrEmpty(tagName) || string.IsNullOrEmpty(htmlUrl)) return null;

            var versionStr = tagName.TrimStart('v', 'V');
            if (!Version.TryParse(versionStr, out var latest)) return null;

            return latest > _currentVersion
                ? new UpdateInfo(versionStr, htmlUrl, body)
                : null;
        }
        catch { return null; }
    }
}
