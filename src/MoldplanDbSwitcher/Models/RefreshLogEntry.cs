namespace MoldplanDbSwitcher.Models;

public record RefreshLogEntry(
    DateTime StartedAt, int DurationMs, int RowsAffected, string Status, string? ErrorMessage);
