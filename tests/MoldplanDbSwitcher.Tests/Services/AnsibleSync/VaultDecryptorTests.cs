using Xunit;
using MoldplanDbSwitcher.Services.AnsibleSync;

namespace MoldplanDbSwitcher.Tests.Services.AnsibleSync;

public class VaultDecryptorTests
{
    // 此字串由 Python 腳本產生（密碼: test-password，明文: vault_db_main_password: secret123）
    // salt 固定為 a1b2c3d4...（可重現），確保測試向量穩定
    private const string ValidVaultContent =
        "$ANSIBLE_VAULT;1.1;AES256\n" +
        "61316232633364346535663661376238633964306531663261336234633564366537663861396230\n" +
        "6331643265336634613562366337643865396630613162320a396534653039303437396434363731\n" +
        "32366566303563636537643161356132336631316662346436303537666339303032303266313837\n" +
        "6165333331666230660a643934356535366666663266373538333436383430366262353937616435\n" +
        "62353632663639336665356239336536313731666561383062383132613435306664336461613663\n" +
        "34373731623065613536643631656135656639633032613437310a\n";

    [Fact]
    public void Decrypt_ValidVault_ReturnsPlaintext()
    {
        var result = VaultDecryptor.Decrypt(ValidVaultContent, "test-password");
        Assert.Contains("vault_db_main_password: secret123", result);
    }

    [Fact]
    public void Decrypt_WrongPassword_ThrowsException()
    {
        Assert.Throws<InvalidOperationException>(
            () => VaultDecryptor.Decrypt(ValidVaultContent, "wrong-password"));
    }

    [Fact]
    public void Decrypt_InvalidHeader_ThrowsException()
    {
        Assert.Throws<InvalidOperationException>(
            () => VaultDecryptor.Decrypt("not a vault file", "password"));
    }

    [Fact(Skip = "需要 ~/.ansible-vault-pass 且在開發機上執行")]
    public void Decrypt_RealVaultFile_ReturnsKnownPassword()
    {
        var vaultPath = @"C:\Users\zihao\source\repos\deploy-ansible\ansible\customer\inventory\group_vars\customer_waydosoft01_staging\vault.yml";
        var passwordFile = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".ansible-vault-pass");

        if (!File.Exists(vaultPath) || !File.Exists(passwordFile))
            return;

        var content = File.ReadAllText(vaultPath);
        var password = File.ReadAllText(passwordFile).Trim();

        var result = VaultDecryptor.Decrypt(content, password);

        Assert.Contains("vault_db_main_password", result);
        Assert.Contains("vault_db_container_password", result);
    }
}
