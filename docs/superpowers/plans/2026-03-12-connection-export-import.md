# 連線設定匯出/匯入功能實作計畫

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 為 MoldplanDbSwitcher 新增與 TableSpec 格式相容的連線設定匯出/匯入功能

**Architecture:** 在現有 MVVM 架構上擴充：Model 層對齊 TableSpec 的 ConnectionProfile 結構，新增 ConnectionExportService 處理 JSON/AES 加密格式，ExportConnectionsViewModel 與 ImportConnectionsViewModel 處理 UI 邏輯，兩個新 Window 作為模態對話框。

**Tech Stack:** .NET 9, Avalonia 11.3, CommunityToolkit.Mvvm, xUnit, NSubstitute, System.Security.Cryptography (AES/PBKDF2)

---

## Chunk 1: Model 層調整

### Task 1: ConnectionProfile 新增 AuthType 與 IsDefault 欄位

**Files:**
- Modify: `src/MoldplanDbSwitcher/Models/ConnectionProfile.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs`

- [ ] **Step 1: 寫失敗測試 — AuthType 欄位存在且預設為 WindowsAuthentication**

```csharp
// tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs
// 在現有 class 中新增：

[Fact]
public void NewProfile_AuthType_DefaultsToWindowsAuthentication()
{
    var profile = new ConnectionProfile();
    Assert.Equal(AuthenticationType.WindowsAuthentication, profile.AuthType);
}

[Fact]
public void NewProfile_IsDefault_DefaultsToFalse()
{
    var profile = new ConnectionProfile();
    Assert.False(profile.IsDefault);
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProfileTests.NewProfile_AuthType_DefaultsToWindowsAuthentication"`
Expected: FAIL — `AuthenticationType` 與 `AuthType` 不存在

- [ ] **Step 3: 實作 — 新增 AuthenticationType enum 與 ConnectionProfile 新欄位**

```csharp
// src/MoldplanDbSwitcher/Models/ConnectionProfile.cs
using System.Text.Json.Serialization;

namespace MoldplanDbSwitcher.Models;

public enum AuthenticationType
{
    WindowsAuthentication = 0,
    SqlServerAuthentication = 1
}

public class ConnectionProfile
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = Guid.NewGuid().ToString();

    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("server")]
    public string Server { get; set; } = string.Empty;

    [JsonPropertyName("database")]
    public string Database { get; set; } = string.Empty;

    [JsonPropertyName("authType")]
    public AuthenticationType AuthType { get; set; } = AuthenticationType.WindowsAuthentication;

    [JsonPropertyName("username")]
    public string Username { get; set; } = string.Empty;

    [JsonPropertyName("password")]
    public string Password { get; set; } = string.Empty;

    [JsonPropertyName("isDefault")]
    public bool IsDefault { get; set; }

    [JsonIgnore]
    public string Source { get; set; } = "Custom";
}

// ConnectionsFile 不變
public class ConnectionsFile
{
    [JsonPropertyName("profiles")]
    public List<ConnectionProfile> Profiles { get; set; } = [];

    [JsonPropertyName("currentProfileId")]
    public string? CurrentProfileId { get; set; }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProfileTests"`
Expected: ALL PASS

- [ ] **Step 5: 寫失敗測試 — JSON 向下相容（缺少新欄位時使用預設值）**

```csharp
// tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs

[Fact]
public void Deserialize_MissingAuthTypeAndIsDefault_UsesDefaults()
{
    var json = """
    {
        "profiles": [
            {
                "id": "test-id",
                "name": "old-format",
                "server": "127.0.0.1",
                "database": "mis",
                "username": "",
                "password": ""
            }
        ]
    }
    """;

    var data = JsonSerializer.Deserialize<ConnectionsFile>(json);

    Assert.NotNull(data);
    Assert.Single(data.Profiles);
    Assert.Equal(AuthenticationType.WindowsAuthentication, data.Profiles[0].AuthType);
    Assert.False(data.Profiles[0].IsDefault);
}
```

- [ ] **Step 6: 執行測試確認通過**（enum 預設值 0 = WindowsAuthentication，bool 預設 false，不需額外實作）

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionProfileTests.Deserialize_MissingAuthTypeAndIsDefault_UsesDefaults"`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add src/MoldplanDbSwitcher/Models/ConnectionProfile.cs tests/MoldplanDbSwitcher.Tests/Models/ConnectionProfileTests.cs
git commit -m "feat: ConnectionProfile 新增 AuthType 與 IsDefault 欄位，對齊 TableSpec 結構"
```

### Task 2: 新增 ConnectionExportData 模型

**Files:**
- Create: `src/MoldplanDbSwitcher/Models/ConnectionExportData.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Models/ConnectionExportDataTests.cs`

- [ ] **Step 1: 寫失敗測試 — ConnectionExportData 預設值**

```csharp
// tests/MoldplanDbSwitcher.Tests/Models/ConnectionExportDataTests.cs
using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Tests.Models;

public class ConnectionExportDataTests
{
    [Fact]
    public void NewExportData_Version_DefaultsTo1()
    {
        var data = new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>()
        };
        Assert.Equal(1, data.Version);
    }

    [Fact]
    public void NewExportData_ExportedAt_DefaultsToUtcNow()
    {
        var before = DateTime.UtcNow;
        var data = new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>()
        };
        var after = DateTime.UtcNow;

        Assert.InRange(data.ExportedAt, before, after);
    }

    [Fact]
    public void Serialize_RoundTrip_PreservesData()
    {
        var original = new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "test", Server = "127.0.0.1", Database = "mis" }
            }
        };

        var json = JsonSerializer.Serialize(original);
        var restored = JsonSerializer.Deserialize<ConnectionExportData>(json);

        Assert.NotNull(restored);
        Assert.Equal(1, restored.Version);
        Assert.Single(restored.Profiles);
        Assert.Equal("test", restored.Profiles[0].Name);
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportDataTests"`
Expected: FAIL — `ConnectionExportData` 不存在

- [ ] **Step 3: 實作 ConnectionExportData**

```csharp
// src/MoldplanDbSwitcher/Models/ConnectionExportData.cs
namespace MoldplanDbSwitcher.Models;

public class ConnectionExportData
{
    public int Version { get; init; } = 1;
    public DateTime ExportedAt { get; init; } = DateTime.UtcNow;
    public List<ConnectionProfile> Profiles { get; init; } = [];
}
```

注意：使用 `List<ConnectionProfile>` 而非 `IReadOnlyList`，便於 JSON 反序列化。

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportDataTests"`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add src/MoldplanDbSwitcher/Models/ConnectionExportData.cs tests/MoldplanDbSwitcher.Tests/Models/ConnectionExportDataTests.cs
git commit -m "feat: 新增 ConnectionExportData 匯出資料模型"
```

### Task 3: 更新 SqlConnectionFactory 支援 AuthType

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs` (新建或修改)

- [ ] **Step 1: 寫失敗測試 — Windows 驗證使用 IntegratedSecurity**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class SqlConnectionFactoryTests
{
    private readonly SqlConnectionFactory _factory = new();

    [Fact]
    public void Create_WindowsAuth_UsesIntegratedSecurity()
    {
        var profile = new ConnectionProfile
        {
            Server = "127.0.0.1",
            Database = "mis",
            AuthType = AuthenticationType.WindowsAuthentication
        };

        using var conn = _factory.Create(profile);

        Assert.Contains("Integrated Security", conn.ConnectionString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("User ID", conn.ConnectionString, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Create_SqlAuth_UsesUsernamePassword()
    {
        var profile = new ConnectionProfile
        {
            Server = "127.0.0.1",
            Database = "mis",
            AuthType = AuthenticationType.SqlServerAuthentication,
            Username = "sa",
            Password = "secret"
        };

        using var conn = _factory.Create(profile);

        Assert.Contains("User ID=sa", conn.ConnectionString);
        Assert.Contains("Password=secret", conn.ConnectionString);
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlConnectionFactoryTests"`
Expected: FAIL — Windows 驗證測試失敗（目前總是設 UserID/Password）

- [ ] **Step 3: 更新 SqlConnectionFactory**

```csharp
// src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs
using Microsoft.Data.SqlClient;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class SqlConnectionFactory : ISqlConnectionFactory
{
    public SqlConnection Create(ConnectionProfile profile)
    {
        var builder = new SqlConnectionStringBuilder
        {
            DataSource = profile.Server,
            InitialCatalog = profile.Database,
            TrustServerCertificate = true,
            ConnectTimeout = 10
        };

        if (profile.AuthType == AuthenticationType.SqlServerAuthentication)
        {
            builder.UserID = profile.Username;
            builder.Password = profile.Password;
        }
        else
        {
            builder.IntegratedSecurity = true;
        }

        return new SqlConnection(builder.ConnectionString);
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "SqlConnectionFactoryTests"`
Expected: ALL PASS

- [ ] **Step 5: 執行所有測試確認無回歸**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: ALL PASS

- [ ] **Step 6: 提交**

```bash
git add src/MoldplanDbSwitcher/Services/SqlConnectionFactory.cs tests/MoldplanDbSwitcher.Tests/Services/SqlConnectionFactoryTests.cs
git commit -m "feat: SqlConnectionFactory 依 AuthType 切換 Windows/SQL 驗證"
```

---

## Chunk 2: ConnectionExportService

### Task 4: IConnectionExportService 介面與純文字匯出

**Files:**
- Create: `src/MoldplanDbSwitcher/Services/IConnectionExportService.cs`
- Create: `src/MoldplanDbSwitcher/Services/ConnectionExportService.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs`

- [ ] **Step 1: 寫失敗測試 — ExportToJson 基本功能**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs
using System.Text.Json;
using Xunit;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.Tests.Services;

public class ConnectionExportServiceTests
{
    private readonly ConnectionExportService _service = new();

    [Fact]
    public void ExportToJson_BasicProfiles_ReturnsValidJson()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
        };

        var bytes = _service.ExportToJson(profiles, includePasswords: false);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);

        Assert.NotNull(data);
        Assert.Equal(1, data.Version);
        Assert.Single(data.Profiles);
        Assert.Equal("dev", data.Profiles[0].Name);
    }

    [Fact]
    public void ExportToJson_IncludePasswordsFalse_NullsOutPasswords()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "secret" }
        };

        var bytes = _service.ExportToJson(profiles, includePasswords: false);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);

        Assert.NotNull(data);
        Assert.Null(data.Profiles[0].Password);
    }

    [Fact]
    public void ExportToJson_IncludePasswordsTrue_PreservesPasswords()
    {
        var profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "secret" }
        };

        var bytes = _service.ExportToJson(profiles, includePasswords: true);
        var data = JsonSerializer.Deserialize<ConnectionExportData>(bytes);

        Assert.NotNull(data);
        Assert.Equal("secret", data.Profiles[0].Password);
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests"`
Expected: FAIL — 類別不存在

- [ ] **Step 3: 建立介面與匯出純文字實作**

```csharp
// src/MoldplanDbSwitcher/Services/IConnectionExportService.cs
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public interface IConnectionExportService
{
    byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords);
    byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords);
    ConnectionExportData ImportFromJson(byte[] data);
    ConnectionExportData ImportFromEncryptedJson(byte[] data, string password);
    bool IsEncryptedFormat(byte[] data);
}
```

```csharp
// src/MoldplanDbSwitcher/Services/ConnectionExportService.cs
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionExportService : IConnectionExportService
{
    private static readonly byte[] MagicBytes = "TSEC"u8.ToArray();

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords)
    {
        var prepared = PrepareProfiles(profiles, includePasswords);
        var exportData = new ConnectionExportData { Profiles = prepared };
        return JsonSerializer.SerializeToUtf8Bytes(exportData, JsonOptions);
    }

    public byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords)
    {
        throw new NotImplementedException();
    }

    public ConnectionExportData ImportFromJson(byte[] data)
    {
        throw new NotImplementedException();
    }

    public ConnectionExportData ImportFromEncryptedJson(byte[] data, string password)
    {
        throw new NotImplementedException();
    }

    public bool IsEncryptedFormat(byte[] data)
    {
        throw new NotImplementedException();
    }

    private static List<ConnectionProfile> PrepareProfiles(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords)
    {
        return profiles.Select(p => new ConnectionProfile
        {
            Id = p.Id,
            Name = p.Name,
            Server = p.Server,
            Database = p.Database,
            AuthType = p.AuthType,
            Username = p.Username,
            Password = includePasswords ? p.Password : null!,
            IsDefault = p.IsDefault
        }).ToList();
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests"`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add src/MoldplanDbSwitcher/Services/IConnectionExportService.cs src/MoldplanDbSwitcher/Services/ConnectionExportService.cs tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs
git commit -m "feat: 新增 IConnectionExportService 介面與純文字 JSON 匯出"
```

### Task 5: 純文字 JSON 匯入

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/ConnectionExportService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs`

- [ ] **Step 1: 寫失敗測試 — ImportFromJson**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs 新增：

[Fact]
public void ImportFromJson_ValidData_ReturnsExportData()
{
    var profiles = new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
    };
    var bytes = _service.ExportToJson(profiles, includePasswords: true);

    var result = _service.ImportFromJson(bytes);

    Assert.Equal(1, result.Version);
    Assert.Single(result.Profiles);
    Assert.Equal("dev", result.Profiles[0].Name);
}

[Fact]
public void ImportFromJson_InvalidData_ThrowsException()
{
    var bytes = System.Text.Encoding.UTF8.GetBytes("not json");

    Assert.ThrowsAny<Exception>(() => _service.ImportFromJson(bytes));
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests.ImportFromJson"`
Expected: FAIL — NotImplementedException

- [ ] **Step 3: 實作 ImportFromJson**

```csharp
// 在 ConnectionExportService.cs 中替換 ImportFromJson：

public ConnectionExportData ImportFromJson(byte[] data)
{
    return JsonSerializer.Deserialize<ConnectionExportData>(data)
        ?? throw new InvalidOperationException("無法解析匯入資料");
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests.ImportFromJson"`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add src/MoldplanDbSwitcher/Services/ConnectionExportService.cs tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs
git commit -m "feat: 實作純文字 JSON 匯入"
```

### Task 6: IsEncryptedFormat 格式偵測

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/ConnectionExportService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs`

- [ ] **Step 1: 寫失敗測試**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs 新增：

[Fact]
public void IsEncryptedFormat_WithMagicBytes_ReturnsTrue()
{
    var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0, 0, 0, 0 };
    Assert.True(_service.IsEncryptedFormat(data));
}

[Fact]
public void IsEncryptedFormat_WithJsonData_ReturnsFalse()
{
    var data = System.Text.Encoding.UTF8.GetBytes("{\"Version\":1}");
    Assert.False(_service.IsEncryptedFormat(data));
}

[Fact]
public void IsEncryptedFormat_TooShort_ReturnsFalse()
{
    var data = new byte[] { (byte)'T', (byte)'S' };
    Assert.False(_service.IsEncryptedFormat(data));
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests.IsEncryptedFormat"`
Expected: FAIL — NotImplementedException

- [ ] **Step 3: 實作 IsEncryptedFormat**

```csharp
// 在 ConnectionExportService.cs 中替換 IsEncryptedFormat：

public bool IsEncryptedFormat(byte[] data)
{
    if (data.Length < MagicBytes.Length)
        return false;
    return data.AsSpan(0, MagicBytes.Length).SequenceEqual(MagicBytes);
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests.IsEncryptedFormat"`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add src/MoldplanDbSwitcher/Services/ConnectionExportService.cs tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs
git commit -m "feat: 實作 IsEncryptedFormat 格式偵測"
```

### Task 7: AES 加密匯出與匯入

**Files:**
- Modify: `src/MoldplanDbSwitcher/Services/ConnectionExportService.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs`

- [ ] **Step 1: 寫失敗測試 — 加密匯出再匯入還原**

```csharp
// tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs 新增：

[Fact]
public void ExportToEncryptedJson_ThenImport_RoundTripsCorrectly()
{
    var profiles = new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "dbpass" }
    };

    var encrypted = _service.ExportToEncryptedJson(profiles, "mypassword", includePasswords: true);
    var result = _service.ImportFromEncryptedJson(encrypted, "mypassword");

    Assert.Single(result.Profiles);
    Assert.Equal("dev", result.Profiles[0].Name);
    Assert.Equal("dbpass", result.Profiles[0].Password);
}

[Fact]
public void ExportToEncryptedJson_HasMagicBytes()
{
    var profiles = new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
    };

    var encrypted = _service.ExportToEncryptedJson(profiles, "password", includePasswords: true);

    Assert.True(_service.IsEncryptedFormat(encrypted));
}

[Fact]
public void ImportFromEncryptedJson_WrongPassword_ThrowsException()
{
    var profiles = new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis" }
    };

    var encrypted = _service.ExportToEncryptedJson(profiles, "correct", includePasswords: true);

    Assert.ThrowsAny<Exception>(() => _service.ImportFromEncryptedJson(encrypted, "wrong"));
}

[Fact]
public void ExportToEncryptedJson_IncludePasswordsFalse_NullsOutPasswords()
{
    var profiles = new List<ConnectionProfile>
    {
        new() { Name = "dev", Server = "127.0.0.1", Database = "mis", Password = "secret" }
    };

    var encrypted = _service.ExportToEncryptedJson(profiles, "password", includePasswords: false);
    var result = _service.ImportFromEncryptedJson(encrypted, "password");

    Assert.Null(result.Profiles[0].Password);
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests.ExportToEncryptedJson"`
Expected: FAIL — NotImplementedException

- [ ] **Step 3: 實作加密匯出與匯入**

```csharp
// 在 ConnectionExportService.cs 中替換加密相關方法：

using System.Security.Cryptography;

// 在 class 頂部新增常數：
private const int SaltSize = 16;
private const int IvSize = 16;
private const int KeySize = 32; // AES-256
private const int Iterations = 100_000;

public byte[] ExportToEncryptedJson(IReadOnlyList<ConnectionProfile> profiles, string password, bool includePasswords)
{
    var prepared = PrepareProfiles(profiles, includePasswords);
    var exportData = new ConnectionExportData { Profiles = prepared };
    var jsonBytes = JsonSerializer.SerializeToUtf8Bytes(exportData, JsonOptions);

    var salt = RandomNumberGenerator.GetBytes(SaltSize);
    var iv = RandomNumberGenerator.GetBytes(IvSize);
    var key = DeriveKey(password, salt);

    using var aes = Aes.Create();
    aes.Key = key;
    aes.IV = iv;
    aes.Mode = CipherMode.CBC;
    aes.Padding = PaddingMode.PKCS7;

    using var encryptor = aes.CreateEncryptor();
    var encrypted = encryptor.TransformFinalBlock(jsonBytes, 0, jsonBytes.Length);

    // [TSEC][Salt][IV][Encrypted]
    var result = new byte[MagicBytes.Length + SaltSize + IvSize + encrypted.Length];
    MagicBytes.CopyTo(result, 0);
    salt.CopyTo(result, MagicBytes.Length);
    iv.CopyTo(result, MagicBytes.Length + SaltSize);
    encrypted.CopyTo(result, MagicBytes.Length + SaltSize + IvSize);

    return result;
}

public ConnectionExportData ImportFromEncryptedJson(byte[] data, string password)
{
    var headerSize = MagicBytes.Length + SaltSize + IvSize;
    if (data.Length < headerSize)
        throw new InvalidOperationException("加密檔案格式不正確");

    var salt = data.AsSpan(MagicBytes.Length, SaltSize).ToArray();
    var iv = data.AsSpan(MagicBytes.Length + SaltSize, IvSize).ToArray();
    var encrypted = data.AsSpan(headerSize).ToArray();
    var key = DeriveKey(password, salt);

    using var aes = Aes.Create();
    aes.Key = key;
    aes.IV = iv;
    aes.Mode = CipherMode.CBC;
    aes.Padding = PaddingMode.PKCS7;

    try
    {
        using var decryptor = aes.CreateDecryptor();
        var jsonBytes = decryptor.TransformFinalBlock(encrypted, 0, encrypted.Length);
        return JsonSerializer.Deserialize<ConnectionExportData>(jsonBytes)
            ?? throw new InvalidOperationException("無法解析匯入資料");
    }
    catch (CryptographicException)
    {
        throw new InvalidOperationException("密碼不正確，請重新輸入");
    }
}

private static byte[] DeriveKey(string password, byte[] salt)
{
    using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256);
    return pbkdf2.GetBytes(KeySize);
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ConnectionExportServiceTests"`
Expected: ALL PASS

- [ ] **Step 5: 執行所有測試確認無回歸**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: ALL PASS

- [ ] **Step 6: 提交**

```bash
git add src/MoldplanDbSwitcher/Services/ConnectionExportService.cs tests/MoldplanDbSwitcher.Tests/Services/ConnectionExportServiceTests.cs
git commit -m "feat: 實作 AES-256-CBC 加密匯出與匯入，與 TableSpec 格式相容"
```

---

## Chunk 3: ViewModel 層

### Task 8: ExportConnectionsViewModel

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ExportConnectionsViewModel.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/ViewModels/ExportConnectionsViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試 — 基本初始化與選擇邏輯**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/ExportConnectionsViewModelTests.cs
using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ExportConnectionsViewModelTests
{
    private readonly IConnectionExportService _exportService;
    private readonly List<ConnectionProfile> _profiles;

    public ExportConnectionsViewModelTests()
    {
        _exportService = Substitute.For<IConnectionExportService>();
        _profiles = new List<ConnectionProfile>
        {
            new() { Name = "dev", Server = "127.0.0.1", Database = "mis" },
            new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
        };
    }

    private ExportConnectionsViewModel CreateVm() => new(_profiles, _exportService);

    [Fact]
    public void Constructor_LoadsAllProfileSelections()
    {
        var vm = CreateVm();
        Assert.Equal(2, vm.ProfileSelections.Count);
        Assert.Equal("dev", vm.ProfileSelections[0].Profile.Name);
    }

    [Fact]
    public void SelectAll_SelectsAllProfiles()
    {
        var vm = CreateVm();
        foreach (var p in vm.ProfileSelections) p.IsSelected = false;

        vm.SelectAllCommand.Execute(null);

        Assert.All(vm.ProfileSelections, p => Assert.True(p.IsSelected));
    }

    [Fact]
    public void DeselectAll_DeselectsAllProfiles()
    {
        var vm = CreateVm();
        foreach (var p in vm.ProfileSelections) p.IsSelected = true;

        vm.DeselectAllCommand.Execute(null);

        Assert.All(vm.ProfileSelections, p => Assert.False(p.IsSelected));
    }

    [Fact]
    public void UseEncryption_True_SetsIncludePasswordsTrue()
    {
        var vm = CreateVm();
        vm.UseEncryption = true;
        Assert.True(vm.IncludePasswords);
    }

    [Fact]
    public void UseEncryption_False_SetsIncludePasswordsFalse()
    {
        var vm = CreateVm();
        vm.UseEncryption = true;
        vm.UseEncryption = false;
        Assert.False(vm.IncludePasswords);
    }

    [Fact]
    public void GetExportData_PlainText_CallsExportToJson()
    {
        _exportService.ExportToJson(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<bool>())
            .Returns(new byte[] { 1, 2, 3 });

        var vm = CreateVm();
        vm.ProfileSelections[0].IsSelected = true;
        vm.ProfileSelections[1].IsSelected = false;
        vm.UseEncryption = false;

        var result = vm.GetExportData();

        Assert.Equal(new byte[] { 1, 2, 3 }, result);
        _exportService.Received(1).ExportToJson(
            Arg.Is<IReadOnlyList<ConnectionProfile>>(list => list.Count == 1 && list[0].Name == "dev"),
            Arg.Any<bool>());
    }

    [Fact]
    public void GetExportData_Encrypted_CallsExportToEncryptedJson()
    {
        _exportService.ExportToEncryptedJson(Arg.Any<IReadOnlyList<ConnectionProfile>>(), Arg.Any<string>(), Arg.Any<bool>())
            .Returns(new byte[] { 4, 5, 6 });

        var vm = CreateVm();
        vm.ProfileSelections[0].IsSelected = true;
        vm.UseEncryption = true;
        vm.EncryptionPassword = "pass";

        var result = vm.GetExportData();

        Assert.Equal(new byte[] { 4, 5, 6 }, result);
        _exportService.Received(1).ExportToEncryptedJson(
            Arg.Any<IReadOnlyList<ConnectionProfile>>(), "pass", true);
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ExportConnectionsViewModelTests"`
Expected: FAIL — ExportConnectionsViewModel 不存在

- [ ] **Step 3: 實作 ExportConnectionsViewModel**

```csharp
// src/MoldplanDbSwitcher/ViewModels/ExportConnectionsViewModel.cs
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public partial class ProfileSelectionItem : ObservableObject
{
    public ConnectionProfile Profile { get; }

    [ObservableProperty]
    private bool _isSelected;

    public ProfileSelectionItem(ConnectionProfile profile)
    {
        Profile = profile;
    }
}

public partial class ExportConnectionsViewModel : ObservableObject
{
    private readonly IConnectionExportService _exportService;

    [ObservableProperty]
    private bool _useEncryption;

    [ObservableProperty]
    private bool _includePasswords;

    [ObservableProperty]
    private string _encryptionPassword = string.Empty;

    [ObservableProperty]
    private string _confirmPassword = string.Empty;

    public ObservableCollection<ProfileSelectionItem> ProfileSelections { get; }

    public string DefaultExtension => UseEncryption ? ".tsjson" : ".json";

    public ExportConnectionsViewModel(IReadOnlyList<ConnectionProfile> profiles, IConnectionExportService exportService)
    {
        _exportService = exportService;
        ProfileSelections = new ObservableCollection<ProfileSelectionItem>(
            profiles.Select(p => new ProfileSelectionItem(p)));
    }

    partial void OnUseEncryptionChanged(bool value)
    {
        IncludePasswords = value;
        OnPropertyChanged(nameof(DefaultExtension));
    }

    [RelayCommand]
    private void SelectAll()
    {
        foreach (var item in ProfileSelections)
            item.IsSelected = true;
    }

    [RelayCommand]
    private void DeselectAll()
    {
        foreach (var item in ProfileSelections)
            item.IsSelected = false;
    }

    public byte[] GetExportData()
    {
        var selected = ProfileSelections
            .Where(p => p.IsSelected)
            .Select(p => p.Profile)
            .ToList();

        if (UseEncryption)
            return _exportService.ExportToEncryptedJson(selected, EncryptionPassword, IncludePasswords);

        return _exportService.ExportToJson(selected, IncludePasswords);
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ExportConnectionsViewModelTests"`
Expected: ALL PASS

- [ ] **Step 5: 提交**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ExportConnectionsViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ExportConnectionsViewModelTests.cs
git commit -m "feat: 新增 ExportConnectionsViewModel 匯出對話框邏輯"
```

### Task 9: ImportConnectionsViewModel

**Files:**
- Create: `src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs`
- Create: `tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試 — 格式偵測與預覽載入**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs
using Xunit;
using NSubstitute;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Tests.ViewModels;

public class ImportConnectionsViewModelTests
{
    private readonly IConnectionExportService _exportService;
    private readonly ISettingsService _settingsService;
    private readonly List<ConnectionProfile> _existingProfiles;

    public ImportConnectionsViewModelTests()
    {
        _exportService = Substitute.For<IConnectionExportService>();
        _settingsService = Substitute.For<ISettingsService>();
        _existingProfiles = new List<ConnectionProfile>
        {
            new() { Id = "1", Name = "dev", Server = "127.0.0.1", Database = "mis" }
        };
        _settingsService.LoadProfiles().Returns(_existingProfiles);
    }

    private ImportConnectionsViewModel CreateVm() => new(_exportService, _settingsService, _existingProfiles);

    [Fact]
    public void LoadImportData_PlainText_SetsNeedsPasswordFalse()
    {
        var data = new byte[] { 1, 2, 3 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);

        Assert.False(vm.NeedsPassword);
        Assert.Single(vm.ImportPreviews);
    }

    [Fact]
    public void LoadImportData_Encrypted_SetsNeedsPasswordTrue()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);

        var vm = CreateVm();
        vm.LoadImportData(data);

        Assert.True(vm.NeedsPassword);
        Assert.Empty(vm.ImportPreviews);
    }

    [Fact]
    public void LoadImportData_ConflictDetection_MatchesByNameIgnoreCase()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "DEV", Server = "new-server", Database = "newdb" },
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);

        Assert.Equal(2, vm.ImportPreviews.Count);
        Assert.True(vm.ImportPreviews[0].HasConflict);   // "DEV" conflicts with "dev"
        Assert.False(vm.ImportPreviews[1].HasConflict);  // "staging" is new
    }

    [Fact]
    public void DecryptAndLoad_Success_PopulatesPreviews()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);
        _exportService.ImportFromEncryptedJson(data, "pass").Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.DecryptPassword = "pass";
        vm.DecryptAndLoad();

        Assert.False(vm.NeedsPassword);
        Assert.Single(vm.ImportPreviews);
        Assert.Empty(vm.ErrorMessage);
    }

    [Fact]
    public void DecryptAndLoad_WrongPassword_SetsErrorMessage()
    {
        var data = new byte[] { (byte)'T', (byte)'S', (byte)'E', (byte)'C', 0 };
        _exportService.IsEncryptedFormat(data).Returns(true);
        _exportService.ImportFromEncryptedJson(data, "wrong")
            .Returns(x => throw new InvalidOperationException("密碼不正確"));

        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.DecryptPassword = "wrong";
        vm.DecryptAndLoad();

        Assert.True(vm.NeedsPassword);
        Assert.Contains("密碼不正確", vm.ErrorMessage);
    }

    [Fact]
    public void OverwriteAll_SetsAllConflictsToOverwrite()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new", Database = "new" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.OverwriteAllCommand.Execute(null);

        Assert.All(vm.ImportPreviews.Where(p => p.HasConflict),
            p => Assert.Equal(ConflictAction.Overwrite, p.ConflictAction));
    }

    [Fact]
    public void SkipAll_SetsAllConflictsToSkip()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new", Database = "new" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.SkipAllCommand.Execute(null);

        Assert.All(vm.ImportPreviews.Where(p => p.HasConflict),
            p => Assert.Equal(ConflictAction.Skip, p.ConflictAction));
    }

    [Fact]
    public void ExecuteImport_AddsNewAndHandlesConflicts()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new-server", Database = "newdb" },
                new() { Name = "staging", Server = "10.0.0.1", Database = "staging" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);

        // "dev" 衝突 → 覆蓋, "staging" 新增
        vm.ImportPreviews[0].ConflictAction = ConflictAction.Overwrite;

        var result = vm.ExecuteImport();

        Assert.Equal(1, result.Added);
        Assert.Equal(1, result.Overwritten);
        Assert.Equal(0, result.Skipped);
        _settingsService.Received(1).AddProfile(Arg.Is<ConnectionProfile>(p => p.Name == "staging"));
        _settingsService.Received(1).UpdateProfile(Arg.Is<ConnectionProfile>(p => p.Name == "dev"));
    }

    [Fact]
    public void ExecuteImport_SkipConflict_DoesNotUpdate()
    {
        var data = new byte[] { 1 };
        _exportService.IsEncryptedFormat(data).Returns(false);
        _exportService.ImportFromJson(data).Returns(new ConnectionExportData
        {
            Profiles = new List<ConnectionProfile>
            {
                new() { Name = "dev", Server = "new-server", Database = "newdb" }
            }
        });

        var vm = CreateVm();
        vm.LoadImportData(data);
        vm.ImportPreviews[0].ConflictAction = ConflictAction.Skip;

        var result = vm.ExecuteImport();

        Assert.Equal(0, result.Added);
        Assert.Equal(0, result.Overwritten);
        Assert.Equal(1, result.Skipped);
        _settingsService.DidNotReceive().UpdateProfile(Arg.Any<ConnectionProfile>());
    }
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ImportConnectionsViewModelTests"`
Expected: FAIL — ImportConnectionsViewModel 不存在

- [ ] **Step 3: 實作 ImportConnectionsViewModel**

```csharp
// src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MoldplanDbSwitcher.Models;
using MoldplanDbSwitcher.Services;

namespace MoldplanDbSwitcher.ViewModels;

public enum ConflictAction { Overwrite, Skip }

public class ImportResult
{
    public int Added { get; init; }
    public int Skipped { get; init; }
    public int Overwritten { get; init; }
}

public partial class ImportPreviewItem : ObservableObject
{
    public ConnectionProfile Profile { get; }
    public bool HasConflict { get; }
    public ConnectionProfile? ExistingProfile { get; }

    [ObservableProperty]
    private ConflictAction _conflictAction = ConflictAction.Skip;

    public ImportPreviewItem(ConnectionProfile profile, bool hasConflict, ConnectionProfile? existingProfile)
    {
        Profile = profile;
        HasConflict = hasConflict;
        ExistingProfile = existingProfile;
    }
}

public partial class ImportConnectionsViewModel : ObservableObject
{
    private readonly IConnectionExportService _exportService;
    private readonly ISettingsService _settingsService;
    private readonly IReadOnlyList<ConnectionProfile> _existingProfiles;
    private byte[] _rawData = [];

    [ObservableProperty]
    private bool _needsPassword;

    [ObservableProperty]
    private string _decryptPassword = string.Empty;

    [ObservableProperty]
    private string _errorMessage = string.Empty;

    public ObservableCollection<ImportPreviewItem> ImportPreviews { get; } = [];

    public ImportConnectionsViewModel(
        IConnectionExportService exportService,
        ISettingsService settingsService,
        IReadOnlyList<ConnectionProfile> existingProfiles)
    {
        _exportService = exportService;
        _settingsService = settingsService;
        _existingProfiles = existingProfiles;
    }

    public void LoadImportData(byte[] data)
    {
        _rawData = data;

        if (_exportService.IsEncryptedFormat(data))
        {
            NeedsPassword = true;
            return;
        }

        var exportData = _exportService.ImportFromJson(data);
        PopulatePreviews(exportData);
    }

    public void DecryptAndLoad()
    {
        try
        {
            var exportData = _exportService.ImportFromEncryptedJson(_rawData, DecryptPassword);
            ErrorMessage = string.Empty;
            NeedsPassword = false;
            PopulatePreviews(exportData);
        }
        catch (Exception ex)
        {
            ErrorMessage = ex.Message;
        }
    }

    private void PopulatePreviews(ConnectionExportData exportData)
    {
        ImportPreviews.Clear();
        foreach (var profile in exportData.Profiles)
        {
            var existing = _existingProfiles.FirstOrDefault(
                p => string.Equals(p.Name, profile.Name, StringComparison.OrdinalIgnoreCase));
            ImportPreviews.Add(new ImportPreviewItem(profile, existing is not null, existing));
        }
    }

    [RelayCommand]
    private void OverwriteAll()
    {
        foreach (var item in ImportPreviews.Where(p => p.HasConflict))
            item.ConflictAction = ConflictAction.Overwrite;
    }

    [RelayCommand]
    private void SkipAll()
    {
        foreach (var item in ImportPreviews.Where(p => p.HasConflict))
            item.ConflictAction = ConflictAction.Skip;
    }

    public ImportResult ExecuteImport()
    {
        var added = 0;
        var skipped = 0;
        var overwritten = 0;

        foreach (var item in ImportPreviews)
        {
            if (item.HasConflict)
            {
                if (item.ConflictAction == ConflictAction.Skip)
                {
                    skipped++;
                    continue;
                }

                // Overwrite: 使用現有的 Id
                item.Profile.Id = item.ExistingProfile!.Id;
                _settingsService.UpdateProfile(item.Profile);
                overwritten++;
            }
            else
            {
                _settingsService.AddProfile(item.Profile);
                added++;
            }
        }

        return new ImportResult { Added = added, Skipped = skipped, Overwritten = overwritten };
    }
}
```

- [ ] **Step 4: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "ImportConnectionsViewModelTests"`
Expected: ALL PASS

- [ ] **Step 5: 執行所有測試確認無回歸**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: ALL PASS

- [ ] **Step 6: 提交**

```bash
git add src/MoldplanDbSwitcher/ViewModels/ImportConnectionsViewModel.cs tests/MoldplanDbSwitcher.Tests/ViewModels/ImportConnectionsViewModelTests.cs
git commit -m "feat: 新增 ImportConnectionsViewModel 匯入對話框邏輯"
```

---

## Chunk 4: View 層與整合

### Task 10: ExportConnectionsWindow

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml.cs`

注意：View 層不做 TDD（Avalonia UI 需要跑真實視窗），直接實作。

- [ ] **Step 1: 建立 ExportConnectionsWindow AXAML**

```xml
<!-- src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml -->
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.ExportConnectionsWindow"
        x:DataType="vm:ExportConnectionsViewModel"
        Title="匯出連線設定"
        Width="480" Height="520"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <DockPanel Margin="16">

    <!-- 底部按鈕 -->
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal"
                HorizontalAlignment="Right" Spacing="8" Margin="0,12,0,0">
      <Button Content="匯出" Click="OnExportClick" Classes="accent" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>

    <StackPanel Spacing="12">

      <!-- 標題與全選按鈕 -->
      <TextBlock Text="選擇要匯出的連線" FontWeight="Bold" FontSize="14" />
      <StackPanel Orientation="Horizontal" Spacing="8">
        <Button Content="全選" Command="{Binding SelectAllCommand}" />
        <Button Content="取消全選" Command="{Binding DeselectAllCommand}" />
      </StackPanel>

      <!-- 連線清單 -->
      <Border BorderBrush="Gray" BorderThickness="1" CornerRadius="4"
              MaxHeight="200" Padding="4">
        <ScrollViewer>
          <ItemsControl ItemsSource="{Binding ProfileSelections}">
            <ItemsControl.ItemTemplate>
              <DataTemplate x:DataType="vm:ProfileSelectionItem">
                <CheckBox IsChecked="{Binding IsSelected}" Margin="2">
                  <StackPanel Orientation="Horizontal" Spacing="8">
                    <TextBlock Text="{Binding Profile.Name}" FontWeight="SemiBold" />
                    <TextBlock Text="{Binding Profile.Server}" Foreground="Gray" />
                  </StackPanel>
                </CheckBox>
              </DataTemplate>
            </ItemsControl.ItemTemplate>
          </ItemsControl>
        </ScrollViewer>
      </Border>

      <Separator />

      <!-- 匯出格式 -->
      <TextBlock Text="匯出格式" FontWeight="Bold" />
      <StackPanel Spacing="4">
        <RadioButton Content="純文字 JSON (.json)"
                     IsChecked="{Binding !UseEncryption}" GroupName="Format" />
        <RadioButton Content="加密 JSON (.tsjson)"
                     IsChecked="{Binding UseEncryption}" GroupName="Format" />
      </StackPanel>

      <!-- 包含密碼 -->
      <CheckBox Content="包含密碼" IsChecked="{Binding IncludePasswords}" />

      <!-- 加密密碼（條件顯示） -->
      <StackPanel Spacing="8" IsVisible="{Binding UseEncryption}">
        <TextBox Watermark="加密密碼" PasswordChar="●"
                 Text="{Binding EncryptionPassword}" />
        <TextBox Watermark="確認密碼" PasswordChar="●"
                 Text="{Binding ConfirmPassword}" />
      </StackPanel>

    </StackPanel>
  </DockPanel>
</Window>
```

- [ ] **Step 2: 建立 ExportConnectionsWindow code-behind**

```csharp
// src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml.cs
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ExportConnectionsWindow : Window
{
    public ExportConnectionsWindow()
    {
        InitializeComponent();
    }

    private async void OnExportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is not ExportConnectionsViewModel vm) return;

        // 驗證至少選擇一個連線
        if (vm.ProfileSelections.All(p => !p.IsSelected)) return;

        // 驗證加密密碼
        if (vm.UseEncryption)
        {
            if (string.IsNullOrEmpty(vm.EncryptionPassword)) return;
            if (vm.EncryptionPassword != vm.ConfirmPassword) return;
        }

        // 儲存檔案對話框
        var extension = vm.UseEncryption ? "tsjson" : "json";
        var typeName = vm.UseEncryption ? "加密 JSON 檔案" : "JSON 檔案";
        var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            Title = "匯出連線設定",
            DefaultExtension = extension,
            FileTypeChoices = new[]
            {
                new FilePickerFileType(typeName) { Patterns = new[] { $"*.{extension}" } }
            },
            SuggestedFileName = "connections"
        });

        if (file is null) return;

        var data = vm.GetExportData();
        await using var stream = await file.OpenWriteAsync();
        await stream.WriteAsync(data);
        Close();
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
```

- [ ] **Step 3: 提交**

```bash
git add src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml src/MoldplanDbSwitcher/Views/ExportConnectionsWindow.axaml.cs
git commit -m "feat: 新增 ExportConnectionsWindow 匯出對話框 UI"
```

### Task 11: ImportConnectionsWindow

**Files:**
- Create: `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml`
- Create: `src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml.cs`

- [ ] **Step 1: 建立 ImportConnectionsWindow AXAML**

```xml
<!-- src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml -->
<Window xmlns="https://github.com/avaloniaui"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:vm="using:MoldplanDbSwitcher.ViewModels"
        x:Class="MoldplanDbSwitcher.Views.ImportConnectionsWindow"
        x:DataType="vm:ImportConnectionsViewModel"
        Title="匯入連線設定"
        Width="500" Height="480"
        WindowStartupLocation="CenterOwner"
        CanResize="False">

  <DockPanel Margin="16">

    <!-- 底部按鈕 -->
    <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal"
                HorizontalAlignment="Right" Spacing="8" Margin="0,12,0,0">
      <Button Content="匯入" Click="OnImportClick"
              IsVisible="{Binding !NeedsPassword}" Classes="accent" />
      <Button Content="取消" Click="OnCancelClick" />
    </StackPanel>

    <Panel>

      <!-- 狀態 1: 需要密碼 -->
      <StackPanel Spacing="12" IsVisible="{Binding NeedsPassword}">
        <TextBlock Text="此檔案為加密格式，請輸入解密密碼：" FontWeight="Bold" />
        <TextBox Watermark="解密密碼" PasswordChar="●"
                 Text="{Binding DecryptPassword}" />
        <TextBlock Text="{Binding ErrorMessage}" Foreground="Red"
                   IsVisible="{Binding ErrorMessage, Converter={x:Static StringConverters.IsNotNullOrEmpty}}" />
        <Button Content="解密" Click="OnDecryptClick" Classes="accent" />
      </StackPanel>

      <!-- 狀態 2: 顯示預覽 -->
      <StackPanel Spacing="12" IsVisible="{Binding !NeedsPassword}">
        <TextBlock Text="即將匯入的連線設定：" FontWeight="Bold" FontSize="14" />

        <StackPanel Orientation="Horizontal" Spacing="8">
          <Button Content="全部覆蓋" Command="{Binding OverwriteAllCommand}" />
          <Button Content="全部跳過" Command="{Binding SkipAllCommand}" />
        </StackPanel>

        <Border BorderBrush="Gray" BorderThickness="1" CornerRadius="4"
                MaxHeight="300" Padding="4">
          <ScrollViewer>
            <ItemsControl ItemsSource="{Binding ImportPreviews}">
              <ItemsControl.ItemTemplate>
                <DataTemplate x:DataType="vm:ImportPreviewItem">
                  <Border Margin="2" Padding="8" CornerRadius="4"
                          BorderBrush="Gray" BorderThickness="1">
                    <StackPanel Spacing="4">
                      <StackPanel Orientation="Horizontal" Spacing="8">
                        <TextBlock Text="{Binding Profile.Name}" FontWeight="SemiBold" />
                        <Border Background="Orange" CornerRadius="3" Padding="4,1"
                                IsVisible="{Binding HasConflict}">
                          <TextBlock Text="衝突" Foreground="White" FontSize="11" />
                        </Border>
                      </StackPanel>
                      <TextBlock Text="{Binding Profile.Server}" Foreground="Gray" FontSize="12" />
                      <!-- 衝突處理選項 -->
                      <StackPanel Orientation="Horizontal" Spacing="12"
                                  IsVisible="{Binding HasConflict}">
                        <RadioButton Content="覆蓋" GroupName="{Binding Profile.Id}"
                                     IsChecked="{Binding ConflictAction, Converter={x:Static ObjectConverters.Equal}, ConverterParameter={x:Static vm:ConflictAction.Overwrite}}" />
                        <RadioButton Content="跳過" GroupName="{Binding Profile.Id}"
                                     IsChecked="{Binding ConflictAction, Converter={x:Static ObjectConverters.Equal}, ConverterParameter={x:Static vm:ConflictAction.Skip}}" />
                      </StackPanel>
                    </StackPanel>
                  </Border>
                </DataTemplate>
              </ItemsControl.ItemTemplate>
            </ItemsControl>
          </ScrollViewer>
        </Border>
      </StackPanel>

    </Panel>
  </DockPanel>
</Window>
```

- [ ] **Step 2: 建立 ImportConnectionsWindow code-behind**

```csharp
// src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml.cs
using Avalonia.Controls;
using Avalonia.Interactivity;
using MoldplanDbSwitcher.ViewModels;

namespace MoldplanDbSwitcher.Views;

public partial class ImportConnectionsWindow : Window
{
    public ImportConnectionsWindow()
    {
        InitializeComponent();
    }

    private void OnDecryptClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ImportConnectionsViewModel vm)
            vm.DecryptAndLoad();
    }

    private void OnImportClick(object? sender, RoutedEventArgs e)
    {
        if (DataContext is ImportConnectionsViewModel vm)
        {
            var result = vm.ExecuteImport();
            Close(result);
        }
    }

    private void OnCancelClick(object? sender, RoutedEventArgs e) => Close();
}
```

- [ ] **Step 3: 提交**

```bash
git add src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml src/MoldplanDbSwitcher/Views/ImportConnectionsWindow.axaml.cs
git commit -m "feat: 新增 ImportConnectionsWindow 匯入對話框 UI"
```

### Task 12: 主視窗整合 — 選單列與命令

**Files:**
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml`
- Modify: `src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs`
- Modify: `src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs`
- Modify: `src/MoldplanDbSwitcher/Program.cs`
- Modify: `tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs`

- [ ] **Step 1: 寫失敗測試 — MainWindowViewModel 匯出/匯入回呼**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs 新增：

[Fact]
public void ExportConnectionsCallbackProfiles_ReturnsCurrentConnections()
{
    var vm = CreateVm();
    Assert.NotNull(vm.GetConnectionsForExport());
    Assert.Single(vm.GetConnectionsForExport());
}
```

- [ ] **Step 2: 執行測試確認失敗**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests.ExportConnectionsCallbackProfiles_ReturnsCurrentConnections"`
Expected: FAIL — `GetConnectionsForExport` 方法不存在

- [ ] **Step 3: 在 MainWindowViewModel 新增方法與 DI 欄位**

```csharp
// src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs
// 新增 IConnectionExportService 到建構式：

private readonly IConnectionExportService _connectionExportService;

public MainWindowViewModel(
    IConnectionSourceService connectionSource,
    IServerTxtService serverTxtService,
    ISettingsService settingsService,
    IFeatureReportService featureReportService,
    IConnectionExportService connectionExportService)
{
    _connectionSource = connectionSource;
    _serverTxtService = serverTxtService;
    _settingsService = settingsService;
    _featureReportService = featureReportService;
    _connectionExportService = connectionExportService;

    LoadConnections();
    DiscoverServerTxtFiles();
}

public IReadOnlyList<ConnectionProfile> GetConnectionsForExport()
    => Connections.ToList();

// 供 View code-behind 使用：
public IConnectionExportService ConnectionExportService => _connectionExportService;
public ISettingsService SettingsService => _settingsService;
```

- [ ] **Step 4: 更新測試中的 CreateVm() 加入新參數**

```csharp
// tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
// 在 class 頂部新增欄位：
private readonly IConnectionExportService _connectionExportService;

// 在建構式中新增：
_connectionExportService = Substitute.For<IConnectionExportService>();

// 更新 CreateVm：
private MainWindowViewModel CreateVm() => new(
    _connectionSource, _serverTxtService, _settingsService,
    _featureReportService, _connectionExportService);
```

- [ ] **Step 5: 執行測試確認通過**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/ --filter "MainWindowViewModelTests"`
Expected: ALL PASS

- [ ] **Step 6: 在 Program.cs 註冊 DI**

```csharp
// src/MoldplanDbSwitcher/Program.cs — ConfigureServices 中新增：
services.AddSingleton<IConnectionExportService, ConnectionExportService>();
```

- [ ] **Step 7: 在 MainWindow.axaml 新增選單列**

在 `<DockPanel Margin="16">` 下方第一個元素前插入：

```xml
<!-- 選單列 -->
<Menu DockPanel.Dock="Top" Margin="0,0,0,8">
  <MenuItem Header="檔案(_F)">
    <MenuItem Header="匯出連線設定(_X)" Click="OnExportConnectionsClick" />
    <MenuItem Header="匯入連線設定(_I)" Click="OnImportConnectionsClick" />
  </MenuItem>
</Menu>
```

- [ ] **Step 8: 在 MainWindow.axaml.cs 新增事件處理**

```csharp
// src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs 新增：

private async void OnExportConnectionsClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is not MainWindowViewModel vm) return;

    var profiles = vm.GetConnectionsForExport();
    if (profiles.Count == 0) return;

    var exportVm = new ExportConnectionsViewModel(profiles, vm.ConnectionExportService);
    var dialog = new ExportConnectionsWindow { DataContext = exportVm };
    await dialog.ShowDialog(this);
}

private async void OnImportConnectionsClick(object? sender, RoutedEventArgs e)
{
    if (DataContext is not MainWindowViewModel vm) return;

    // 開啟檔案選擇
    var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
    {
        Title = "選擇連線設定檔",
        AllowMultiple = false,
        FileTypeFilter = new[]
        {
            new FilePickerFileType("連線設定檔") { Patterns = new[] { "*.json", "*.tsjson" } }
        }
    });

    if (files.Count == 0) return;

    await using var stream = await files[0].OpenReadAsync();
    using var ms = new System.IO.MemoryStream();
    await stream.CopyToAsync(ms);
    var data = ms.ToArray();

    var importVm = new ImportConnectionsViewModel(
        vm.ConnectionExportService, vm.SettingsService, vm.GetConnectionsForExport());
    importVm.LoadImportData(data);

    var dialog = new ImportConnectionsWindow { DataContext = importVm };
    var result = await dialog.ShowDialog<ImportResult?>(this);

    if (result is not null)
    {
        vm.LoadConnectionsCommand.Execute(null);
        vm.StatusMessage = $"匯入完成：新增 {result.Added}，覆蓋 {result.Overwritten}，跳過 {result.Skipped}";
    }
}
```

- [ ] **Step 9: 建置確認編譯通過**

Run: `dotnet build src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj`
Expected: Build succeeded

- [ ] **Step 10: 執行所有測試確認無回歸**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: ALL PASS

- [ ] **Step 11: 提交**

```bash
git add src/MoldplanDbSwitcher/ViewModels/MainWindowViewModel.cs src/MoldplanDbSwitcher/Views/MainWindow.axaml src/MoldplanDbSwitcher/Views/MainWindow.axaml.cs src/MoldplanDbSwitcher/Program.cs tests/MoldplanDbSwitcher.Tests/ViewModels/MainWindowViewModelTests.cs
git commit -m "feat: 主視窗整合匯出/匯入選單與 DI 註冊"
```

---

## Chunk 5: 最終驗證

### Task 13: 全面整合測試與手動驗證

- [ ] **Step 1: 執行所有測試**

Run: `dotnet test tests/MoldplanDbSwitcher.Tests/`
Expected: ALL PASS

- [ ] **Step 2: 建置發佈版本**

Run: `dotnet publish src/MoldplanDbSwitcher/MoldplanDbSwitcher.csproj -c Release -r win-x64 --self-contained -o publish/win-x64/`
Expected: Build succeeded

- [ ] **Step 3: 手動驗證清單**

1. 啟動應用程式，確認選單列出現「檔案 → 匯出連線設定 / 匯入連線設定」
2. 匯出純文字 JSON，確認檔案可讀取
3. 匯出加密 JSON，設定密碼
4. 匯入純文字 JSON，確認預覽正確，衝突標記正確
5. 匯入加密 JSON，輸入正確/錯誤密碼
6. 確認匯入後連線清單更新

- [ ] **Step 4: 最終提交（如有調整）**

```bash
git add -A
git commit -m "chore: 連線設定匯出/匯入功能最終調整"
```
