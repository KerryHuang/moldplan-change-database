using System;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Services;

public sealed class ActiveConnectionService : IActiveConnectionService
{
    public ActiveConnection? Current { get; private set; }
    public event Action<ActiveConnection>? Changed;

    public void SetCurrent(ActiveConnection connection)
    {
        Current = connection;
        Changed?.Invoke(connection);
    }
}
