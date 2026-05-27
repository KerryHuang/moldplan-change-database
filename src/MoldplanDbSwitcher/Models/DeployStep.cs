namespace MoldplanDbSwitcher.Models;

public enum DeployStatus { Pending, Running, Success, Failed, Skipped }

public record DeployStep(string FileName, string Description, DeployStatus Status, string? Error);
