using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IAppSettingsService
{
    AppSettings Load();
    void Save(AppSettings settings);
}
