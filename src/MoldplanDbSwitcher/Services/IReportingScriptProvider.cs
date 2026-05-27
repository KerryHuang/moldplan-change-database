using System.Collections.Generic;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingScriptProvider
{
    ReportingScript GetScript(int fileNumber);
    string RenderJobScript(int fileNumber, string databaseName, string jobOwner);
    IReadOnlyList<ReportingScript> ListAvailable();
}
