using NAudio.Wave;

namespace ROX.Audio;

/// Spectral noise suppression (adaptive noise floor + Wiener-style gain), 48 kHz mono.
/// Removes steady background noise (fans, AC, PC hum, hiss) even while you talk.
public sealed class Denoiser : ISampleProvider
{
    const int N = 1024, Hop = N / 2, Latency = N - Hop;
    readonly ISampleProvider src; readonly VoiceSettings s;
    readonly float[] win = new float[N], inFifo = new float[N], outFifo = new float[N], accum = new float[N * 2];
    readonly float[] re = new float[N], im = new float[N];
    readonly float[] noise = new float[N / 2 + 1], gain = new float[N / 2 + 1], prevPow = new float[N / 2 + 1];
    int rover = Latency; long frames;

    public Denoiser(ISampleProvider source, VoiceSettings settings)
    {
        src = source; s = settings;
        for (int k = 0; k < N; k++) win[k] = (float)Math.Sqrt(0.5 - 0.5 * Math.Cos(2 * Math.PI * k / N));
        Array.Fill(gain, 1f);
    }
    public WaveFormat WaveFormat => src.WaveFormat;

    public int Read(float[] b, int o, int c)
    {
        int n = src.Read(b, o, c);
        for (int i = 0; i < n; i++)
        {
            inFifo[rover] = b[o + i];
            b[o + i] = outFifo[rover - Latency];
            if (++rover >= N) { rover = Latency; Frame(); }
        }
        return n;
    }

    void Frame()
    {
        for (int k = 0; k < N; k++) { re[k] = inFifo[k] * win[k]; im[k] = 0; }
        Fft(re, im, false);

        float strength = s.NoiseStrength / 100f;
        float over = 1f + strength * 3f;                         // over-subtraction
        float floor = Fmt.Db(-6 - strength * 24);                // max attenuation -6..-30 dB
        bool learning = frames++ < 40;                           // first ~0.4 s: learn fast

        for (int k = 0; k <= N / 2; k++)
        {
            float p = re[k] * re[k] + im[k] * im[k];
            float sp = 0.5f * prevPow[k] + 0.5f * p; prevPow[k] = sp;
            // minimum-tracking noise floor: drops fast, rises slowly
            if (learning) noise[k] = noise[k] == 0 ? sp : 0.8f * noise[k] + 0.2f * sp;
            else if (sp < noise[k]) noise[k] = 0.85f * noise[k] + 0.15f * sp;
            else noise[k] *= 1.004f;

            float g = strength <= 0 ? 1 : Math.Max(floor, 1 - over * noise[k] / (sp + 1e-12f));
            g = g > gain[k] ? 0.5f * gain[k] + 0.5f * g : 0.75f * gain[k] + 0.25f * g; // fast attack, smooth release
            gain[k] = g;
            re[k] *= g; im[k] *= g;
            if (k > 0 && k < N / 2) { re[N - k] = re[k]; im[N - k] = -im[k]; }
        }
        Fft(re, im, true);

        for (int k = 0; k < N; k++) accum[k] += re[k] * win[k];
        Array.Copy(accum, outFifo, Hop);
        Array.Copy(accum, Hop, accum, 0, N);
        Array.Clear(accum, N, Hop);
        Array.Copy(inFifo, Hop, inFifo, 0, Latency);
    }

    static void Fft(float[] re, float[] im, bool inverse)
    {
        int n = re.Length;
        for (int i = 1, j = 0; i < n; i++)
        {
            int bit = n >> 1;
            for (; (j & bit) != 0; bit >>= 1) j ^= bit;
            j ^= bit;
            if (i < j) { (re[i], re[j]) = (re[j], re[i]); (im[i], im[j]) = (im[j], im[i]); }
        }
        for (int len = 2; len <= n; len <<= 1)
        {
            double ang = 2 * Math.PI / len * (inverse ? 1 : -1);
            float wr = (float)Math.Cos(ang), wi = (float)Math.Sin(ang);
            for (int i = 0; i < n; i += len)
            {
                float cr = 1, ci = 0;
                for (int k = 0; k < len / 2; k++)
                {
                    int a = i + k, bb = a + len / 2;
                    float tr = re[bb] * cr - im[bb] * ci, ti = re[bb] * ci + im[bb] * cr;
                    re[bb] = re[a] - tr; im[bb] = im[a] - ti;
                    re[a] += tr; im[a] += ti;
                    float ncr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = ncr;
                }
            }
        }
        if (inverse) for (int i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
    }
}
