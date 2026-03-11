namespace MoldplanDbSwitcher.Models;

public class ServerTxtEntry
{
    public string Field1 { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = string.Empty;
    public string ServerAddress { get; set; } = string.Empty;
    public string Field4 { get; set; } = string.Empty;
    public string Field5 { get; set; } = string.Empty;

    public static ServerTxtEntry Parse(string line)
    {
        var parts = line.Split(',');
        if (parts.Length < 5)
            throw new FormatException($"SERVER.txt 格式不正確，預期 5 個欄位但只有 {parts.Length} 個: {line}");

        return new ServerTxtEntry
        {
            Field1 = parts[0],
            DatabaseName = parts[1],
            ServerAddress = parts[2],
            Field4 = parts[3],
            Field5 = parts[4]
        };
    }

    public string ToLine() => $"{Field1},{DatabaseName},{ServerAddress},{Field4},{Field5}";
}
