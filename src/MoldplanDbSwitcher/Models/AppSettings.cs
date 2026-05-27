namespace MoldplanDbSwitcher.Models;

public class AppSettings
{
    public string AnsibleRepoPath { get; set; } = string.Empty;

    public string VaultPasswordFile { get; set; } =
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".ansible-vault-pass");

    public string DevDirectory { get; set; } = string.Empty;

    public string? MoldPlanScriptsPath { get; set; }
}
