using System.Security.Cryptography;
using System.Text.Json;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public class ConnectionExportService : IConnectionExportService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };
    private static readonly byte[] MagicBytes = "TSEC"u8.ToArray();
    private const int SaltSize = 16;
    private const int IvSize = 16;
    private const int KeySize = 32;
    private const int Iterations = 100_000;

    public byte[] ExportToJson(IReadOnlyList<ConnectionProfile> profiles, bool includePasswords)
    {
        var prepared = PrepareProfiles(profiles, includePasswords);
        var exportData = new ConnectionExportData { Profiles = prepared };
        return JsonSerializer.SerializeToUtf8Bytes(exportData, JsonOptions);
    }

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

        var result = new byte[MagicBytes.Length + SaltSize + IvSize + encrypted.Length];
        MagicBytes.CopyTo(result, 0);
        salt.CopyTo(result, MagicBytes.Length);
        iv.CopyTo(result, MagicBytes.Length + SaltSize);
        encrypted.CopyTo(result, MagicBytes.Length + SaltSize + IvSize);
        return result;
    }

    public ConnectionExportData ImportFromJson(byte[] data)
    {
        return JsonSerializer.Deserialize<ConnectionExportData>(data)
            ?? throw new InvalidOperationException("無法解析匯入資料");
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

    public bool IsEncryptedFormat(byte[] data)
    {
        if (data.Length < MagicBytes.Length)
            return false;
        return data.AsSpan(0, MagicBytes.Length).SequenceEqual(MagicBytes);
    }

    private static byte[] DeriveKey(string password, byte[] salt)
    {
        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, Iterations, HashAlgorithmName.SHA256);
        return pbkdf2.GetBytes(KeySize);
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
