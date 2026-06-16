namespace MoldplanDbSwitcher.Models;

/// <summary>部署參數：目標報表庫名（&lt;&lt;Database&gt;&gt;）、來源主庫名（&lt;&lt;MAINDB&gt;&gt;）、Job 擁有者。</summary>
public record ReportingDeployParameters(string TargetDatabase, string SourceDatabase, string JobOwner = "sa");
