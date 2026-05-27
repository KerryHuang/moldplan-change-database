using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IUpdateCheckService
{
    Task<UpdateInfo?> CheckAsync(string? token, CancellationToken ct = default);
}
