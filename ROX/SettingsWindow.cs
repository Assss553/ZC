using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using NAudio.CoreAudioApi;
using ROX.Audio;
using static ROX.Lang;

namespace ROX;

public sealed class SettingsWindow : Window
{
    readonly Settings cfg;
    readonly Action devicesChanged, langChanged;
    readonly Action<int, float> outVolume;
    static readonly DeviceInfo None = new("", "");
    TabControl? tabs; int lastTab;

    public SettingsWindow(Settings cfg, Action devicesChanged, Action langChanged, Action<int, float> outVolume)
    {
        this.cfg = cfg; this.devicesChanged = devicesChanged; this.langChanged = langChanged; this.outVolume = outVolume;
        Title = L("sTitle"); Width = 620; Height = 640; WindowStartupLocation = WindowStartupLocation.CenterOwner;
        SetResourceReference(BackgroundProperty, "Bg");
        FlowDirection = Rtl ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        Build();
    }

    void Build()
    {
        var tabs = this.tabs = new TabControl { Margin = new Thickness(12), Background = Brushes.Transparent, BorderThickness = new Thickness(0) };
        tabs.Items.Add(Tab(L("tAudio"), AudioTab()));
        tabs.Items.Add(Tab(L("tLook"), LookTab()));
        tabs.Items.Add(Tab(L("tLang"), LangTab()));
        var close = new Button { Content = L("close"), HorizontalAlignment = HorizontalAlignment.Right, Margin = new Thickness(12), MinWidth = 100 };
        close.Click += (_, _) => Close();
        var dp = new DockPanel(); DockPanel.SetDock(close, Dock.Bottom);
        dp.Children.Add(close); dp.Children.Add(tabs);
        Content = dp; tabs.SelectedIndex = lastTab; tabs.SelectionChanged += (_, _) => lastTab = tabs.SelectedIndex;
    }

    static TabItem Tab(string header, UIElement content)
    {
        var card = new Border { CornerRadius = new CornerRadius(12), Padding = new Thickness(18), Child = new ScrollViewer { Content = content, VerticalScrollBarVisibility = ScrollBarVisibility.Auto } };
        card.SetResourceReference(Border.BackgroundProperty, "Panel");
        return new TabItem { Header = new TextBlock { Text = header, Foreground = Brushes.Black, FontWeight = FontWeights.SemiBold, Margin = new Thickness(8, 2, 8, 2) }, Content = card };
    }

    static TextBlock H(string t) { var tb = new TextBlock { Text = t, FontWeight = FontWeights.Bold, FontSize = 14, Margin = new Thickness(0, 12, 0, 6) }; tb.SetResourceReference(TextBlock.ForegroundProperty, "Accent1"); return tb; }

    UIElement AudioTab()
    {
        var sp = new StackPanel();
        var ins = AudioEngine.Devices(DataFlow.Capture);
        var outs = AudioEngine.Devices(DataFlow.Render);
        sp.Children.Add(H(L("dMic"))); sp.Children.Add(Combo(ins, cfg.Mic, id => cfg.Mic = id));
        sp.Children.Add(H(L("dLine"))); sp.Children.Add(Combo(ins, cfg.Line, id => cfg.Line = id));
        string[] keys = { "dOut1", "dOut2", "dOut3" };
        for (int i = 0; i < 3; i++)
        {
            int idx = i;
            sp.Children.Add(H(L(keys[i])));
            var row = new DockPanel();
            var vol = new Slider { Minimum = 0, Maximum = 1.5, Value = cfg.OutVolumes[i], Width = 140, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(10, 0, 0, 0), ToolTip = L("volume") };
            vol.ValueChanged += (_, e) => { cfg.OutVolumes[idx] = (float)e.NewValue; outVolume(idx, (float)e.NewValue); };
            DockPanel.SetDock(vol, Dock.Right);
            row.Children.Add(vol);
            row.Children.Add(Combo(outs, cfg.Outputs[i], id => cfg.Outputs[idx] = id));
            sp.Children.Add(row);
        }
        var tip = new TextBlock { Text = "Discord / OBS: Output 2 = CABLE Input → app mic = CABLE Output", TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 14, 0, 0) };
        tip.SetResourceReference(TextBlock.ForegroundProperty, "Sub");
        sp.Children.Add(tip);
        return sp;
    }

    ComboBox Combo(List<DeviceInfo> devs, string? selected, Action<string?> set)
    {
        var cb = new ComboBox { Padding = new Thickness(6, 4, 6, 4) };
        cb.Items.Add(None with { Name = L("none") });
        foreach (var d in devs) cb.Items.Add(d);
        cb.SelectedItem = devs.FirstOrDefault(d => d.Id == selected) ?? cb.Items[0];
        cb.SelectionChanged += (_, _) => { set(cb.SelectedItem is DeviceInfo d && d.Id != "" ? d.Id : null); cfg.Save(); devicesChanged(); };
        return cb;
    }

    UIElement LookTab()
    {
        var sp = new StackPanel();
        sp.Children.Add(H(L("themes")));
        var grid = new WrapPanel();
        foreach (var t in ThemeColors.Presets)
        {
            var b = new Button { Width = 165, Height = 64, Padding = new Thickness(0), BorderBrush = new SolidColorBrush(ThemeManager.Parse(t.A1)), Background = new SolidColorBrush(ThemeManager.Parse(t.Panel)) };
            var inner = new StackPanel();
            var sw = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
            foreach (var c in new[] { t.Bg, t.A1, t.A2 }) sw.Children.Add(new Border { Width = 22, Height = 14, Margin = new Thickness(2), CornerRadius = new CornerRadius(3), Background = new SolidColorBrush(ThemeManager.Parse(c)), BorderBrush = Brushes.Gray, BorderThickness = new Thickness(0.5) });
            inner.Children.Add(sw);
            inner.Children.Add(new TextBlock { Text = t.Name, Foreground = new SolidColorBrush(ThemeManager.Parse(t.A1)), HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 4, 0, 0) });
            b.Content = inner;
            b.Click += (_, _) => { cfg.Theme = t.Clone(); ThemeManager.Apply(cfg.Theme); cfg.Save(); Build(); };
            grid.Children.Add(b);
        }
        sp.Children.Add(grid);

        sp.Children.Add(H(L("custom")));
        var edit = cfg.Theme.Clone();
        void Row(string label, Func<string> get, Action<string> set)
        {
            var row = new DockPanel { Margin = new Thickness(0, 3, 0, 3) };
            var swatch = new Border { Width = 34, Height = 24, CornerRadius = new CornerRadius(4), BorderBrush = Brushes.Gray, BorderThickness = new Thickness(1), Margin = new Thickness(8, 0, 8, 0), Background = new SolidColorBrush(ThemeManager.Parse(get())) };
            var box = new TextBox { Text = get(), Width = 110, FlowDirection = FlowDirection.LeftToRight, VerticalContentAlignment = VerticalAlignment.Center, Padding = new Thickness(4, 2, 4, 2) };
            box.TextChanged += (_, _) => { set(box.Text.Trim()); swatch.Background = new SolidColorBrush(ThemeManager.Parse(box.Text.Trim(), Colors.Transparent)); };
            var tb = new TextBlock { Text = label, Width = 150, VerticalAlignment = VerticalAlignment.Center };
            row.Children.Add(tb); row.Children.Add(swatch); row.Children.Add(box);
            sp.Children.Add(row);
        }
        Row(L("cA1"), () => edit.A1, v => edit.A1 = v);
        Row(L("cA2"), () => edit.A2, v => edit.A2 = v);
        Row(L("cBg"), () => edit.Bg, v => edit.Bg = v);
        Row(L("cPanel"), () => edit.Panel, v => edit.Panel = v);
        Row(L("cText"), () => edit.Text, v => edit.Text = v);
        var apply = new Button { Content = L("apply"), HorizontalAlignment = HorizontalAlignment.Left, MinWidth = 110, Margin = new Thickness(0, 10, 0, 0) };
        apply.Click += (_, _) => { edit.Name = "Custom"; cfg.Theme = edit.Clone(); ThemeManager.Apply(cfg.Theme); cfg.Save(); Build(); };
        sp.Children.Add(apply);
        return sp;
    }

    UIElement LangTab()
    {
        var sp = new StackPanel();
        sp.Children.Add(H(L("langPick")));
        foreach (var (code, name) in new[] { ("en", "English"), ("ar", "العربية") })
        {
            var rb = new RadioButton { Content = name, GroupName = "lang", IsChecked = Lang.Code == code, FontSize = 15, Margin = new Thickness(0, 6, 0, 6) };
            rb.Checked += (_, _) =>
            {
                Lang.Code = code; cfg.Language = code; cfg.Save();
                FlowDirection = Rtl ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
                Title = L("sTitle");
                langChanged(); Build();
            };
            sp.Children.Add(rb);
        }
        return sp;
    }
}
