using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace ROX.Audio;

public sealed class Channel
{
    public string Name { get; }
    public float Volume = 0.8f;
    public bool Muted;
    public float Peak;
    public Channel(string name) => Name = name;
}

public static class Fmt
{
    public const int Rate = 48000;
    public static WaveFormat Mono => WaveFormat.CreateIeeeFloatWaveFormat(Rate, 1);
    public static WaveFormat Stereo => WaveFormat.CreateIeeeFloatWaveFormat(Rate, 2);

    /// Converts any source to 48 kHz float with the requested channel count (1 or 2).
    public static ISampleProvider Normalize(ISampleProvider s, int channels)
    {
        if (s.WaveFormat.Channels != 1) s = new ToMono(s);
        if (s.WaveFormat.SampleRate != Rate) s = new WdlResamplingSampleProvider(s, Rate);
        if (channels == 2) s = new MonoToStereoSampleProvider(s);
        return s;
    }

    public static float Db(float db) => (float)Math.Pow(10, db / 20.0);
}

public sealed class ToMono : ISampleProvider
{
    readonly ISampleProvider src; readonly int ch; float[] tmp = new float[0];
    public ToMono(ISampleProvider s) { src = s; ch = s.WaveFormat.Channels; WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(s.WaveFormat.SampleRate, 1); }
    public WaveFormat WaveFormat { get; }
    public int Read(float[] b, int o, int c)
    {
        int need = c * ch;
        if (tmp.Length < need) tmp = new float[need];
        int n = src.Read(tmp, 0, need) / ch;
        for (int f = 0; f < n; f++)
        {
            float sum = 0;
            for (int k = 0; k < ch; k++) sum += tmp[f * ch + k];
            b[o + f] = sum / ch;
        }
        return n;
    }
}

/// Swappable source that always returns a full buffer (silence when empty).
public sealed class Slot : ISampleProvider
{
    readonly object gate = new();
    ISampleProvider? inner;
    public Slot(WaveFormat wf) => WaveFormat = wf;
    public WaveFormat WaveFormat { get; }
    public void Set(ISampleProvider? p) { lock (gate) inner = p; }
    public int Read(float[] b, int o, int c)
    {
        int n = 0;
        lock (gate) if (inner != null) n = inner.Read(b, o, c);
        if (n < c) Array.Clear(b, o + n, c - n);
        return c;
    }
}

/// Applies channel volume/mute and records peak level for meters.
public sealed class ChannelStage : ISampleProvider
{
    readonly ISampleProvider src; readonly Channel ch;
    public ChannelStage(ISampleProvider s, Channel c) { src = s; ch = c; }
    public WaveFormat WaveFormat => src.WaveFormat;
    public int Read(float[] b, int o, int c)
    {
        int n = src.Read(b, o, c);
        float g = ch.Muted ? 0 : ch.Volume * ch.Volume * 1.5f; // perceptual curve, up to +3.5 dB
        float p = 0;
        for (int i = 0; i < n; i++)
        {
            float x = b[o + i] * g; b[o + i] = x;
            float a = Math.Abs(x); if (a > p) p = a;
        }
        if (p > ch.Peak) ch.Peak = p;
        return n;
    }
}

public sealed class MusicPlayer : ISampleProvider
{
    readonly object gate = new();
    AudioFileReader? reader; ISampleProvider? chain;
    public bool Playing;
    public string? File { get; private set; }
    public WaveFormat WaveFormat => Fmt.Stereo;

    public void Load(string path)
    {
        var r = new AudioFileReader(path);
        lock (gate) { reader?.Dispose(); reader = r; chain = Fmt.Normalize(r, 2); File = path; Playing = true; }
    }

    public int Read(float[] b, int o, int c)
    {
        int n = 0;
        lock (gate)
        {
            if (Playing && chain != null)
            {
                n = chain.Read(b, o, c);
                if (n < c && reader != null) reader.Position = 0; // loop
            }
        }
        if (n < c) Array.Clear(b, o + n, c - n);
        return c;
    }
}

public sealed class CachedSound : ISampleProvider
{
    readonly float[] data; int pos;
    public CachedSound(float[] d) => data = d;
    public WaveFormat WaveFormat => Fmt.Stereo;
    public int Read(float[] b, int o, int c)
    {
        int n = Math.Min(c, data.Length - pos);
        Array.Copy(data, pos, b, o, n); pos += n;
        return n;
    }

    public static float[] Load(string path)
    {
        using var r = new AudioFileReader(path);
        var p = Fmt.Normalize(r, 2);
        var all = new List<float>(); var buf = new float[48000];
        int n;
        while ((n = p.Read(buf, 0, buf.Length)) > 0) all.AddRange(buf.AsSpan(0, n).ToArray());
        return all.ToArray();
    }
}
