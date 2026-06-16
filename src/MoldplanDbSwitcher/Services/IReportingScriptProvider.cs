using System.Collections.Generic;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IReportingScriptProvider
{
    ReportingScript GetScript(int fileNumber);
    IReadOnlyList<ReportingScript> ListAvailable();
    /// <summary>渲染雙占位符；Job 檔（06/07）一併替換 @JobOwner。</summary>
    string Render(int fileNumber, ReportingDeployParameters parameters);
}
