using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface ISettingsService
{
    List<ConnectionProfile> LoadProfiles();
    void SaveProfiles(List<ConnectionProfile> profiles);
    void AddProfile(ConnectionProfile profile);
    void UpdateProfile(ConnectionProfile profile);
    void DeleteProfile(string id);
}
