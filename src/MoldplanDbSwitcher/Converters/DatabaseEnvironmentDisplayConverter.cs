using System;
using System.Globalization;
using Avalonia.Data.Converters;
using MoldplanDbSwitcher.Models;

namespace MoldplanDbSwitcher.Converters;

/// <summary>將 DatabaseEnvironment 轉為繁中顯示名稱（開發/測試/預備/正式環境）。</summary>
public class DatabaseEnvironmentDisplayConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        => value switch
        {
            DatabaseEnvironment.Development => "開發環境",
            DatabaseEnvironment.Testing => "測試環境",
            DatabaseEnvironment.Staging => "預備環境",
            DatabaseEnvironment.Production => "正式環境",
            _ => value?.ToString()
        };

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        => throw new NotImplementedException();
}
