using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Microsoft.Win32;
using NAudio.CoreAudioApi;
using ROX.Audio;

namespace ROX;

public partial class MainWindow : Window
{
    readonly AudioEngine engine = new();
    readonly Settings cfg = Settings.Load();
    readonly ComboBox micBox = Combo(), lineBox = Combo();
    readonly ComboBox[] outBoxes = { Combo(), Combo(), Combo() };
    readonly Slider[] outVols = new Slider[3];
    readonly Button startBtn = new() { Content = "▶ تشغيل", FontWeight = FontWeights.Bold };
    readonly List<(Channel ch, ProgressBar meter)> meters = new();
    readonly Dictionary<string, Slider> knobs = new();
    static readonly DeviceInfo None = new("", "— بدون —");
    bool loading = true;

    static readonly Brush Cyan = new SolidColorBrush(Color.FromRgb(0x19, 0xE6, 0xE6));
    static readonly Brush Pink = new SolidColorBrush(Color.FromRgb(0xE0, 0x40, 0xFB));
    static readonly Brush Red = new SolidColorBrush(Color.FromRgb(0xFF, 0x4D, 0x6D));

    public MainWindow()
    {
        InitializeComponent();
        BuildDevices();
        BuildStrips();
        BuildKnobs();
        BuildFx();
        BuildPads();
        WireRight();
        loading = false;

        var timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(40) };
        timer.Tick += (_, _) => UpdateMeters();
        timer.Start();
        Closing += (_, _) => { SaveAll(); engine.Dispose(); };
        Status.Text = "اختر الميك والسماعة ثم اضغط تشغيل. للبث/ديسكورد: اختر كابل افتراضي (VB-Cable) في الإخراج 2.";
    }

    static ComboBox Combo() => new() { MinWidth = 190 };

    // ---------- Devices ----------
    void BuildDevices()
    {
        var ins = AudioEngine.Devices(DataFlow.Capture);
        var outs = AudioEngine.Devices(DataFlow.Render);
        Fill(micBox, ins, cfg.Mic, true);
        Fill(lineBox, ins, cfg.Line, false);
        string[] labels = { "🎧 السماعة", "📡 إخراج 2", "🔊 إخراج 3" };
        Add("🎤 الميك", micBox);
        Add("مدخل 2", lineBox);
        for (int i = 0; i < 3; i++)
        {
            Fill(outBoxes[i], outs, cfg.Outputs.ElementAtOrDefault(i), i == 0);
            int idx = i;
            outVols[i] = new Slider { Minimum = 0, Maximum = 1.5, Value = cfg.OutVolumes.ElementAtOrDefault(i) is var v && v > 0 ? v : 1, Width = 80, VerticalAlignment = VerticalAlignment.Center, ToolTip = "مستوى الصوت" };
            outVols[i].ValueChanged += (_, e) => engine.SetOutputVolume(OutIndex(idx), (float)e.NewValue);
            var sp = new StackPanel { Orientation = Orientation.Horizontal };
            sp.Children.Add(outBoxes[i]); sp.Children.Add(outVols[i]);
            Add(labels[i], sp);
        }
        var mon = new CheckBox { Content = "اسمع صوتي بالسماعة", IsChecked = cfg.Monitor, VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(8, 0, 8, 0) };
        engine.MonitorMic = cfg.Monitor;
        mon.Checked += (_, _) => engine.MonitorMic = true;
        mon.Unchecked += (_, _) => engine.MonitorMic = false;
        DevicePanel.Children.Add(mon);
        startBtn.Click += (_, _) => { if (engine.Running) { engine.Stop(); startBtn.Content = "▶ تشغيل"; } else StartEngine(); };
        DevicePanel.Children.Add(startBtn);

        foreach (var cb in outBoxes.Append(micBox).Append(lineBox))
            cb.SelectionChanged += (_, _) => { if (!loading && engine.Running) StartEngine(); };

        void Add(string label, UIElement el)
        {
            var sp = new StackPanel { Margin = new Thickness(4) };
            sp.Children.Add(new TextBlock { Text = label, FontSize = 11, Foreground = Brushes.Gray });
            sp.Children.Add(el);
            DevicePanel.Children.Add(sp);
        }
    }

    static void Fill(ComboBox box, List<DeviceInfo> devs, string? saved, bool pickFirst)
    {
        box.Items.Add(None);
        foreach (var d in devs) box.Items.Add(d);
        var match = devs.FirstOrDefault(d => d.Id == saved);
        box.SelectedItem = match ?? (pickFirst && devs.Count > 0 && saved == null ? devs[0] : None);
    }

    static string? Id(ComboBox b) => b.SelectedItem is DeviceInfo d && d.Id != "" ? d.Id : null;

    // engine sink index for UI output slot (skips empty slots)
    int OutIndex(int slot) => outBoxes.Take(slot).Count(b => Id(b) != null);

    void StartEngine()
    {
        try
        {
            var outs = new List<(string, float)>();
            for (int i = 0; i < 3; i++) if (Id(outBoxes[i]) is string id) outs.Add((id, (float)outVols[i].Value));
            engine.Start(Id(micBox), Id(lineBox), outs);
            startBtn.Content = "⏹ إيقاف";
            Status.Text = "ROX شغال ✔";
            SaveAll();
        }
        catch (Exception ex)
        {
            engine.Stop();
            startBtn.Content = "▶ تشغيل";
            Status.Text = "خطأ: " + ex.Message;
        }
    }

    // ---------- Fader strips ----------
    void BuildStrips()
    {
        foreach (var ch in new[] { engine.Mic, engine.Line, engine.Music, engine.Samples })
        {
            var key = "vol_" + ch.Name;
            if (cfg.Values.TryGetValue(key, out var v)) ch.Volume = v;
            var meter = new ProgressBar { Orientation = Orientation.Vertical, Width = 10, Height = 300, Maximum = 1, Foreground = Pink, Background = new SolidColorBrush(Color.FromRgb(0x2A, 0x2A, 0x38)), BorderThickness = new Thickness(0), Margin = new Thickness(2) };
            var fader = new Slider { Orientation = Orientation.Vertical, Height = 300, Minimum = 0, Maximum = 1, Value = ch.Volume, Margin = new Thickness(2) };
            fader.ValueChanged += (_, e) => { ch.Volume = (float)e.NewValue; cfg.Values[key] = ch.Volume; };
            var mute = new Button { Content = "🔈", Padding = new Thickness(6, 4, 6, 4) };
            mute.Click += (_, _) => { ch.Muted = !ch.Muted; mute.Content = ch.Muted ? "🔇" : "🔈"; mute.BorderBrush = ch.Muted ? Red : Cyan; };
            var row = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center };
            row.Children.Add(fader); row.Children.Add(meter);
            var strip = new StackPanel { Margin = new Thickness(6, 0, 6, 0), Width = 70 };
            strip.Children.Add(new TextBlock { Text = ch.Name, HorizontalAlignment = HorizontalAlignment.Center, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 6) });
            strip.Children.Add(row);
            strip.Children.Add(mute);
            Strips.Children.Add(strip);
            meters.Add((ch, meter));
        }
    }

    // ---------- Knobs ----------
    void BuildKnobs()
    {
        var s = engine.Voice;
        Knob("noise", "🛡 عزل الضوضاء", 0, 100, s.NoiseStrength, v => s.NoiseStrength = v, "%");
        Knob("comp", "🎚 الضغط (Compressor)", 0, 100, s.Comp, v => s.Comp = v, "%");
        Knob("gain", "🔊 تكبير الميك", -12, 24, s.Gain, v => s.Gain = v, " dB");
        Knob("pitch", "🎵 طبقة الصوت (Pitch)", -12, 12, s.Pitch, v => { s.Pitch = (float)Math.Round(v); engine.UpdatePitch(); }, "");
        Knob("bass", "Bass", -12, 12, s.Bass, v => { s.Bass = v; s.EqDirty = true; }, " dB");
        Knob("mid", "Mid", -12, 12, s.Mid, v => { s.Mid = v; s.EqDirty = true; }, " dB");
        Knob("treble", "Treble", -12, 12, s.Treble, v => { s.Treble = v; s.EqDirty = true; }, " dB");
        Knob("reverb", "🌊 صدى القاعة (Reverb)", 0, 100, s.Reverb, v => s.Reverb = v, "%");
        Knob("echo", "🔁 الإيكو (Echo)", 0, 100, s.Echo, v => s.Echo = v, "%");
    }

    void Knob(string key, string label, double min, double max, float def, Action<float> set, string unit)
    {
        double val = cfg.Values.TryGetValue(key, out var sv) ? sv : def;
        var title = new TextBlock();
        var sl = new Slider { Minimum = min, Maximum = max, Value = val, Margin = new Thickness(0, 2, 0, 0) };
        void Apply(double v) { set((float)v); cfg.Values[key] = (float)v; title.Text = $"{label}:  {v:0}{unit}"; }
        sl.ValueChanged += (_, e) => Apply(e.NewValue);
        Apply(val);
        var box = new Border { Background = new SolidColorBrush(Color.FromRgb(0x24, 0x24, 0x31)), CornerRadius = new CornerRadius(8), Padding = new Thickness(10), Margin = new Thickness(4) };
        var sp = new StackPanel(); sp.Children.Add(title); sp.Children.Add(sl);
        box.Child = sp;
        Knobs.Children.Add(box);
        knobs[key] = sl;
    }

    // ---------- FX buttons ----------
    void BuildFx()
    {
        var s = engine.Voice;
        Toggle("📢 Megaphone", () => s.Megaphone = !s.Megaphone, () => s.Megaphone);
        Toggle("🤖 Robot", () => s.Robot = !s.Robot, () => s.Robot);
        Preset("👹 صوت وحش", -6, 30);
        Preset("🐿 صوت سنجاب", 7, 0);
        Preset("🎙 مذيع", -2, 10, bass: 5, comp: 70);
        Preset("↺ طبيعي", 0, 0);
        Toggle("FX ✔", () => { s.FxOn = !s.FxOn; engine.UpdatePitch(); }, () => s.FxOn);
    }

    void Toggle(string text, Action flip, Func<bool> state)
    {
        var b = new Button { Content = text, MinWidth = 110 };
        void Paint() { b.Background = state() ? new SolidColorBrush(Color.FromRgb(0x10, 0x4A, 0x4F)) : new SolidColorBrush(Color.FromRgb(0x22, 0x22, 0x2E)); }
        b.Click += (_, _) => { flip(); Paint(); };
        Paint();
        FxButtons.Children.Add(b);
    }

    void Preset(string text, double pitch, double reverb, double bass = 0, double comp = 30)
    {
        var b = new Button { Content = text, MinWidth = 110, Foreground = Pink, BorderBrush = Pink };
        b.Click += (_, _) =>
        {
            knobs["pitch"].Value = pitch; knobs["reverb"].Value = reverb;
            knobs["bass"].Value = bass; knobs["comp"].Value = comp;
            if (pitch == 0 && reverb == 0) { knobs["echo"].Value = 0; knobs["mid"].Value = 0; knobs["treble"].Value = 0; engine.Voice.Megaphone = engine.Voice.Robot = false; }
        };
        FxButtons.Children.Add(b);
    }

    // ---------- Pads ----------
    void BuildPads()
    {
        for (int i = 0; i < cfg.Pads.Count; i++)
        {
            int idx = i;
            var b = new Button { Height = 52 };
            void Label() => b.Content = cfg.Pads[idx] is string p ? System.IO.Path.GetFileNameWithoutExtension(p) : $"زر {idx + 1}";
            Label();
            b.Click += (_, _) =>
            {
                if (cfg.Pads[idx] is not string p) { Choose(); return; }
                try { engine.PlaySample(p); } catch (Exception ex) { Status.Text = "خطأ بالملف: " + ex.Message; }
            };
            b.MouseRightButtonUp += (_, _) => Choose();
            void Choose()
            {
                var dlg = new OpenFileDialog { Filter = "ملفات صوت|*.wav;*.mp3;*.m4a;*.wma;*.aac|الكل|*.*" };
                if (dlg.ShowDialog() == true) { cfg.Pads[idx] = dlg.FileName; Label(); SaveAll(); }
            }
            Pads.Children.Add(b);
        }
        StopPads.Click += (_, _) => engine.StopSamples();
    }

    void WireRight()
    {
        LoadMusic.Click += (_, _) =>
        {
            var dlg = new OpenFileDialog { Filter = "ملفات صوت|*.mp3;*.wav;*.m4a;*.wma;*.aac;*.flac|الكل|*.*" };
            if (dlg.ShowDialog() != true) return;
            try { engine.Player.Load(dlg.FileName); MusicName.Text = System.IO.Path.GetFileName(dlg.FileName); }
            catch (Exception ex) { Status.Text = "خطأ بالملف: " + ex.Message; }
        };
        PlayMusic.Click += (_, _) => engine.Player.Playing = !engine.Player.Playing;
        Bleep.PreviewMouseLeftButtonDown += (_, _) => engine.Voice.Bleep = true;
        Bleep.PreviewMouseLeftButtonUp += (_, _) => engine.Voice.Bleep = false;
        Bleep.MouseLeave += (_, _) => engine.Voice.Bleep = false;
        MicMute.Click += (_, _) =>
        {
            engine.Mic.Muted = !engine.Mic.Muted;
            MicMute.Content = engine.Mic.Muted ? "🔇 الميك مكتوم" : "🎤 كتم الميك";
            MicMute.BorderBrush = engine.Mic.Muted ? Red : Cyan;
            MicMute.Foreground = engine.Mic.Muted ? Red : Cyan;
        };
    }

    void UpdateMeters()
    {
        foreach (var (ch, m) in meters)
        {
            float p = ch.Peak; ch.Peak = 0;
            m.Value = Math.Max(Math.Sqrt(Math.Min(p, 1)), m.Value * 0.8);
        }
        float mp = engine.MasterPeak; engine.MasterPeak = 0;
        MasterMeter.Value = Math.Max(Math.Sqrt(Math.Min(mp, 1)), MasterMeter.Value * 0.8);
    }

    void SaveAll()
    {
        cfg.Mic = Id(micBox); cfg.Line = Id(lineBox);
        cfg.Outputs = outBoxes.Select(Id).ToList();
        cfg.OutVolumes = outVols.Select(s => (float)s.Value).ToList();
        cfg.Monitor = engine.MonitorMic;
        cfg.Save();
    }
}
