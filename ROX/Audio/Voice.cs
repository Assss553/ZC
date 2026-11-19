using NAudio.Dsp;
using NAudio.Wave;

namespace ROX.Audio;

public sealed class VoiceSettings
{
    public float NoiseStrength = 50; // 0..100 noise isolation
    public float Bass, Mid, Treble;  // dB -12..12
    public float Comp = 30;          // 0..100
    public float Gain;               // dB -12..24
    public float Reverb, Echo;       // 0..100
    public float Pitch;              // semitones -12..12
    public bool Megaphone, Robot, Bleep, FxOn = true;
    public volatile bool EqDirty = true;
    public float GateOpen;           // 0..1 for UI
}

/// High-pass, noise gate/isolation, 3-band EQ, compressor, gain.
public sealed class VoiceCleaner : ISampleProvider
{
    readonly ISampleProvider src; readonly VoiceSettings s;
    BiQuadFilter hpf = BiQuadFilter.HighPassFilter(Fmt.Rate, 90, 0.707f);
    BiQuadFilter? lo, mi, hi;
    float env, gateGain = 1, compEnv; int hold;

    public VoiceCleaner(ISampleProvider source, VoiceSettings settings) { src = source; s = settings; }
    public WaveFormat WaveFormat => src.WaveFormat;

    public int Read(float[] b, int o, int c)
    {
        int n = src.Read(b, o, c);
        if (s.EqDirty || lo == null)
        {
            lo = BiQuadFilter.LowShelf(Fmt.Rate, 150, 1, s.Bass);
            mi = BiQuadFilter.PeakingEQ(Fmt.Rate, 1200, 0.8f, s.Mid);
            hi = BiQuadFilter.HighShelf(Fmt.Rate, 5000, 1, s.Treble);
            s.EqDirty = false;
        }
        float strength = s.NoiseStrength;
        float thr = Fmt.Db(-66 + strength * 0.4f);       // -66 dB .. -26 dB
        float comp = s.Comp;
        float cThr = -10 - comp * 0.2f, ratio = 1 + comp * 0.07f, makeup = comp * 0.1f;
        float gain = s.Gain;

        for (int i = 0; i < n; i++)
        {
            float x = hpf.Transform(b[o + i]);

            float a = Math.Abs(x);
            env += (a - env) * (a > env ? 0.02f : 0.0004f);
            if (strength <= 0 || env >= thr) hold = 9600; else if (hold > 0) hold--;
            float target = hold > 0 ? 1f : (1 - strength / 100f) * 0.05f;
            gateGain += (target - gateGain) * (target > gateGain ? 0.01f : 0.0006f);
            x *= gateGain;

            x = hi!.Transform(mi!.Transform(lo.Transform(x)));

            float ax = Math.Abs(x);
            compEnv += (ax - compEnv) * (ax > compEnv ? 0.005f : 0.0002f);
            float lvl = 20f * (float)Math.Log10(compEnv + 1e-9);
            float gr = lvl > cThr ? -(lvl - cThr) * (1 - 1 / ratio) : 0;
            x *= Fmt.Db(gr + makeup + gain);

            b[o + i] = x;
        }
        s.GateOpen = gateGain;
        return n;
    }
}

/// Megaphone, robot, echo, reverb and bleep.
public sealed class VoiceEffects : ISampleProvider
{
    readonly ISampleProvider src; readonly VoiceSettings s;
    readonly BiQuadFilter megHp = BiQuadFilter.HighPassFilter(Fmt.Rate, 600, 0.7f);
    readonly BiQuadFilter megLp = BiQuadFilter.LowPassFilter(Fmt.Rate, 3200, 0.7f);
    readonly float[] echoBuf = new float[Fmt.Rate]; int echoPos;
    readonly Comb[] combs; readonly AllPass[] alls;
    double robotPh, bleepPh;

    public VoiceEffects(ISampleProvider source, VoiceSettings settings)
    {
        src = source; s = settings;
        combs = new[] { 1557, 1617, 1491, 1422, 1277, 1356 }.Select(l => new Comb(l * 48 / 44)).ToArray();
        alls = new[] { 556, 441, 341 }.Select(l => new AllPass(l * 48 / 44)).ToArray();
    }
    public WaveFormat WaveFormat => src.WaveFormat;

    public int Read(float[] b, int o, int c)
    {
        int n = src.Read(b, o, c);
        bool fx = s.FxOn;
        float echoMix = fx ? s.Echo / 100f * 0.6f : 0, echoFb = 0.25f + s.Echo * 0.004f;
        int echoLen = (int)(Fmt.Rate * 0.32);
        float revMix = fx ? s.Reverb / 100f * 0.45f : 0;

        for (int i = 0; i < n; i++)
        {
            float x = b[o + i];
            if (fx && s.Megaphone) x = (float)Math.Tanh(megLp.Transform(megHp.Transform(x)) * 6) * 0.35f;
            if (fx && s.Robot)
            {
                robotPh += 2 * Math.PI * 70 / Fmt.Rate;
                x *= (float)Math.Sin(robotPh) * 1.6f;
            }

            int rp = (echoPos - echoLen + echoBuf.Length) % echoBuf.Length;
            float d = echoBuf[rp];
            echoBuf[echoPos] = x + d * echoFb * (echoMix > 0 ? 1 : 0);
            echoPos = (echoPos + 1) % echoBuf.Length;
            x += d * echoMix;

            if (revMix > 0)
            {
                float r = 0;
                foreach (var cb in combs) r += cb.Process(x * 0.15f);
                foreach (var ap in alls) r = ap.Process(r);
                x += r * revMix;
            }

            if (s.Bleep)
            {
                bleepPh += 2 * Math.PI * 1000 / Fmt.Rate;
                x = (float)Math.Sin(bleepPh) * 0.25f;
            }
            b[o + i] = x;
        }
        if (robotPh > 1e6) robotPh = 0;
        if (bleepPh > 1e6) bleepPh = 0;
        return n;
    }

    sealed class Comb
    {
        readonly float[] buf; int p; float store;
        public Comb(int len) => buf = new float[len];
        public float Process(float x)
        {
            float y = buf[p];
            store = y * 0.75f + store * 0.25f; // damping
            buf[p] = x + store * 0.82f;
            p = (p + 1) % buf.Length;
            return y;
        }
    }

    sealed class AllPass
    {
        readonly float[] buf; int p;
        public AllPass(int len) => buf = new float[len];
        public float Process(float x)
        {
            float bo = buf[p];
            buf[p] = x + bo * 0.5f;
            p = (p + 1) % buf.Length;
            return bo - x;
        }
    }
}
