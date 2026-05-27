namespace MoldplanDbSwitcher.Models;

public enum ReportingObjectKind { BaseTable, SummaryTable, SystemTable, View, Procedure, AgentJob }

public record ReportingObject(string Schema, string Name, ReportingObjectKind Kind, string? Description);
