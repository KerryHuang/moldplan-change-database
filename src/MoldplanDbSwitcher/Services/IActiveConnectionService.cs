using System;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

/// <summary>持有目前作用中連線，並在變更時通知訂閱者（已開啟文件）。</summary>
public interface IActiveConnectionService
{
    ActiveConnection? Current { get; }
    event Action<ActiveConnection>? Changed;
    void SetCurrent(ActiveConnection connection);
}
