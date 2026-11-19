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
    public List<string?> Pads { get; set; } = new() { null, null, null, null, null, null, null, null };
    public bool Monitor { get; set; }

    static string PathFile => System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ROX", "settings.json");

    public static Settings Load()
    {
        try { return JsonSerializer.Deserialize<Settings>(File.ReadAllText(PathFile)) ?? new(); }
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
