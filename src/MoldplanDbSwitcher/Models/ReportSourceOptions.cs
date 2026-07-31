namespace MoldplanDbSwitcher.Models;

/// <summary>報表匯出的篩選條件。來源與環境為兩個獨立維度，實際範圍取交集。</summary>
public record ReportSourceOptions(
    // 來源
    bool Specurai,
    bool Custom,
    bool MoldPlanCenter,
    // 環境
    bool Development,
    bool Testing,
    bool Staging,
    bool Production)
{
    public static ReportSourceOptions AllSelected =>
        new(true, true, true, true, true, true, true);
}
