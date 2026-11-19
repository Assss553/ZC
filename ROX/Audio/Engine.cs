using NAudio.CoreAudioApi;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace ROX.Audio;

public sealed record DeviceInfo(string Id, string Name) { public override string ToString() => Name; }

public sealed class AudioEngine : IDisposable
{
    public readonly Channel Mic = new("الميك"), Line = new("مدخل 2"), Music = new("الموسيقى"), Samples = new("المؤثرات");
    public readonly VoiceSettings Voice = new();
    public readonly MusicPlayer Player = new();
    public bool MonitorMic;
    public float MasterPeak;
    public bool Running { get; private set; }

    readonly Slot micSlot = new(Fmt.Stereo), lineSlot = new(Fmt.Stereo);
    readonly MixingSampleProvider sampleMix = new(Fmt.Stereo) { ReadFully = true };
    readonly Dictionary<string, float[]> cache = new();
    readonly List<Sink> sinks = new();
    WasapiCapture? micCap, lineCap;
    SmbPitchShiftingSampleProvider? pitch;

    sealed class Sink
    {
        public required WasapiOut Out;
        public required VolumeSampleProvider Vol;
        public BufferedWaveProvider? Buffer;
    }

    public static List<DeviceInfo> Devices(DataFlow flow)
    {
        using var en = new MMDeviceEnumerator();
        return en.EnumerateAudioEndPoints(flow, DeviceState.Active).Select(d => new DeviceInfo(d.ID, d.FriendlyName)).ToList();
    }

    static MMDevice Get(string id) { using var en = new MMDeviceEnumerator(); return en.GetDevice(id); }

    public void Start(string? micId, string? lineId, IList<(string id, float vol)> outputs)
    {
        Stop();
        if (outputs.Count == 0) throw new InvalidOperationException("اختر جهاز إخراج واحد على الأقل");

        // Mic chain: capture -> mono 48k -> clean -> pitch -> fx -> stereo
        if (micId != null)
        {
            var (cap, buf) = OpenCapture(micId);
            micCap = cap;
            ISampleProvider p = Fmt.Normalize(buf.ToSampleProvider(), 1);
            p = new VoiceCleaner(p, Voice);
            pitch = new SmbPitchShiftingSampleProvider(p) { PitchFactor = PitchFactor() };
            p = new VoiceEffects(pitch, Voice);
            micSlot.Set(new MonoToStereoSampleProvider(p));
        }
        if (lineId != null)
        {
            var (cap, buf) = OpenCapture(lineId);
            lineCap = cap;
            lineSlot.Set(Fmt.Normalize(buf.ToSampleProvider(), 2));
        }

        var bus = new Bus(this, new (ISampleProvider, bool)[]
        {
            (new ChannelStage(micSlot, Mic), true),
            (new ChannelStage(lineSlot, Line), false),
            (new ChannelStage(Player, Music), false),
            (new ChannelStage(sampleMix, Samples), false),
        });

        for (int i = 0; i < outputs.Count; i++)
        {
            var dev = Get(outputs[i].id);
            var wo = new WasapiOut(dev, AudioClientShareMode.Shared, true, 30);
            if (i == 0)
            {
                var vol = new VolumeSampleProvider(bus) { Volume = outputs[i].vol };
                wo.Init(vol);
                sinks.Add(new Sink { Out = wo, Vol = vol });
            }
            else
            {
                var buf = new BufferedWaveProvider(Fmt.Stereo) { DiscardOnBufferOverflow = true, BufferDuration = TimeSpan.FromSeconds(1) };
                var vol = new VolumeSampleProvider(buf.ToSampleProvider()) { Volume = outputs[i].vol };
                wo.Init(vol);
                sinks.Add(new Sink { Out = wo, Vol = vol, Buffer = buf });
            }
        }
        micCap?.StartRecording();
        lineCap?.StartRecording();
        foreach (var s in sinks) s.Out.Play();
        Running = true;
    }

    static (WasapiCapture, BufferedWaveProvider) OpenCapture(string id)
    {
        var cap = new WasapiCapture(Get(id), true, 10);
        var buf = new BufferedWaveProvider(cap.WaveFormat) { DiscardOnBufferOverflow = true, BufferDuration = TimeSpan.FromSeconds(1), ReadFully = true };
        cap.DataAvailable += (_, e) =>
        {
            if (buf.BufferedDuration.TotalMilliseconds > 120) buf.ClearBuffer(); // keep latency low
            buf.AddSamples(e.Buffer, 0, e.BytesRecorded);
        };
        return (cap, buf);
    }

    public void Stop()
    {
        Running = false;
        foreach (var s in sinks) { try { s.Out.Stop(); s.Out.Dispose(); } catch { } }
        sinks.Clear();
        foreach (var c in new[] { micCap, lineCap }) { try { c?.StopRecording(); c?.Dispose(); } catch { } }
        micCap = lineCap = null; pitch = null;
        micSlot.Set(null); lineSlot.Set(null);
    }

    float PitchFactor() => (float)Math.Pow(2, (Voice.FxOn ? Voice.Pitch : 0) / 12.0);
    public void UpdatePitch() { if (pitch != null) pitch.PitchFactor = PitchFactor(); }

    public void SetOutputVolume(int index, float v) { if (index < sinks.Count) sinks[index].Vol.Volume = v; }

    public void PlaySample(string path)
    {
        if (!cache.TryGetValue(path, out var data)) cache[path] = data = CachedSound.Load(path);
        sampleMix.AddMixerInput(new CachedSound(data));
    }

    public void StopSamples() => sampleMix.RemoveAllMixerInputs();

    public void Dispose() => Stop();

    /// Sums all channels. Output 1 (headphones) gets mic only when monitoring;
    /// extra outputs (e.g. virtual cable for Discord/OBS) always get the full mix.
    sealed class Bus : ISampleProvider
    {
        readonly AudioEngine e; readonly (ISampleProvider p, bool isMic)[] inputs;
        float[] tmp = new float[0], stream = new float[0]; byte[] bytes = new byte[0];
        public Bus(AudioEngine engine, (ISampleProvider, bool)[] ins) { e = engine; inputs = ins; }
        public WaveFormat WaveFormat => Fmt.Stereo;

        public int Read(float[] b, int o, int c)
        {
            if (tmp.Length < c) { tmp = new float[c]; stream = new float[c]; bytes = new byte[c * 4]; }
            Array.Clear(b, o, c); Array.Clear(stream, 0, c);
            foreach (var (p, isMic) in inputs)
            {
                p.Read(tmp, 0, c);
                bool toPhones = !isMic || e.MonitorMic;
                for (int i = 0; i < c; i++)
                {
                    stream[i] += tmp[i];
                    if (toPhones) b[o + i] += tmp[i];
                }
            }
            float peak = 0;
            for (int i = 0; i < c; i++)
            {
                b[o + i] = Limit(b[o + i]);
                stream[i] = Limit(stream[i]);
                float a = Math.Abs(stream[i]); if (a > peak) peak = a;
            }
            if (peak > e.MasterPeak) e.MasterPeak = peak;

            Buffer.BlockCopy(stream, 0, bytes, 0, c * 4);
            for (int k = 1; k < e.sinks.Count; k++)
            {
                var buf = e.sinks[k].Buffer!;
                if (buf.BufferedDuration.TotalMilliseconds > 150) buf.ClearBuffer();
                buf.AddSamples(bytes, 0, c * 4);
            }
            return c;
        }

        static float Limit(float x) => Math.Abs(x) < 0.9f ? x : Math.Sign(x) * (0.9f + 0.1f * (float)Math.Tanh((Math.Abs(x) - 0.9f) * 10));
    }
}
