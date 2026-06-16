namespace MoldplanDbSwitcher.Models;

/// <summary>目前作用中連線的快照，供已開啟文件重指向。</summary>
public record ActiveConnection(string ConnectionString, string Database, ConnectionProfile? Profile);
