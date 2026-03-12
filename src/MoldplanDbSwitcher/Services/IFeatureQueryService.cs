using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IFeatureQueryService
{
    Task<List<FeatureEntry>> QueryFeaturesAsync(ConnectionProfile profile);
}
