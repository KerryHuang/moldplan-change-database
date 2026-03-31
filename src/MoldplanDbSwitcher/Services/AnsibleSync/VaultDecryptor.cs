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
            throw new InvalidOperationException("不支援的 Vault 格式，僅支援 $ANSIBLE_VAULT;1.1;AES256");

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
        // 注意：若 padding 無效，不丟例外。HMAC 已確保資料完整性，
        // padding 去除僅為清理用途；Ansible vault 固定使用 PKCS7 padding，
        // 若此處條件不符表示資料異常，但 HMAC 已通過，保留原始資料即可。
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
