using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Media;

namespace ROX;

static class Draw
{
    public static void Text(DrawingContext dc, Visual v, string s, double size, Color c, Point center, bool bold = false)
    {
        var ft = new FormattedText(s, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight,
            new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, bold ? FontWeights.Bold : FontWeights.SemiBold, FontStretches.Normal),
            size, new SolidColorBrush(c), VisualTreeHelper.GetDpi(v).PixelsPerDip);
        dc.DrawText(ft, new Point(center.X - ft.Width / 2, center.Y - ft.Height / 2));
    }

    public static Point Polar(Point c, double r, double deg)
    {
        double a = deg * Math.PI / 180;
        return new Point(c.X + r * Math.Cos(a), c.Y + r * Math.Sin(a));
    }

    public static Geometry Arc(Point c, double r, double from, double to)
    {
        var g = new StreamGeometry();
        using (var ctx = g.Open())
        {
            ctx.BeginFigure(Polar(c, r, from), false, false);
            ctx.ArcTo(Polar(c, r, to), new Size(r, r), 0, to - from > 180, SweepDirection.Clockwise, true, false);
        }
        g.Freeze();
        return g;
    }

    public static Color Lerp(Color a, Color b, double t) =>
        Color.FromRgb((byte)(a.R + (b.R - a.R) * t), (byte)(a.G + (b.G - a.G) * t), (byte)(a.B + (b.B - a.B) * t));
    public static Color Dim(Color c, byte a) => Color.FromArgb(a, c.R, c.G, c.B);
}

/// Rotary knob with LED ring. Drag up/down or scroll; double-click resets.
public sealed class Knob : FrameworkElement
{
    public double Min, Max, Default; double value;
    public string Label = "";
    public Func<double, string> Format = v => v.ToString("0");
    public double Step = 1;
    public event Action<double>? Changed;
    public bool Big;
    Point? drag; double dragStart;

    public Knob(bool big = false)
    {
        Big = big;
        Width = big ? 120 : 84; Height = big ? 138 : 100;
        Cursor = Cursors.SizeNS; FlowDirection = FlowDirection.LeftToRight;
        ThemeManager.Changed += InvalidateVisual;
        ToolTip = "Drag / scroll — double-click to reset";
    }

    public double Value
    {
        get => value;
        set { var v = Math.Clamp(value, Min, Max); if (v == this.value) return; this.value = v; InvalidateVisual(); Changed?.Invoke(v); }
    }

    protected override void OnRender(DrawingContext dc)
    {
        double s = Big ? 1.35 : 1;
        var c = new Point(Width / 2, 42 * s);
        double r = 26 * s;
        var a1 = ThemeManager.A1; var a2 = ThemeManager.A2;
        double frac = (value - Min) / (Max - Min);

        // LED dots ring
        int dots = 17;
        for (int i = 0; i < dots; i++)
        {
            double t = i / (double)(dots - 1);
            var p = Draw.Polar(c, r + 10 * s, 135 + 270 * t);
            bool lit = t <= frac + 1e-6;
            dc.DrawEllipse(new SolidColorBrush(lit ? Draw.Lerp(a1, a2, t) : Draw.Dim(ThemeManager.Sub, 60)), null, p, 2.2 * s, 2.2 * s);
        }
        // body
        var body = new RadialGradientBrush(Draw.Lerp(ThemeManager.Panel2, Colors.White, ThemeManager.IsLight ? 0 : 0.10), Draw.Lerp(ThemeManager.Panel, Colors.Black, 0.35));
        dc.DrawEllipse(body, new Pen(new SolidColorBrush(Draw.Dim(a1, 90)), 1.2), c, r, r);
        // knurl
        var kp = new Pen(new SolidColorBrush(Draw.Dim(ThemeManager.Text, 35)), 1);
        for (int i = 0; i < 24; i++) dc.DrawLine(kp, Draw.Polar(c, r - 5 * s, i * 15), Draw.Polar(c, r - 1, i * 15));
        // value arc
        if (frac > 0.002) dc.DrawGeometry(null, new Pen(new SolidColorBrush(a1), 3 * s) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }, Draw.Arc(c, r - 9 * s, 135, 135 + 270 * frac));
        // pointer
        double ang = 135 + 270 * frac;
        dc.DrawLine(new Pen(new SolidColorBrush(ThemeManager.Text), 2.4 * s) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round }, Draw.Polar(c, r * 0.25, ang), Draw.Polar(c, r - 6 * s, ang));
        // texts
        Draw.Text(dc, this, Format(value), 11 * s, a1, new Point(Width / 2, c.Y + r + 6 * s), true);
        Draw.Text(dc, this, Label, 11 * s, ThemeManager.Sub, new Point(Width / 2, c.Y + r + 20 * s));
    }

    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2) { Value = Default; return; }
        drag = e.GetPosition(this); dragStart = value; CaptureMouse();
    }
    protected override void OnMouseMove(MouseEventArgs e)
    {
        if (drag is not Point p0) return;
        double dy = p0.Y - e.GetPosition(this).Y;
        double v = dragStart + dy * (Max - Min) / 180;
        Value = Math.Round(v / Step) * Step;
    }
    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e) { drag = null; ReleaseMouseCapture(); }
    protected override void OnMouseWheel(MouseWheelEventArgs e) => Value = value + Math.Sign(e.Delta) * Math.Max(Step, (Max - Min) / 40);
}

/// Vertical fader with LED meter columns on both sides.
public sealed class Fader : FrameworkElement
{
    double value, level;
    public event Action<double>? Changed;
    public Fader() { Width = 64; Height = 300; Cursor = Cursors.Hand; FlowDirection = FlowDirection.LeftToRight; ThemeManager.Changed += InvalidateVisual; }

    public double Value { get => value; set { var v = Math.Clamp(value, 0, 1); if (v == this.value) return; this.value = v; InvalidateVisual(); Changed?.Invoke(v); } }
    public double Level { get => level; set { level = value; InvalidateVisual(); } }

    const double Pad = 14;
    protected override void OnRender(DrawingContext dc)
    {
        dc.DrawRectangle(Brushes.Transparent, null, new Rect(0, 0, Width, Height));
        var a1 = ThemeManager.A1; var a2 = ThemeManager.A2;
        double h = Height - Pad * 2, cx = Width / 2;
        int segs = 26;
        double sh = h / segs;
        for (int i = 0; i < segs; i++)
        {
            double t = i / (double)(segs - 1);
            double y = Pad + h - (i + 1) * sh + 1.5;
            bool lit = t < level;
            var col = lit ? Draw.Lerp(a1, a2, t) : Draw.Dim(ThemeManager.Sub, 45);
            var br = new SolidColorBrush(col);
            dc.DrawRoundedRectangle(br, null, new Rect(4, y, 9, sh - 3), 1.5, 1.5);
            dc.DrawRoundedRectangle(br, null, new Rect(Width - 13, y, 9, sh - 3), 1.5, 1.5);
        }
        // slot
        dc.DrawRoundedRectangle(new SolidColorBrush(Draw.Lerp(ThemeManager.Panel, Colors.Black, 0.5)), null, new Rect(cx - 3, Pad, 6, h), 3, 3);
        // cap
        double cy = Pad + h * (1 - value);
        var cap = new LinearGradientBrush(Color.FromRgb(235, 235, 240), Color.FromRgb(150, 150, 160), 90);
        dc.DrawRoundedRectangle(cap, new Pen(new SolidColorBrush(Color.FromRgb(90, 90, 100)), 1), new Rect(cx - 15, cy - 13, 30, 26), 4, 4);
        dc.DrawLine(new Pen(new SolidColorBrush(a1), 2.5), new Point(cx - 11, cy), new Point(cx + 11, cy));
    }

    void SetFrom(MouseEventArgs e) => Value = 1 - (e.GetPosition(this).Y - Pad) / (Height - Pad * 2);
    protected override void OnMouseLeftButtonDown(MouseButtonEventArgs e) { CaptureMouse(); SetFrom(e); }
    protected override void OnMouseMove(MouseEventArgs e) { if (IsMouseCaptured) SetFrom(e); }
    protected override void OnMouseLeftButtonUp(MouseButtonEventArgs e) => ReleaseMouseCapture();
    protected override void OnMouseWheel(MouseWheelEventArgs e) => Value = value + Math.Sign(e.Delta) * 0.03;
}

/// Horizontal LED meter.
public sealed class LedBar : FrameworkElement
{
    double level;
    public LedBar() { Height = 14; FlowDirection = FlowDirection.LeftToRight; ThemeManager.Changed += InvalidateVisual; }
    public double Level { get => level; set { level = value; InvalidateVisual(); } }
    protected override void OnRender(DrawingContext dc)
    {
        int segs = 30; double w = ActualWidth / segs;
        for (int i = 0; i < segs; i++)
        {
            double t = i / (double)(segs - 1);
            var col = t < level ? Draw.Lerp(ThemeManager.A1, ThemeManager.A2, t) : Draw.Dim(ThemeManager.Sub, 45);
            dc.DrawRoundedRectangle(new SolidColorBrush(col), null, new Rect(i * w + 1, 0, w - 3, Height), 1.5, 1.5);
        }
    }
}
