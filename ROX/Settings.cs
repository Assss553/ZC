using System.IO;
using System.Text.Json;

namespace ROX;

public sealed class Settings
{
    public string? Mic { get; set; }
    public string? Line { get; set; }
    public List<string?> Outputs { get; set; } = new() { null, null, null };
    public List<float> OutVolumes { get; set; } = new() { 1, 1, 1 };
    public Dictionary<string, float> Values { get; set; } = new();
    public List<string?> Pads { get; set; } = Enumerable.Repeat<string?>(null, 12).ToList();
    public List<Dictionary<string, float>?> FxPresets { get; set; } = Enumerable.Repeat<Dictionary<string, float>?>(null, 6).ToList();
    public List<string> Transitions { get; set; } = new();
    public string StageBg { get; set; } = "green";
    public bool TransitionSound { get; set; } = true;
    public string Language { get; set; } = "en";
    public ThemeColors Theme { get; set; } = ThemeColors.Presets[0].Clone();
    public bool Monitor { get; set; }

    static string PathFile => System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ROX", "settings.json");

    public static Settings Load()
    {
        try
        {
            var s = JsonSerializer.Deserialize<Settings>(File.ReadAllText(PathFile)) ?? new();
            while (s.Pads.Count < 12) s.Pads.Add(null);
            while (s.FxPresets.Count < 6) s.FxPresets.Add(null);
            while (s.Outputs.Count < 3) s.Outputs.Add(null);
            while (s.OutVolumes.Count < 3) s.OutVolumes.Add(1);
            return s;
        }
        catch { return new(); }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(System.IO.Path.GetDirectoryName(PathFile)!);
            File.WriteAllText(PathFile, JsonSerializer.Serialize(this, new JsonSerializerOptions { WriteIndented = true }));
        }
        catch { }
    }
}
