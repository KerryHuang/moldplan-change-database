namespace MoldplanDbSwitcher.Models;

public record RefreshLogEntry(
    DateTime StartTime, DateTime? EndTime, string Status, int? RowCount, string? Error);
