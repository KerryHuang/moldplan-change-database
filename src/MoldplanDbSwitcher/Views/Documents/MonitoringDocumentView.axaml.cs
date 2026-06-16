using System;
using Avalonia.Controls;
using Avalonia.Threading;
using MoldplanDbSwitcher.ViewModels.Documents;

namespace MoldplanDbSwitcher.Views.Documents;

public partial class MonitoringDocumentView : UserControl
{
    private readonly DispatcherTimer _timer;

    public MonitoringDocumentView()
    {
        InitializeComponent();
        _timer = new DispatcherTimer();
        _timer.Tick += OnTick;
        AttachedToVisualTree += (_, _) => StartTimer();
        DetachedFromVisualTree += (_, _) => _timer.Stop();
        Loaded += async (_, _) =>
        {
            if (DataContext is MonitoringDocumentViewModel vm)
                await vm.RefreshCommand.ExecuteAsync(null);
        };
    }

    private void StartTimer()
    {
        if (DataContext is not MonitoringDocumentViewModel vm) return;
        _timer.Interval = TimeSpan.FromSeconds(Math.Max(5, vm.RefreshIntervalSeconds));
        _timer.Start();
    }

    private void OnTick(object? sender, EventArgs e)
    {
        if (DataContext is not MonitoringDocumentViewModel vm) { _timer.Stop(); return; }
        if (!vm.AutoRefreshEnabled || vm.IsBusy) return;
        _timer.Interval = TimeSpan.FromSeconds(Math.Max(5, vm.RefreshIntervalSeconds));
        _ = vm.RefreshCommand.ExecuteAsync(null);
    }
}
