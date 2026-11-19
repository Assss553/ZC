using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Threading;
using Microsoft.Win32;
using ROX.Audio;
using static ROX.Lang;

namespace ROX;

public sealed class MainWindow : Window
{
    readonly AudioEngine engine = new();
    readonly Settings cfg = Settings.Load();
    readonly List<(Channel ch, Fader f)> faders = new();
    readonly Dictionary<string, Knob> knobs = new();
    LedBar? master;
    Button? startBtn, micBtn;
    TextBlock? status, statusPill, musicName;
    int bank;
    readonly Button[] pads = new Button[4];
    readonly Button[] banks = new Button[3];

    public MainWindow()
    {
        Lang.Code = cfg.Language;
        ThemeManager.Apply(cfg.Theme);
        Title = "ROX"; Width = 1440; Height = 860; MinWidth = 1280; MinHeight = 800;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        SetResourceReference(BackgroundProperty, "Bg");
        engine.MonitorMic = cfg.Monitor;
        foreach (var ch in AllChannels) if (cfg.Values.TryGetValue("vol_" + Key(ch), out var v)) ch.Volume = v;
        ApplyVoiceFromCfg();
        Build();
        ThemeManager.Changed += Build;

        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(33) };
        timer.Tick += (_, _) => Meters();
        timer.Start();
        Closing += (_, _) => { cfg.Monitor = engine.MonitorMic; cfg.Save(); engine.Dispose(); };
    }

    Channel[] AllChannels => new[] { engine.Mic, engine.Line, engine.Music, engine.Samples };
    string Key(Channel c) => c == engine.Mic ? "mic" : c == engine.Line ? "line" : c == engine.Music ? "music" : "sfx";

    // ================= Layout =================
    void Build()
    {
        FlowDirection = Rtl ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        faders.Clear(); knobs.Clear();

        var device = Card(new Thickness(22), 22);
        device.BorderThickness = new Thickness(1.5);
        device.SetResourceReference(Border.BorderBrushProperty, "Accent1Soft");
        device.Effect = new DropShadowEffect { BlurRadius = 30, ShadowDepth = 0, Opacity = 0.6, Color = Colors.Black };

        var dock = new DockPanel();
        var header = Header(); DockPanel.SetDock(header, Dock.Top); dock.Children.Add(header);
        status = Txt(L("hint"), 12, "Sub"); status.Margin = new Thickness(4, 10, 0, 0);
        DockPanel.SetDock(status, Dock.Bottom); dock.Children.Add(status);

        var body = new Grid { Margin = new Thickness(0, 16, 0, 0) };
        foreach (var w in new[] { GridLength.Auto, new GridLength(1, GridUnitType.Star), GridLength.Auto })
            body.ColumnDefinitions.Add(new ColumnDefinition { Width = w });
        var mixer = MixerSection();
        var mid = MiddleSection(); Grid.SetColumn(mid, 1);
        var right = RightSection(); Grid.SetColumn(right, 2);
        body.Children.Add(mixer); body.Children.Add(mid); body.Children.Add(right);
        dock.Children.Add(body);

        device.Child = dock;
        Content = new Border { Padding = new Thickness(18), Child = device };
        UpdateStart();
    }

    UIElement Header()
    {
        var dp = new DockPanel();
        var logo = new StackPanel { Orientation = Orientation.Horizontal, FlowDirection = FlowDirection.LeftToRight, VerticalAlignment = VerticalAlignment.Center };
        logo.Children.Add(Txt("R", 38, "Accent1", FontWeights.Black));
        var x = Txt("O", 38, "Accent2", FontWeights.Black); logo.Children.Add(x);
        logo.Children.Add(Txt("X", 38, "Accent1", FontWeights.Black));
        logo.Children.Add(Txt("  AUDIO MIXER", 12, "Sub", FontWeights.Bold));
        ((TextBlock)logo.Children[3]).VerticalAlignment = VerticalAlignment.Center;
        DockPanel.SetDock(logo, Dock.Left); dp.Children.Add(logo);

        var right = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right };
        statusPill = Txt("", 13, "Sub", FontWeights.Bold); statusPill.VerticalAlignment = VerticalAlignment.Center; statusPill.Margin = new Thickness(10, 0, 10, 0);
        right.Children.Add(statusPill);
        startBtn = Btn("", false, 140); startBtn.Height = 42;
        startBtn.Click += (_, _) => { if (engine.Running) { engine.Stop(); UpdateStart(); } else StartEngine(); };
        right.Children.Add(startBtn);
        var set = Btn(L("settings"), true, 150); set.Height = 42;
        set.Click += (_, _) => new SettingsWindow(cfg, () => { if (engine.Running) StartEngine(); }, Build, (i, v) => engine.SetOutputVolume(OutIndex(i), v)) { Owner = this }.ShowDialog();
        right.Children.Add(set);
        dp.Children.Add(right);
        return dp;
    }

    // ---------- Mixer ----------
    UIElement MixerSection()
    {
        var card = Card(new Thickness(14), 16);
        var sp = new StackPanel();
        sp.Children.Add(SectionTitle(L("mixer")));
        var strips = new StackPanel { Orientation = Orientation.Horizontal };
        var icons = new[] { "🎤", "🎧", "♫", "▦" };
        var names = new[] { L("mic"), L("line"), L("music"), L("sfx") };
        var chans = AllChannels;
        for (int i = 0; i < 4; i++)
        {
            var ch = chans[i];
            var strip = new StackPanel { Margin = new Thickness(6, 0, 6, 0), Width = 82 };
            // scribble LCD
            var lcd = new Border { Height = 54, CornerRadius = new CornerRadius(5), Margin = new Thickness(0, 0, 0, 8), BorderThickness = new Thickness(2) };
            lcd.SetResourceReference(Border.BackgroundProperty, "Accent1");
            lcd.SetResourceReference(Border.BorderBrushProperty, "Accent1Soft");
            lcd.Effect = new DropShadowEffect { BlurRadius = 14, ShadowDepth = 0, Opacity = 0.7, Color = ThemeManager.A1 };
            var ls = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            ls.Children.Add(Center(Txt($"{i + 1}  {icons[i]}", 15, "OnAccent", FontWeights.Bold)));
            ls.Children.Add(Center(Txt(names[i], 11, "OnAccent", FontWeights.Bold)));
            lcd.Child = ls;
            strip.Children.Add(lcd);

            var f = new Fader { Value = ch.Volume, HorizontalAlignment = HorizontalAlignment.Center, Height = 330 };
            string key = "vol_" + Key(ch);
            f.Changed += v => { ch.Volume = (float)v; cfg.Values[key] = (float)v; };
            strip.Children.Add(f);
            faders.Add((ch, f));

            var mute = Btn("◀×", true, 60);
            mute.Tag = ch.Muted ? "on2" : null;
            mute.ToolTip = L("mute");
            mute.Click += (_, _) => { ch.Muted = !ch.Muted; mute.Tag = ch.Muted ? "on2" : null; if (ch == engine.Mic) PaintMic(); };
            strip.Children.Add(mute);
            strips.Children.Add(strip);
        }
        sp.Children.Add(strips);

        // music transport
        var mrow = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 8, 0, 0) };
        var load = Btn(L("load"), false); load.Click += (_, _) => LoadMusic();
        var play = Btn("⏯", false, 48); play.Click += (_, _) => engine.Player.Playing = !engine.Player.Playing;
        musicName = Txt(engine.Player.File is string mf ? System.IO.Path.GetFileName(mf) : "—", 11, "Sub");
        musicName.VerticalAlignment = VerticalAlignment.Center; musicName.MaxWidth = 200; musicName.TextTrimming = TextTrimming.CharacterEllipsis;
        mrow.Children.Add(load); mrow.Children.Add(play); mrow.Children.Add(musicName);
        sp.Children.Add(mrow);
        card.Child = sp;
        return card;
    }

    // ---------- FX / Sampler ----------
    UIElement MiddleSection()
    {
        var grid = new Grid { Margin = new Thickness(16, 0, 16, 0) };
        grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        // FX card
        var fx = Card(new Thickness(14), 16);
        var fxg = new Grid();
        fxg.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        fxg.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        fxg.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var presets = new StackPanel { Margin = new Thickness(0, 0, 12, 0) };
        presets.Children.Add(SectionTitle(L("presets")));
        for (int i = 0; i < 6; i++)
        {
            int idx = i;
            var b = Btn((i + 1).ToString(), false, 54); b.Height = 32; b.Margin = new Thickness(2, 3, 2, 3);
            b.ToolTip = L("presetTip");
            if (cfg.FxPresets[i] != null) b.Tag = "on";
            b.Click += (_, _) => { if (cfg.FxPresets[idx] is { } p) foreach (var kv in p) if (knobs.TryGetValue(kv.Key, out var k)) k.Value = kv.Value; };
            b.MouseRightButtonUp += (_, _) => { cfg.FxPresets[idx] = knobs.ToDictionary(k => k.Key, k => (float)k.Value.Value); b.Tag = "on"; cfg.Save(); };
            presets.Children.Add(b);
        }
        fxg.Children.Add(presets);

        var center = new StackPanel(); Grid.SetColumn(center, 1);
        center.Children.Add(SectionTitle(L("effects")));
        var big = new UniformGrid { Columns = 4, HorizontalAlignment = HorizontalAlignment.Center };
        var v = engine.Voice;
        big.Children.Add(MakeKnob("reverb", L("reverb"), 0, 100, 0, x => v.Reverb = (float)x, x => $"{x:0}%", true));
        big.Children.Add(MakeKnob("pitch", L("pitch"), -12, 12, 0, x => { v.Pitch = (float)x; engine.UpdatePitch(); }, x => x > 0 ? $"+{x:0}" : $"{x:0}", true));
        big.Children.Add(MakeKnob("echo", L("echo"), 0, 100, 0, x => v.Echo = (float)x, x => $"{x:0}%", true));
        big.Children.Add(MakeKnob("noise", L("noise"), 0, 100, 50, x => v.NoiseStrength = (float)x, x => $"{x:0}%", true));
        center.Children.Add(big);
        var tuneTitle = SectionTitle(L("mictune")); tuneTitle.Margin = new Thickness(0, 6, 0, 0);
        center.Children.Add(tuneTitle);
        var small = new UniformGrid { Columns = 5, HorizontalAlignment = HorizontalAlignment.Center };
        small.Children.Add(MakeKnob("gain", L("gain"), -12, 24, 0, x => v.Gain = (float)x, x => $"{x:0}dB"));
        small.Children.Add(MakeKnob("comp", L("comp"), 0, 100, 30, x => v.Comp = (float)x, x => $"{x:0}%"));
        small.Children.Add(MakeKnob("bass", L("bass"), -12, 12, 0, x => { v.Bass = (float)x; v.EqDirty = true; }, x => $"{x:0}dB"));
        small.Children.Add(MakeKnob("mid", L("mid"), -12, 12, 0, x => { v.Mid = (float)x; v.EqDirty = true; }, x => $"{x:0}dB"));
        small.Children.Add(MakeKnob("treble", L("treble"), -12, 12, 0, x => { v.Treble = (float)x; v.EqDirty = true; }, x => $"{x:0}dB"));
        center.Children.Add(small);
        fxg.Children.Add(center);

        var fxBtns = new StackPanel { Margin = new Thickness(12, 0, 0, 0), Width = 150 };
        Grid.SetColumn(fxBtns, 2);
        fxBtns.Children.Add(SectionTitle(" "));
        fxBtns.Children.Add(FxToggle(L("megaphone"), () => v.Megaphone = !v.Megaphone, () => v.Megaphone));
        fxBtns.Children.Add(FxToggle(L("robot"), () => v.Robot = !v.Robot, () => v.Robot));
        var deep = Btn(L("deep"), false); deep.Height = 40;
        deep.Click += (_, _) => { knobs["pitch"].Value = -5; knobs["bass"].Value = 6; knobs["reverb"].Value = 15; };
        fxBtns.Children.Add(deep);
        var fxb = FxToggle(L("fx"), () => { v.FxOn = !v.FxOn; engine.UpdatePitch(); }, () => v.FxOn);
        fxb.Height = 80; fxb.FontSize = 22;
        fxBtns.Children.Add(fxb);
        fxg.Children.Add(fxBtns);
        fx.Child = fxg;
        grid.Children.Add(fx);

        // Sampler card
        var smp = Card(new Thickness(14), 16); smp.Margin = new Thickness(0, 16, 0, 0);
        Grid.SetRow(smp, 1);
        var sdock = new DockPanel();
        var st = SectionTitle(L("sampler")); DockPanel.SetDock(st, Dock.Top); sdock.Children.Add(st);
        var tip = Txt(L("samplerTip"), 11, "Sub"); DockPanel.SetDock(tip, Dock.Bottom); sdock.Children.Add(tip);
        var bankCol = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        for (int i = 0; i < 3; i++)
        {
            int idx = i;
            banks[i] = Btn(((char)('A' + i)).ToString(), true, 54); banks[i].Height = 40;
            banks[i].Click += (_, _) => { bank = idx; RefreshPads(); };
            bankCol.Children.Add(banks[i]);
        }
        DockPanel.SetDock(bankCol, Dock.Left); sdock.Children.Add(bankCol);

        var padGrid = new Grid { Margin = new Thickness(12, 4, 0, 4), MaxWidth = 560 };
        padGrid.RowDefinitions.Add(new RowDefinition()); padGrid.RowDefinitions.Add(new RowDefinition());
        padGrid.ColumnDefinitions.Add(new ColumnDefinition()); padGrid.ColumnDefinitions.Add(new ColumnDefinition());
        for (int i = 0; i < 4; i++)
        {
            int idx = i;
            var b = Btn("", false); b.Margin = new Thickness(5); b.MinHeight = 64; b.FontSize = 13;
            b.SetResourceReference(Control.BackgroundProperty, "Panel2");
            b.Click += (_, _) => PlayPad(idx);
            b.MouseRightButtonUp += (_, _) => AssignPad(idx);
            Grid.SetRow(b, i / 2); Grid.SetColumn(b, i % 2);
            padGrid.Children.Add(b); pads[i] = b;
        }
        var clear = Btn(L("clear"), true, 96); clear.Height = 46;
        clear.HorizontalAlignment = HorizontalAlignment.Center; clear.VerticalAlignment = VerticalAlignment.Center;
        clear.SetResourceReference(Control.BackgroundProperty, "Panel");
        Grid.SetRowSpan(clear, 2); Grid.SetColumnSpan(clear, 2);
        clear.Click += (_, _) => engine.StopSamples();
        padGrid.Children.Add(clear);
        sdock.Children.Add(padGrid);
        smp.Child = sdock;
        grid.Children.Add(smp);
        RefreshPads();
        return grid;
    }

    // ---------- Right column ----------
    UIElement RightSection()
    {
        var card = Card(new Thickness(14), 16); card.Width = 230;
        var dp = new DockPanel();
        var top = new StackPanel(); DockPanel.SetDock(top, Dock.Top);
        top.Children.Add(SectionTitle(L("output")));
        master = new LedBar { Margin = new Thickness(0, 4, 0, 12) };
        top.Children.Add(master);
        var mon = new CheckBox { Content = L("monitor"), IsChecked = engine.MonitorMic, Margin = new Thickness(0, 0, 0, 12) };
        mon.Checked += (_, _) => engine.MonitorMic = true; mon.Unchecked += (_, _) => engine.MonitorMic = false;
        top.Children.Add(mon);
        dp.Children.Add(top);

        var bottom = new StackPanel { VerticalAlignment = VerticalAlignment.Bottom };
        var bleep = Btn("⊘  " + L("bleep"), true); bleep.Height = 56; bleep.FontSize = 16;
        bleep.PreviewMouseLeftButtonDown += (_, _) => { engine.Voice.Bleep = true; bleep.Tag = "on2"; };
        bleep.PreviewMouseLeftButtonUp += (_, _) => { engine.Voice.Bleep = false; bleep.Tag = null; };
        bleep.MouseLeave += (_, _) => { engine.Voice.Bleep = false; bleep.Tag = null; };
        bottom.Children.Add(bleep);
        micBtn = Btn("", false); micBtn.Height = 150; micBtn.FontSize = 18; micBtn.BorderThickness = new Thickness(2.5);
        micBtn.Click += (_, _) => { engine.Mic.Muted = !engine.Mic.Muted; Build(); };
        bottom.Children.Add(micBtn);
        dp.Children.Add(bottom);
        card.Child = dp;
        PaintMic();
        return card;
    }

    // ================= Behaviour =================
    void PaintMic()
    {
        if (micBtn == null) return;
        bool m = engine.Mic.Muted;
        var sp = new StackPanel();
        sp.Children.Add(Center(Txt(m ? "🔇" : "🎤", 44, m ? "Accent2" : "Accent1")));
        sp.Children.Add(Center(Txt(m ? L("micmuted") : L("mute"), 15, m ? "Accent2" : "Accent1", FontWeights.Bold)));
        micBtn.Content = sp;
        micBtn.SetResourceReference(Control.BorderBrushProperty, m ? "Accent2" : "Accent1");
        micBtn.Tag = m ? "on2" : null;
    }

    Knob MakeKnob(string key, string label, double min, double max, double def, Action<double> set, Func<double, string> fmt, bool big = false)
    {
        var k = new Knob(big) { Min = min, Max = max, Default = def, Label = label, Format = fmt, Margin = new Thickness(4) };
        double start = cfg.Values.TryGetValue(key, out var sv) ? sv : def;
        k.Changed += x => { set(x); cfg.Values[key] = (float)x; };
        k.Value = start;
        set(start);
        knobs[key] = k;
        return k;
    }

    void ApplyVoiceFromCfg()
    {
        var v = engine.Voice;
        float G(string k, float d) => cfg.Values.TryGetValue(k, out var x) ? x : d;
        v.Reverb = G("reverb", 0); v.Pitch = G("pitch", 0); v.Echo = G("echo", 0); v.NoiseStrength = G("noise", 50);
        v.Gain = G("gain", 0); v.Comp = G("comp", 30); v.Bass = G("bass", 0); v.Mid = G("mid", 0); v.Treble = G("treble", 0); v.EqDirty = true;
    }

    Button FxToggle(string text, Action flip, Func<bool> state)
    {
        var b = Btn(text, true); b.Height = 40;
        b.Tag = state() ? "on2" : null;
        b.Click += (_, _) => { flip(); b.Tag = state() ? "on2" : null; };
        return b;
    }

    void RefreshPads()
    {
        for (int i = 0; i < 3; i++) if (banks[i] != null) banks[i].Tag = i == bank ? "on2" : null;
        for (int i = 0; i < 4; i++)
        {
            if (pads[i] == null) continue;
            var path = cfg.Pads[bank * 4 + i];
            pads[i].Content = path != null ? System.IO.Path.GetFileNameWithoutExtension(path) : $"{(char)('A' + bank)}{i + 1} · {L("empty")}";
            pads[i].Tag = path != null ? "on" : null;
        }
    }

    void PlayPad(int i)
    {
        var path = cfg.Pads[bank * 4 + i];
        if (path == null) { AssignPad(i); return; }
        try { engine.PlaySample(path); } catch (Exception ex) { Status(L("error") + ex.Message); }
    }

    void AssignPad(int i)
    {
        var dlg = new OpenFileDialog { Filter = "Audio|*.wav;*.mp3;*.m4a;*.wma;*.aac;*.flac|*.*|*.*" };
        if (dlg.ShowDialog() != true) return;
        cfg.Pads[bank * 4 + i] = dlg.FileName; cfg.Save(); RefreshPads();
    }

    void LoadMusic()
    {
        var dlg = new OpenFileDialog { Filter = "Audio|*.mp3;*.wav;*.m4a;*.wma;*.aac;*.flac|*.*|*.*" };
        if (dlg.ShowDialog() != true) return;
        try { engine.Player.Load(dlg.FileName); if (musicName != null) musicName.Text = System.IO.Path.GetFileName(dlg.FileName); }
        catch (Exception ex) { Status(L("error") + ex.Message); }
    }

    int OutIndex(int slot) => cfg.Outputs.Take(slot).Count(o => o != null);

    void StartEngine()
    {
        try
        {
            var outs = new List<(string, float)>();
            for (int i = 0; i < 3; i++) if (cfg.Outputs[i] is string id) outs.Add((id, cfg.OutVolumes[i]));
            engine.Start(cfg.Mic, cfg.Line, outs);
            Status("ROX ✔");
        }
        catch (Exception ex) { engine.Stop(); Status(L("error") + ex.Message); }
        UpdateStart();
        cfg.Save();
    }

    void UpdateStart()
    {
        if (startBtn == null || statusPill == null) return;
        startBtn.Content = engine.Running ? L("stop") : L("start");
        startBtn.Tag = engine.Running ? "on" : null;
        statusPill.Text = engine.Running ? L("running") : L("idle");
        statusPill.SetResourceReference(TextBlock.ForegroundProperty, engine.Running ? "Accent1" : "Sub");
    }

    void Status(string s) { if (status != null) status.Text = s; }

    void Meters()
    {
        foreach (var (ch, f) in faders)
        {
            float p = ch.Peak; ch.Peak = 0;
            f.Level = Math.Max(Math.Sqrt(Math.Min(p, 1)), f.Level * 0.85);
        }
        float mp = engine.MasterPeak; engine.MasterPeak = 0;
        if (master != null) master.Level = Math.Max(Math.Sqrt(Math.Min(mp, 1)), master.Level * 0.85);
    }

    // ================= Helpers =================
    static Border Card(Thickness pad, double radius)
    {
        var b = new Border { Padding = pad, CornerRadius = new CornerRadius(radius) };
        b.SetResourceReference(Border.BackgroundProperty, "Panel");
        return b;
    }

    static TextBlock Txt(string t, double size, string brush, FontWeight? w = null)
    {
        var tb = new TextBlock { Text = t, FontSize = size, FontWeight = w ?? FontWeights.Normal };
        tb.SetResourceReference(TextBlock.ForegroundProperty, brush);
        return tb;
    }

    static TextBlock SectionTitle(string t)
    {
        var tb = Txt(t, 12, "Sub", FontWeights.Bold);
        tb.Margin = new Thickness(2, 0, 0, 8);
        return tb;
    }

    static T Center<T>(T e) where T : FrameworkElement { e.HorizontalAlignment = HorizontalAlignment.Center; return e; }

    static Button Btn(string text, bool second, double width = double.NaN)
    {
        var b = new Button { Content = text, Width = width };
        if (second) b.Style = (Style)Application.Current.FindResource("Btn2");
        return b;
    }
}
