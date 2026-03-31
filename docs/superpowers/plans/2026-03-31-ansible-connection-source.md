# Ansible 連線來源 + Specurai 路徑修正 實作計畫

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正 TableSpec → Specurai 路徑，並新增第三個連線來源 Ansible，讓 MoldplanDbSwitcher 能從 deploy-ansible 專案自動讀取每家客戶的正式/測試主資料庫連線。

**Architecture:** 新增 `AppSettingsService`（儲存 ansible repo 路徑）、`VaultDecryptor`（純 .NET AES-256-CTR 解密）、`AnsibleSyncService`（解析 YAML + 解密 vault 產生 ConnectionProfile）。ViewModel 新增 `ShowAnsible`、`SyncAnsibleCommand`；UI 新增第三個 checkbox、同步按鈕與設定視窗。

**Tech Stack:** .NET 9, Avalonia 11.3, CommunityToolkit.Mvvm, xUnit, NSubstitute, YamlDotNet（新增）

---

## 檔案結構

```
新增：
  src/MoldplanDbSwitcher/Models/AppSettings.cs
  src/MoldplanDbSwitcher/Services/IAppSettingsService.cs
  src/MoldplanDbSwitcher/Services/AppSettingsService.cs
  src/MoldplanDbSwitcher/Services/AnsibleSync/VaultDecryptor.cs
  src/MoldplanDbSwitcher/Services/AnsibleSync/AnsibleInventoryParser.cs
  src/MoldplanDbSwitcher/Services/AnsibleSync/IAnsibleSyncService.cs
  src/MoldplanDbSwitcher/Services/AnsibleSync/AnsibleSyncService.cs
  src/MoldplanDbSwitcher/Views/SettingsDialog.axaml
  src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs
  tests/MoldplanDbSwitcher.Tests/Services/AppSettingsServiceTests.cs
  tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/VaultDecryptorTests.cs
  tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/AnsibleSyncServiceTests.cs

修改：
  src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj        → 加 YamlDotNet
  src/MoldplanDbSwitcher/Services/IConnectionSourceService.cs → 改名 LoadSpecuraiConnections
  src/MoldplanDbSwitcher/Services/ConnectionSourceService.cs  → 路徑改 Specurai，改名
  src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs    → ShowTableSpec→ShowSpecurai, ShowAnsible, SyncAnsibleCommand
  src/MoldplanDbSwitcher/Views/MainWindow.axaml               → 第三個 checkbox、同步按鈕、設定選單
  src/MoldplanDbSwitcher/Program.cs                          → 註冊新服務
```

---

## Task 1：修正 Specurai 路徑與名稱

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/IConnectionSourceService.cs`
- Modify: `src/MoldplanDbSwitcher/Services/ConnectionSourceService.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`

- [ ] **Step 1: 修改 IConnectionSourceService**

將 `LoadTableSpecConnections` 改名為 `LoadSpecuraiConnections`：

```csharp
// src/MoldplanDbSwitcher/Services/IConnectionSourceService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionSourceService
{
    List<ConnectionProfile> LoadSpecuraiConnections();
    List<ConnectionProfile> LoadCustomConnections();
    List<ConnectionProfile> LoadAllConnections();
}
```

- [ ] **Step 2: 修改 ConnectionSourceService**

更新預設路徑與方法名稱：

```csharp
// src/MoldplanDbSwitcher/Services/ConnectionSourceService.cs
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionSourceService : IConnectionSourceService
{
    private readonly ISettingsService _settingsService;
    private readonly string _specuraiPath;

    public ConnectionSourceService(ISettingsService settingsService)
        : this(settingsService, Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "Specurai",
            "connections.json"))
    {
    }

    public ConnectionSourceService(ISettingsService settingsService, string specuraiPath)
    {
        _settingsService = settingsService;
        _specuraiPath = specuraiPath;
    }

    public List<ConnectionProfile> LoadSpecuraiConnections()
    {
        if (!File.Exists(_specuraiPath))
            return [];

        try
        {
            var json = File.ReadAllText(_specuraiPath);
            var data = JsonSerializer.Deserialize<ConnectionsFile>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });
            if (data?.Profiles is null) return [];

            foreach (var p in data.Profiles)
                p.Source = "Specurai";

            return data.Profiles;
        }
        catch
        {
            return [];
        }
    }

    public List<ConnectionProfile> LoadCustomConnections()
    {
        var profiles = _settingsService.LoadProfiles();
        foreach (var p in profiles)
            p.Source = "Custom";
        return profiles;
    }

    public List<ConnectionProfile> LoadAllConnections()
    {
        var all = new List<ConnectionProfile>();
        all.AddRange(LoadSpecuraiConnections());
        all.AddRange(LoadCustomConnections());
        return all;
    }
}
```

- [ ] **Step 3: 修改 MainWindowViewModel**

將 `ShowTableSpec` / `_showTableSpec` 全部改為 `ShowSpecurai` / `_showSpecurai`，更新 `LoadConnections`：

```csharp
// 在 MainWindowViewModel.cs 中：
// 舊：
[ObservableProperty]
private bool _showTableSpec = true;
partial void OnShowTableSpecChanged(bool value) => LoadConnections();

// 新：
[ObservableProperty]
private bool _showSpecurai = true;
partial void OnShowSpecuraiChanged(bool value) => LoadConnections();
```

更新 `LoadConnections` 方法：

```csharp
[RelayCommand]
private void LoadConnections()
{
    var all = new List<ConnectionProfile>();
    if (ShowSpecurai)
        all.AddRange(_connectionSource.LoadSpecuraiConnections());
    if (ShowCustom)
        all.AddRange(_connectionSource.LoadCustomConnections());

    Connections = new ObservableCollection<ConnectionProfile>(all);
    SelectedConnection = Connections.FirstOrDefault();
}
```

- [ ] **Step 4: 修改 MainWindow.axaml**

將 `TableSpec` checkbox 改為 `Specurai`：

```xml
<!-- 將此行 -->
<CheckBox Content="TableSpec" IsChecked="{Binding ShowTableSpec}" />
<!-- 改為 -->
<CheckBox Content="Specurai" IsChecked="{Binding ShowSpecurai}" />
```

- [ ] **Step 5: 執行測試確認沒有 break**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```

Expected: 所有現有測試通過（若有測試使用 `LoadTableSpecConnections`，需同步更新）

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix: 修正 TableSpec → Specurai 路徑與名稱"
```

---

## Task 2：新增 YamlDotNet 套件

**Files:**
- Modify: `src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
- Modify: `tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj`

- [ ] **Step 1: 加入 YamlDotNet**

```bash
dotnet add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj package YamlDotNet
dotnet add tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj package YamlDotNet
```

- [ ] **Step 2: 確認可建置**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj tests/MoldplanDbSwitcher.Tests/MoldplanDbSwitcher.Tests.csproj
git commit -m "chore: 加入 YamlDotNet 套件"
```

---

## Task 3：AppSettings + AppSettingsService（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/AppSettings.cs`
- Create: `src/MoldplanDbSwitcher/Services/IAppSettingsService.cs`
- Create: `src/MoldplanDbSwitcher/Services/AppSettingsService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/AppSettingsServiceTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/AppSettingsServiceTests.cs
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class AppSettingsServiceTests : IDisposable
{
    private readonly string _tempDir;
    private readonly AppSettingsService _sut;

    public AppSettingsServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        Directory.CreateDirectory(_tempDir);
        _sut = new AppSettingsService(_tempDir);
    }

    public void Dispose() => Directory.Delete(_tempDir, true);

    [Fact]
    public void Load_NoFile_ReturnsDefaults()
    {
        var settings = _sut.Load();

        Assert.Equal(string.Empty, settings.AnsibleRepoPath);
        Assert.Contains(".ansible-vault-pass", settings.VaultPasswordFile);
    }

    [Fact]
    public void Save_ThenLoad_RoundTrips()
    {
        var settings = new AppSettings
        {
            AnsibleRepoPath = "/home/user/deploy-ansible",
            VaultPasswordFile = "/home/user/.my-vault-pass"
        };

        _sut.Save(settings);
        var loaded = _sut.Load();

        Assert.Equal("/home/user/deploy-ansible", loaded.AnsibleRepoPath);
        Assert.Equal("/home/user/.my-vault-pass", loaded.VaultPasswordFile);
    }

    [Fact]
    public void Save_CreatesFile_InConfigDir()
    {
        _sut.Save(new AppSettings());

        Assert.True(File.Exists(Path.Combine(_tempDir, "app-settings.json")));
    }
}
```

- [ ] **Step 2: 執行確認失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsServiceTests"
```

Expected: FAIL — `AppSettingsService` 類別不存在

- [ ] **Step 3: 建立 AppSettings 模型**

```csharp
// src/MoldplanDbSwitcher/Models/AppSettings.cs
namespace MoldplanDbSwitcher.Models;

public class AppSettings
{
    public string AnsibleRepoPath { get; set; } = string.Empty;

    public string VaultPasswordFile { get; set; } =
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".ansible-vault-pass");
}
```

- [ ] **Step 4: 建立 IAppSettingsService**

```csharp
// src/MoldplanDbSwitcher/Services/IAppSettingsService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IAppSettingsService
{
    AppSettings Load();
    void Save(AppSettings settings);
}
```

- [ ] **Step 5: 實作 AppSettingsService**

```csharp
// src/MoldplanDbSwitcher/Services/AppSettingsService.cs
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class AppSettingsService : IAppSettingsService
{
    private readonly string _filePath;

    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public AppSettingsService() : this(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "MoldplanDbSwitcher"))
    {
    }

    public AppSettingsService(string configDir)
    {
        Directory.CreateDirectory(configDir);
        _filePath = Path.Combine(configDir, "app-settings.json");
    }

    public AppSettings Load()
    {
        if (!File.Exists(_filePath))
            return new AppSettings();

        try
        {
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize<AppSettings>(json, JsonOptions) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        var json = JsonSerializer.Serialize(settings, JsonOptions);
        File.WriteAllText(_filePath, json);
    }
}
```

- [ ] **Step 6: 執行確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AppSettingsServiceTests"
```

Expected: 3 tests passed

- [ ] **Step 7: Commit**

```bash
git add src/MoldplanDbSwitcher/Models/AppSettings.cs \
        src/MoldplanDbSwitcher/Services/IAppSettingsService.cs \
        src/MoldplanDbSwitcher/Services/AppSettingsService.cs \
        tests/MoldplanDbSwitcher.Tests/Services/AppSettingsServiceTests.cs
git commit -m "feat: 新增 AppSettings / AppSettingsService"
```

---

## Task 4：VaultDecryptor（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/AnsibleSync/VaultDecryptor.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/VaultDecryptorTests.cs`

Ansible Vault 1.1 格式：AES-256-CTR + PBKDF2-SHA256（10000 次）+ HMAC-SHA256 驗證。
.NET 無內建 CTR 模式，使用 AES-ECB 手動實作 CTR（counter XOR）。

- [ ] **Step 1: 寫失敗測試**

下方測試使用一個預先產生的 vault 加密字串（用真實 ansible-vault 產生，密碼為 `test-password`，明文為 `vault_db_main_password: secret123`）：

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/VaultDecryptorTests.cs
using MoldplanDbSwitcher.Services.AnsibleSync;

namespace MoldplanDbSwitcher.Tests.Services.AnsibleSync;

public class VaultDecryptorTests
{
    // 此加密字串由 ansible-vault encrypt_string 產生
    // 密碼: test-password，明文: vault_db_main_password: secret123
    private const string ValidVaultContent = """
        $ANSIBLE_VAULT;1.1;AES256
        39653932653465623431313436353930616133396139313239383363326462633439626631363639
        6530313061313766356138663539363065363536386530310a396565323561626334303039623138
        64333265643437636533306633373039336332363834383938363932383333376361336264363430
        3861303035623330380a326637623536663665333361383663373331363563643533663363306136
        37623966393538366636633635336164333963393763363130363661363831643534343065313831
        3730376362326233626365373831326539326362316261
        """;

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
}
```

- [ ] **Step 2: 執行確認失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "VaultDecryptorTests"
```

Expected: FAIL — `VaultDecryptor` 類別不存在

- [ ] **Step 3: 實作 VaultDecryptor**

```csharp
// src/MoldplanDbSwitcher/Services/AnsibleSync/VaultDecryptor.cs
using System.Security.Cryptography;
using System.Text;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public static class VaultDecryptor
{
    private const string Header = "$ANSIBLE_VAULT;1.1;AES256";

    public static string Decrypt(string vaultContent, string password)
    {
        var lines = vaultContent.Trim().Split('\n', StringSplitOptions.TrimEntries);

        if (lines.Length < 2 || lines[0] != Header)
            throw new InvalidOperationException($"不支援的 Vault 格式：{lines[0]}");

        // 合併 hex 行並解碼
        var hexData = string.Concat(lines[1..]);
        var rawBytes = Convert.FromHexString(hexData);
        var inner = Encoding.UTF8.GetString(rawBytes);
        var parts = inner.Split('\n', StringSplitOptions.RemoveEmptyEntries);

        if (parts.Length != 3)
            throw new InvalidOperationException($"Vault 內部格式錯誤，應為 3 段，得到 {parts.Length} 段");

        var salt = Convert.FromHexString(parts[0].Trim());
        var hmacBytes = Convert.FromHexString(parts[1].Trim());
        var ciphertext = Convert.FromHexString(parts[2].Trim());

        // PBKDF2-SHA256 衍生 80 bytes：32(key) + 32(hmacKey) + 16(iv)
        var derived = Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password),
            salt,
            10000,
            HashAlgorithmName.SHA256,
            80);

        var key = derived[..32];
        var hmacKey = derived[32..64];
        var iv = derived[64..80];

        // 驗證 HMAC-SHA256
        var computedHmac = HMACSHA256.HashData(hmacKey, ciphertext);
        if (!CryptographicOperations.FixedTimeEquals(computedHmac, hmacBytes))
            throw new InvalidOperationException("HMAC 驗證失敗，密碼錯誤或資料損毀");

        // AES-256-CTR 解密（手動實作，.NET 無內建 CTR）
        var plaintext = AesCtr(key, iv, ciphertext);

        // 去除 PKCS7 padding
        var pad = plaintext[^1];
        if (pad > 0 && pad <= 16 && plaintext[^pad..].All(b => b == pad))
            plaintext = plaintext[..^pad];

        return Encoding.UTF8.GetString(plaintext);
    }

    private static byte[] AesCtr(byte[] key, byte[] iv, byte[] ciphertext)
    {
        using var aes = Aes.Create();
        aes.Key = key;
        aes.Mode = CipherMode.ECB;
        aes.Padding = PaddingMode.None;

        var result = new byte[ciphertext.Length];
        var counter = (byte[])iv.Clone();
        var keyStream = new byte[16];

        using var encryptor = aes.CreateEncryptor();

        for (int offset = 0; offset < ciphertext.Length; offset += 16)
        {
            encryptor.TransformBlock(counter, 0, 16, keyStream, 0);
            IncrementCounter(counter);

            int blockSize = Math.Min(16, ciphertext.Length - offset);
            for (int i = 0; i < blockSize; i++)
                result[offset + i] = (byte)(ciphertext[offset + i] ^ keyStream[i]);
        }

        return result;
    }

    private static void IncrementCounter(byte[] counter)
    {
        for (int i = counter.Length - 1; i >= 0; i--)
        {
            if (++counter[i] != 0) break;
        }
    }
}
```

- [ ] **Step 4: 產生真實測試用的 Vault 字串**

在 `VaultDecryptorTests.cs` 的 `ValidVaultContent` 是示意用的佔位符。執行下列指令產生真實字串，並替換到測試中：

```bash
cd /c/Users/zihao/source/repos/deploy-ansible
echo "vault_db_main_password: secret123" | uv run ansible-vault encrypt_string \
  --vault-password-file ~/.ansible-vault-pass --stdin-name dummy 2>/dev/null || \
python -c "
import subprocess, sys
result = subprocess.run(['uv', 'run', 'ansible-vault', 'encrypt',
  '--vault-password-file', '/c/Users/zihao/.ansible-vault-pass', '/dev/stdin'],
  input=b'vault_db_main_password: secret123\n', capture_output=True)
print(result.stdout.decode())
"
```

若無法在 Windows 上直接執行，改用此方式：用 Python 直接呼叫現有的解密邏輯，反向驗證（用真實 vault 檔案測試）。

**替代方案**：用真實的 `customer_waydosoft01_staging/vault.yml` 作為整合測試：

```csharp
[Fact(Skip = "需要 ~/.ansible-vault-pass 且在開發機上執行")]
public void Decrypt_RealVaultFile_ReturnsKnownPassword()
{
    var vaultPath = @"C:\Users\zihao\source\repos\deploy-ansible\ansible\customer\inventory\group_vars\customer_waydosoft01_staging\vault.yml";
    var passwordFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".ansible-vault-pass");

    if (!File.Exists(vaultPath) || !File.Exists(passwordFile))
        return; // 跳過

    var content = File.ReadAllText(vaultPath);
    var password = File.ReadAllText(passwordFile).Trim();

    var result = VaultDecryptor.Decrypt(content, password);

    Assert.Contains("vault_db_main_password", result);
    Assert.Contains("ZUjWQ7zrE8uYvXfC", result);
}
```

- [ ] **Step 5: 執行確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "VaultDecryptorTests"
```

Expected: 3 tests passed（或跳過整合測試）

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/AnsibleSync/VaultDecryptor.cs \
        tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/VaultDecryptorTests.cs
git commit -m "feat: 新增 VaultDecryptor（AES-256-CTR）"
```

---

## Task 5：AnsibleSyncService（TDD）

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/AnsibleSync/IAnsibleSyncService.cs`
- Create: `src/MoldplanDbSwitcher/Services/AnsibleSync/AnsibleSyncService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/AnsibleSyncServiceTests.cs`

- [ ] **Step 1: 寫失敗測試**

測試使用臨時目錄模擬 deploy-ansible 結構：

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/AnsibleSyncServiceTests.cs
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.Services.AnsibleSync;

namespace MoldplanDbSwitcher.Tests.Services.AnsibleSync;

public class AnsibleSyncServiceTests : IDisposable
{
    private readonly string _repoRoot;
    private readonly string _groupVarsDir;
    private readonly string _vaultPassFile;

    public AnsibleSyncServiceTests()
    {
        _repoRoot = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString());
        _groupVarsDir = Path.Combine(_repoRoot, "ansible", "customer", "inventory", "group_vars");
        Directory.CreateDirectory(_groupVarsDir);

        _vaultPassFile = Path.Combine(_repoRoot, ".vault-pass");
        File.WriteAllText(_vaultPassFile, "testpass");
    }

    public void Dispose() => Directory.Delete(_repoRoot, true);

    private void WriteFile(string relativePath, string content)
    {
        var fullPath = Path.Combine(_groupVarsDir, relativePath);
        Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);
        File.WriteAllText(fullPath, content);
    }

    [Fact]
    public async Task SyncAsync_ExternalMssql_ReturnsCorrectProfile()
    {
        // 模擬 hosts.yml
        var hostsYml = Path.Combine(_repoRoot, "ansible", "customer", "inventory", "hosts.yml");
        Directory.CreateDirectory(Path.GetDirectoryName(hostsYml)!);
        File.WriteAllText(hostsYml, """
            all:
              children:
                customer_testco:
                  hosts:
                    testco-production:
                      env: production
                    testco-staging:
                      env: staging
                  vars:
                    mssql_host: 192.168.1.100
                    tailscale_ip: 100.1.2.3
                    customer: testco
            """);

        // 模擬 customer_testco_production/database.yml
        WriteFile("customer_testco_production/database.yml", """
            main_sql_override:
              database: "testcoDB"
            """);

        // 模擬未加密的 vault（用明文 YAML 模擬，測試時 bypass 解密）
        WriteFile("customer_testco/vault.yml", """
            vault_db_main_password: prodpass123
            """);

        var settings = new AppSettings
        {
            AnsibleRepoPath = _repoRoot,
            VaultPasswordFile = _vaultPassFile
        };
        var appSettingsService = NSubstitute.Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);

        var sut = new AnsibleSyncService(appSettingsService);

        var profiles = await sut.SyncAsync();

        var prod = profiles.FirstOrDefault(p => p.Name.Contains("正式") && p.Name.Contains("Testcо"));
        Assert.NotNull(prod);
        Assert.Equal("192.168.1.100", prod.Server);
        Assert.Equal("testcoDB", prod.Database);
        Assert.Equal("mis", prod.Username);
        Assert.Equal("Ansible", prod.Source);
    }

    [Fact]
    public async Task SyncAsync_ContainerMssql_UsesTailscaleIp()
    {
        var hostsYml = Path.Combine(_repoRoot, "ansible", "customer", "inventory", "hosts.yml");
        Directory.CreateDirectory(Path.GetDirectoryName(hostsYml)!);
        File.WriteAllText(hostsYml, """
            all:
              children:
                customer_waydo:
                  hosts:
                    waydo-staging:
                      env: staging
                  vars:
                    mssql_host: container
                    tailscale_ip: 100.73.36.124
                    customer: waydo
            """);

        WriteFile("customer_waydo_staging/database.yml", """
            main_sql_override:
              database: "waydo-test"
            """);

        WriteFile("customer_waydo/vault.yml", """
            vault_db_container_password: containerPass
            """);

        var settings = new AppSettings
        {
            AnsibleRepoPath = _repoRoot,
            VaultPasswordFile = _vaultPassFile
        };
        var appSettingsService = NSubstitute.Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);

        var sut = new AnsibleSyncService(appSettingsService);
        var profiles = await sut.SyncAsync();

        var staging = profiles.FirstOrDefault(p => p.Name.Contains("測試"));
        Assert.NotNull(staging);
        Assert.Equal("100.73.36.124", staging.Server);
        Assert.Equal("SA", staging.Username);
        Assert.Equal("containerPass", staging.Password);
    }

    [Fact]
    public async Task SyncAsync_EmptyRepo_ReturnsEmpty()
    {
        var settings = new AppSettings { AnsibleRepoPath = _repoRoot };
        var appSettingsService = NSubstitute.Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);

        var sut = new AnsibleSyncService(appSettingsService);
        var profiles = await sut.SyncAsync();

        Assert.Empty(profiles);
    }

    [Fact]
    public async Task SyncAsync_RepoPathEmpty_ReturnsEmpty()
    {
        var settings = new AppSettings { AnsibleRepoPath = string.Empty };
        var appSettingsService = NSubstitute.Substitute.For<IAppSettingsService>();
        appSettingsService.Load().Returns(settings);

        var sut = new AnsibleSyncService(appSettingsService);
        var profiles = await sut.SyncAsync();

        Assert.Empty(profiles);
    }
}
```

- [ ] **Step 2: 執行確認失敗**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AnsibleSyncServiceTests"
```

Expected: FAIL — `IAnsibleSyncService` / `AnsibleSyncService` 不存在

- [ ] **Step 3: 建立 IAnsibleSyncService**

```csharp
// src/MoldplanDbSwitcher/Services/AnsibleSync/IAnsibleSyncService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public interface IAnsibleSyncService
{
    Task<List<ConnectionProfile>> SyncAsync();
}
```

- [ ] **Step 4: 實作 AnsibleSyncService**

```csharp
// src/MoldplanDbSwitcher/Services/AnsibleSync/AnsibleSyncService.cs
using System.Globalization;
using MoldplanDbSwitcher.Models;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace MoldplanDbSwitcher.Services.AnsibleSync;

public class AnsibleSyncService : IAnsibleSyncService
{
    private readonly IAppSettingsService _appSettingsService;

    private static readonly IDeserializer YamlDeserializer =
        new DeserializerBuilder()
            .WithNamingConvention(UnderscoredNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build();

    public AnsibleSyncService(IAppSettingsService appSettingsService)
    {
        _appSettingsService = appSettingsService;
    }

    public async Task<List<ConnectionProfile>> SyncAsync()
    {
        var settings = _appSettingsService.Load();
        if (string.IsNullOrWhiteSpace(settings.AnsibleRepoPath))
            return [];

        var inventoryDir = Path.Combine(
            settings.AnsibleRepoPath, "ansible", "customer", "inventory");

        if (!Directory.Exists(inventoryDir))
            return [];

        var hostsFile = Path.Combine(inventoryDir, "hosts.yml");
        if (!File.Exists(hostsFile))
            return [];

        var groupVarsDir = Path.Combine(inventoryDir, "group_vars");
        var customers = ParseCustomers(hostsFile);
        var profiles = new List<ConnectionProfile>();

        foreach (var customer in customers)
        {
            foreach (var env in customer.Environments)
            {
                var profile = await BuildProfileAsync(
                    customer, env, groupVarsDir, settings.VaultPasswordFile);
                if (profile != null)
                    profiles.Add(profile);
            }
        }

        return profiles;
    }

    private List<CustomerInfo> ParseCustomers(string hostsFile)
    {
        var content = File.ReadAllText(hostsFile);
        var root = YamlDeserializer.Deserialize<Dictionary<string, object>>(content);

        var customers = new List<CustomerInfo>();

        if (root.TryGetValue("all", out var allObj) &&
            allObj is Dictionary<object, object> all &&
            all.TryGetValue("children", out var childrenObj) &&
            childrenObj is Dictionary<object, object> children)
        {
            foreach (var (groupKey, groupVal) in children)
            {
                var groupName = groupKey.ToString()!;
                if (!groupName.StartsWith("customer_") || groupName.Count(c => c == '_') < 1)
                    continue;

                // 只取 customer_<name>（不含 _production/_staging）
                var parts = groupName["customer_".Length..].Split('_');
                if (parts.Length > 2) continue; // 跳過 customer_name_env 格式

                if (groupVal is not Dictionary<object, object> groupDict) continue;

                var vars = groupDict.TryGetValue("vars", out var v)
                    ? v as Dictionary<object, object>
                    : null;

                var mssqlHost = vars?.GetValueOrDefault("mssql_host")?.ToString() ?? string.Empty;
                var tailscaleIp = vars?.GetValueOrDefault("tailscale_ip")?.ToString() ?? string.Empty;
                var customerName = vars?.GetValueOrDefault("customer")?.ToString() ?? parts[0];

                var environments = new List<string>();
                if (groupDict.TryGetValue("hosts", out var hostsObj) &&
                    hostsObj is Dictionary<object, object> hosts)
                {
                    foreach (var (hostKey, hostVal) in hosts)
                    {
                        if (hostVal is Dictionary<object, object> hostDict &&
                            hostDict.TryGetValue("env", out var envObj))
                        {
                            environments.Add(envObj.ToString()!);
                        }
                    }
                }

                if (environments.Count == 0) continue;

                customers.Add(new CustomerInfo
                {
                    GroupName = groupName,
                    CustomerName = customerName,
                    MssqlHost = mssqlHost,
                    TailscaleIp = tailscaleIp,
                    Environments = environments.Distinct().ToList()
                });
            }
        }

        return customers;
    }

    private async Task<ConnectionProfile?> BuildProfileAsync(
        CustomerInfo customer, string env, string groupVarsDir, string vaultPasswordFile)
    {
        // 讀取 database.yml（優先 env 層，其次 customer 層）
        var envGroup = $"customer_{customer.CustomerName}_{env}";
        var dbYmlPath = Path.Combine(groupVarsDir, envGroup, "database.yml");
        string? database = null;

        if (File.Exists(dbYmlPath))
        {
            var dbYml = YamlDeserializer.Deserialize<Dictionary<string, object>>(
                File.ReadAllText(dbYmlPath));
            database = ExtractMainDatabase(dbYml);
        }

        if (string.IsNullOrEmpty(database))
            return null;

        // 合併 vault 變數：all → customer → env
        var vaultVars = await MergeVaultVarsAsync(
            customer.CustomerName, env, groupVarsDir, vaultPasswordFile);

        // 判斷連線模式
        var isContainer = customer.MssqlHost.Equals("container", StringComparison.OrdinalIgnoreCase);
        var server = isContainer ? customer.TailscaleIp : customer.MssqlHost;

        if (string.IsNullOrEmpty(server))
            return null;

        var username = isContainer ? "SA" : "mis";
        var password = isContainer
            ? GetVaultVar(vaultVars, "vault_db_container_password", "service")
            : GetVaultVar(vaultVars,
                "vault_db_main_password",
                "vault_db_admin_password",
                "vault_db_password",
                "service");

        var envLabel = env == "production" ? "正式" : "測試";
        var displayName = CultureInfo.CurrentCulture.TextInfo.ToTitleCase(customer.CustomerName);

        return new ConnectionProfile
        {
            Name = $"{displayName} - {envLabel}",
            Server = server,
            Database = database,
            AuthType = AuthenticationType.SqlServerAuthentication,
            Username = username,
            Password = password,
            Source = "Ansible"
        };
    }

    private static string? ExtractMainDatabase(Dictionary<string, object> dbYml)
    {
        if (dbYml.TryGetValue("main_sql_override", out var overrideObj) &&
            overrideObj is Dictionary<object, object> overrideDict &&
            overrideDict.TryGetValue("database", out var db))
        {
            return db?.ToString();
        }
        return null;
    }

    private async Task<Dictionary<string, string>> MergeVaultVarsAsync(
        string customerName, string env, string groupVarsDir, string vaultPasswordFile)
    {
        string? password = null;
        if (File.Exists(vaultPasswordFile))
            password = (await File.ReadAllTextAsync(vaultPasswordFile)).Trim();

        var merged = new Dictionary<string, string>();

        // 合併順序：customer → env（後蓋前）
        foreach (var group in new[]
        {
            $"customer_{customerName}",
            $"customer_{customerName}_{env}"
        })
        {
            var vaultFile = Path.Combine(groupVarsDir, group, "vault.yml");
            if (!File.Exists(vaultFile)) continue;

            try
            {
                var rawContent = await File.ReadAllTextAsync(vaultFile);
                string yamlContent;

                // 判斷是否加密
                if (rawContent.TrimStart().StartsWith("$ANSIBLE_VAULT"))
                {
                    if (password == null) continue;
                    yamlContent = VaultDecryptor.Decrypt(rawContent, password);
                }
                else
                {
                    yamlContent = rawContent;
                }

                var vars = YamlDeserializer.Deserialize<Dictionary<string, object>>(yamlContent);
                foreach (var (k, v) in vars)
                    merged[k] = v?.ToString() ?? string.Empty;
            }
            catch
            {
                // 單一 vault 解密失敗不中斷整體流程
            }
        }

        return merged;
    }

    private static string GetVaultVar(Dictionary<string, string> vars, params string[] keys)
    {
        foreach (var key in keys)
        {
            if (vars.TryGetValue(key, out var val) && !string.IsNullOrEmpty(val))
                return val;
        }
        return keys[^1]; // 最後一個 key 視為預設值
    }

    private class CustomerInfo
    {
        public string GroupName { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public string MssqlHost { get; set; } = string.Empty;
        public string TailscaleIp { get; set; } = string.Empty;
        public List<string> Environments { get; set; } = [];
    }
}
```

- [ ] **Step 5: 執行確認通過**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "AnsibleSyncServiceTests"
```

Expected: 4 tests passed

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/Services/AnsibleSync/ \
        tests/MoldplanDbSwitcher.Tests/Services/AnsibleSync/AnsibleSyncServiceTests.cs
git commit -m "feat: 新增 AnsibleSyncService（讀取 deploy-ansible 連線）"
```

---

## Task 6：設定視窗（SettingsDialog）

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml`
- Create: `src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs`

- [ ] **Step 1: 建立 SettingsDialog.axaml**

```xml
<!-- src/MoldplanDbSwitcher/Views/SettingsDialog.axaml -->
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Class="MoldplanDbSwitcher.Views.SettingsDialog"
        Title="設定"
        Width="480"
        SizeToContent="Height"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <DockPanel Margin="16">

    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal"
                HorizontalAlignment="Right" Spacing="8" Margin="0,12,0,0">
      <Button Content="儲存" Click="OnSaveClick" Classes="accent" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>

    <StackPanel Spacing="12">
      <TextBlock Text="Ansible 連線設定" FontWeight="Bold" FontSize="14" />

      <StackPanel Spacing="4">
        <TextBlock Text="deploy-ansible Repo 路徑：" />
        <DockPanel Spacing="8">
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseRepoClick" />
          <TextBox x:Name="AnsibleRepoPathBox" Watermark="例：/Users/alice/repos/deploy-ansible" />
        </DockPanel>
      </StackPanel>

      <StackPanel Spacing="4">
        <TextBlock Text="Vault 密碼檔案路徑：" />
        <DockPanel Spacing="8">
          <Button DockPanel.Dock="Right" Content="瀏覽..." Click="OnBrowseVaultPassClick" />
          <TextBox x:Name="VaultPasswordFileBox" Watermark="預設：~/.ansible-vault-pass" />
        </DockPanel>
      </StackPanel>
    </StackPanel>

  </DockPanel>
</Window>
```

- [ ] **Step 2: 建立 SettingsDialog.axaml.cs**

```csharp
// src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Views;

public partial class SettingsDialog : Window
{
    private readonly IAppSettingsService _appSettingsService;

    public SettingsDialog(IAppSettingsService appSettingsService)
    {
        InitializeComponent();
        _appSettingsService = appSettingsService;

        var settings = _appSettingsService.Load();
        AnsibleRepoPathBox.Text = settings.AnsibleRepoPath;
        VaultPasswordFileBox.Text = settings.VaultPasswordFile;
    }

    private void OnSaveClick(object? sender, RoutedEventArgs e)
    {
        _appSettingsService.Save(new AppSettings
        {
            AnsibleRepoPath = AnsibleRepoPathBox.Text ?? string.Empty,
            VaultPasswordFile = VaultPasswordFileBox.Text ?? string.Empty
        });
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();

    private async void OnBrowseRepoClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new OpenFolderDialog { Title = "選擇 deploy-ansible 目錄" };
        var result = await dialog.ShowAsync(this);
        if (!string.IsNullOrEmpty(result))
            AnsibleRepoPathBox.Text = result;
    }

    private async void OnBrowseVaultPassClick(object? sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Title = "選擇 Vault 密碼檔案",
            AllowMultiple = false
        };
        var result = await dialog.ShowAsync(this);
        if (result?.Length > 0)
            VaultPasswordFileBox.Text = result[0];
    }
}
```

- [ ] **Step 3: 確認可建置**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/SettingsDialog.axaml \
        src/MoldplanDbSwitcher/Views/SettingsDialog.axaml.cs
git commit -m "feat: 新增設定視窗（SettingsDialog）"
```

---

## Task 7：MainWindowViewModel — 新增 Ansible 支援

**Files:**
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`

- [ ] **Step 1: 更新建構式與欄位**

在 `MainWindowViewModel` 中新增：

```csharp
// 新增 field
private readonly IAnsibleSyncService _ansibleSyncService;
private List<ConnectionProfile> _ansibleConnections = [];

// 新增 ObservableProperty
[ObservableProperty]
private bool _showAnsible = true;

[ObservableProperty]
private bool _isSyncingAnsible;
```

更新建構式簽名（新增 `IAnsibleSyncService ansibleSyncService` 參數）：

```csharp
public MainWindowViewModel(
    IConnectionSourceService connectionSource,
    IServerTxtService serverTxtService,
    ISettingsService settingsService,
    IFeatureReportService featureReportService,
    IConnectionExportService connectionExportService,
    IUsageReportService usageReportService,
    IAnsibleSyncService ansibleSyncService)
{
    _connectionSource = connectionSource;
    _serverTxtService = serverTxtService;
    _settingsService = settingsService;
    _featureReportService = featureReportService;
    _connectionExportService = connectionExportService;
    _usageReportService = usageReportService;
    _ansibleSyncService = ansibleSyncService;

    LoadConnections();
    DiscoverServerTxtFiles();
}
```

- [ ] **Step 2: 新增 partial 方法與 SyncAnsibleCommand**

```csharp
partial void OnShowAnsibleChanged(bool value) => LoadConnections();

[RelayCommand]
private async Task SyncAnsible()
{
    IsSyncingAnsible = true;
    StatusMessage = "正在從 Ansible 同步連線...";
    try
    {
        _ansibleConnections = await _ansibleSyncService.SyncAsync();
        LoadConnections();
        StatusMessage = $"已同步 {_ansibleConnections.Count} 個 Ansible 連線";
    }
    catch (Exception ex)
    {
        StatusMessage = $"同步失敗：{ex.Message}";
    }
    finally
    {
        IsSyncingAnsible = false;
    }
}
```

- [ ] **Step 3: 更新 LoadConnections 加入 Ansible**

```csharp
[RelayCommand]
private void LoadConnections()
{
    var all = new List<ConnectionProfile>();
    if (ShowSpecurai)
        all.AddRange(_connectionSource.LoadSpecuraiConnections());
    if (ShowCustom)
        all.AddRange(_connectionSource.LoadCustomConnections());
    if (ShowAnsible)
        all.AddRange(_ansibleConnections);

    Connections = new ObservableCollection<ConnectionProfile>(all);
    SelectedConnection = Connections.FirstOrDefault();
}
```

- [ ] **Step 4: 更新 GetConnectionsForExport 包含 Ansible**

```csharp
public IReadOnlyList<ConnectionProfile> GetConnectionsForExport()
    => Connections
        .Where(c => c.Source is "Custom" or "Ansible")
        .ToList();
```

- [ ] **Step 5: 確認可建置**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded

- [ ] **Step 6: Commit**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs
git commit -m "feat: MainWindowViewModel 新增 Ansible 連線來源與同步命令"
```

---

## Task 8：MainWindow.axaml — UI 更新

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`

- [ ] **Step 1: 更新 MainWindow.axaml**

將連線來源區塊與功能列更新：

```xml
<!-- 頂部：連線來源篩選 -->
<StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Spacing="16" Margin="0,0,0,12">
  <TextBlock Text="連線來源：" VerticalAlignment="Center" />
  <CheckBox Content="Specurai" IsChecked="{Binding ShowSpecurai}" />
  <CheckBox Content="自訂" IsChecked="{Binding ShowCustom}" />
  <CheckBox Content="Ansible" IsChecked="{Binding ShowAnsible}" />
  <Button Content="重新整理" Command="{Binding RefreshAllCommand}" Margin="16,0,0,0" />
  <Button Content="同步 Ansible"
          Command="{Binding SyncAnsibleCommand}"
          IsEnabled="{Binding !IsSyncingAnsible}"
          Margin="0,0,0,0" />
</StackPanel>
```

在選單 `MenuItem Header="檔案(_F)"` 內新增設定項目：

```xml
<MenuItem Header="設定(_S)" Click="OnSettingsClick" />
```

- [ ] **Step 2: 更新 MainWindow.axaml.cs — 新增 OnSettingsClick**

```csharp
private async void OnSettingsClick(object? sender, RoutedEventArgs e)
{
    var dialog = new SettingsDialog(App.Services!.GetRequiredService<IAppSettingsService>());
    await dialog.ShowDialog(this);
}
```

- [ ] **Step 3: 確認可建置**

```bash
dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Views/MainWindow.axaml \
        src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs
git commit -m "feat: UI 新增 Ansible checkbox、同步按鈕、設定選單"
```

---

## Task 9：DI 註冊

**Files:**
- Modify: `src/MoldplanDbSwitcher/Program.cs`

- [ ] **Step 1: 更新 Program.cs**

```csharp
private static void ConfigureServices(IServiceCollection services)
{
    services.AddSingleton<ISettingsService, SettingsService>();
    services.AddSingleton<IAppSettingsService, AppSettingsService>();           // 新增
    services.AddSingleton<IConnectionSourceService, ConnectionSourceService>();
    services.AddSingleton<IServerTxtService, ServerTxtService>();
    services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
    services.AddSingleton<IFeatureQueryService, FeatureQueryService>();
    services.AddSingleton<IFeatureReportService, FeatureReportService>();
    services.AddSingleton<IUsageQueryService, UsageQueryService>();
    services.AddSingleton<IUsageReportService, UsageReportService>();
    services.AddSingleton<IConnectionExportService, ConnectionExportService>();
    services.AddSingleton<IAnsibleSyncService, AnsibleSyncService>();           // 新增
    services.AddTransient<MainWindowViewModel>();
}
```

在 `using` 區塊新增：

```csharp
using MoldplanDbSwitcher.Services.AnsibleSync;
```

- [ ] **Step 2: 執行完整測試**

```bash
dotnet test tests/MoldplanDbSwitcher.Tests/
```

Expected: 所有測試通過

- [ ] **Step 3: 啟動 app 確認**

```bash
dotnet run --project src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj
```

確認：
- 連線來源顯示「Specurai / 自訂 / Ansible」三個 checkbox
- 點「設定」可開啟設定視窗
- 設定 deploy-ansible 路徑後點「同步 Ansible」可載入連線

- [ ] **Step 4: Commit**

```bash
git add src/MoldplanDbSwitcher/Program.cs
git commit -m "feat: 註冊 AppSettingsService / AnsibleSyncService DI"
```

---

## 自我審查

### Spec 覆蓋確認

| 需求 | 對應 Task |
|------|-----------|
| TableSpec → Specurai 路徑修正 | Task 1 |
| YamlDotNet 套件 | Task 2 |
| AppSettings + AppSettingsService | Task 3 |
| VaultDecryptor（AES-256-CTR） | Task 4 |
| AnsibleSyncService（解析+解密+產生連線） | Task 5 |
| 設定視窗（repo 路徑、vault 密碼檔） | Task 6 |
| MainWindowViewModel Ansible 支援 | Task 7 |
| UI：第三個 checkbox、同步按鈕、設定選單 | Task 8 |
| DI 註冊 | Task 9 |
| 匯出包含 Ansible 連線 | Task 7（GetConnectionsForExport） |

### 類型一致性確認

- `IAnsibleSyncService.SyncAsync()` → `Task<List<ConnectionProfile>>`，Task 5、7 一致
- `IAppSettingsService.Load()` / `.Save()` → Task 3、6、7 一致
- `ConnectionProfile.Source = "Ansible"` → Task 5、7、ExportViewModel 一致
- `ShowSpecurai`（非 `ShowTableSpec`）→ Task 1、7、8 一致
