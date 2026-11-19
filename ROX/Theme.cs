using System.Windows;
using System.Windows.Media;

namespace ROX;

public sealed class ThemeColors
{
    public string Name { get; set; } = "Mint Dark";
    public string A1 { get; set; } = "#5CFFA0";
    public string A2 { get; set; } = "#C8FFE0";
    public string Bg { get; set; } = "#000000";
    public string Panel { get; set; } = "#0E1210";
    public string Text { get; set; } = "#EFFFF5";

    public ThemeColors Clone() => (ThemeColors)MemberwiseClone();

    public static readonly ThemeColors[] Presets =
    {
        new() { Name = "Mint Dark", A1 = "#5CFFA0", A2 = "#C8FFE0", Bg = "#000000", Panel = "#0E1210", Text = "#EFFFF5" },
        new() { Name = "Mint Light", A1 = "#14B866", A2 = "#2EE88A", Bg = "#EEF5F0", Panel = "#FFFFFF", Text = "#0B0B0B" },
        new() { Name = "Neon", A1 = "#19E6E6", A2 = "#E040FB", Bg = "#0E0E13", Panel = "#1A1A22", Text = "#ECECF4" },
        new() { Name = "Toxic Green", A1 = "#39FF14", A2 = "#00C853", Bg = "#000000", Panel = "#0D120D", Text = "#E8FFE8" },
        new() { Name = "White Purple", A1 = "#8E24AA", A2 = "#5E35B1", Bg = "#EDEAF3", Panel = "#FFFFFF", Text = "#1E1730" },
        new() { Name = "Blood Red", A1 = "#FF1744", A2 = "#FF9100", Bg = "#0B0606", Panel = "#1A0E0E", Text = "#FFECEC" },
        new() { Name = "Ocean", A1 = "#2979FF", A2 = "#00E5FF", Bg = "#060B16", Panel = "#0F1A2E", Text = "#E6F0FF" },
        new() { Name = "Gold", A1 = "#FFC400", A2 = "#FFFFFF", Bg = "#0A0A0A", Panel = "#171512", Text = "#FFF8E1" },
    };
}

public static class ThemeManager
{
    public static ThemeColors Current { get; private set; } = ThemeColors.Presets[0];
    public static event Action? Changed;

    public static Color A1 => Parse(Current.A1);
    public static Color A2 => Parse(Current.A2);
    public static Color Bg => Parse(Current.Bg);
    public static Color Panel => Parse(Current.Panel);
    public static Color Text => Parse(Current.Text);
    public static bool IsLight => Lum(Panel) > 0.5;

    public static Color Parse(string hex, Color? fallback = null)
    {
        try { return (Color)ColorConverter.ConvertFromString(hex.StartsWith('#') ? hex : "#" + hex); }
        catch { return fallback ?? Colors.Magenta; }
    }

    static double Lum(Color c) => (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) / 255;
    static Color Mix(Color a, Color b, double t) => Color.FromRgb((byte)(a.R + (b.R - a.R) * t), (byte)(a.G + (b.G - a.G) * t), (byte)(a.B + (b.B - a.B) * t));
    static Color Alpha(Color c, byte a) => Color.FromArgb(a, c.R, c.G, c.B);

    public static Color Panel2 => Mix(Panel, IsLight ? Colors.Black : Colors.White, 0.07);
    public static Color Sub => Mix(Text, Panel, 0.45);

    public static void Apply(ThemeColors t)
    {
        Current = t.Clone();
        var r = Application.Current.Resources;
        r["Bg"] = new SolidColorBrush(Bg);
        r["Panel"] = new SolidColorBrush(Panel);
        r["Panel2"] = new SolidColorBrush(Panel2);
        r["Text"] = new SolidColorBrush(Text);
        r["Sub"] = new SolidColorBrush(Sub);
        r["Accent1"] = new SolidColorBrush(A1);
        r["Accent2"] = new SolidColorBrush(A2);
        r["Accent1Soft"] = new SolidColorBrush(Alpha(A1, 0x40));
        r["Accent2Soft"] = new SolidColorBrush(Alpha(A2, 0x40));
        r["OnAccent"] = new SolidColorBrush(Lum(A1) > 0.55 ? Color.FromRgb(15, 15, 20) : Colors.White);
        Changed?.Invoke();
    }
}
