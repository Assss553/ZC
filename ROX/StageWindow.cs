using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace ROX;

/// Borderless window that plays transition videos. Add it in OBS as "Window Capture: ROX Stage"
/// and use a Chroma Key (green) or Color Key (black) filter.
public sealed class StageWindow : Window
{
    readonly MediaElement media = new() { LoadedBehavior = MediaState.Manual, UnloadedBehavior = MediaState.Close, IsMuted = true, Stretch = Stretch.Uniform };
    public event Action? Finished;

    public StageWindow()
    {
        Title = "ROX Stage";
        Width = 960; Height = 540;
        WindowStyle = WindowStyle.None; ResizeMode = ResizeMode.CanResizeWithGrip;
        ShowInTaskbar = true; Topmost = false;
        Content = media;
        media.MediaEnded += (_, _) => { media.Stop(); media.Source = null; Finished?.Invoke(); };
        MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) DragMove(); };
        SetBackground("green");
    }

    public void SetBackground(string key) => Background = key switch
    {
        "black" => Brushes.Black,
        "magenta" => Brushes.Magenta,
        _ => new SolidColorBrush(Color.FromRgb(0, 255, 0)),
    };

    public void Play(string path)
    {
        if (!IsVisible) Show();
        media.Stop();
        media.Source = new Uri(path);
        media.Play();
    }

    public void StopVideo() { media.Stop(); media.Source = null; }
}
