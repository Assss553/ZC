package app.rox.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;

// ROX TV: the TV itself reads the game picture (screen capture of the HDMI input), translates it and shows it on top.
// The phone app is the remote: it finds this TV on the Wi-Fi and sends start / reading area / size.
public class TvActivity extends Activity {
    WebView web; final Handler ui = new Handler(Looper.getMainLooper());

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        Compat.startService(this, new Intent(this, RoxService.class));
        web = new WebView(this); web.setBackgroundColor(Color.parseColor("#071331")); web.getSettings().setJavaScriptEnabled(true);
        web.addJavascriptInterface(new Bridge(), "RoxTv"); setContentView(web);
    }
    @Override protected void onResume() { super.onResume(); step(); }
    final Runnable refresh = new Runnable() { public void run() { step(); } };

    void page(String body, String button, String action) {
        String h = "<!doctype html><html dir=rtl><meta name=viewport content='width=device-width'><style>body{margin:0;height:100vh;display:flex;align-items:center;justify-content:center;background:radial-gradient(120% 80% at 50% 0%,#1b4fae,#071331 60%);color:#f2f7ff;font-family:sans-serif}"
            + ".c{max-width:72vw;text-align:center}h1{font-size:5vh;margin:0 0 2vh}p{font-size:2.7vh;color:#a9bfe4;line-height:1.7}b{color:#fff}.ip{font:700 6vh monospace;direction:ltr;color:#fff;margin:2vh 0;text-shadow:0 0 3vh #38b6ff}"
            + "button{margin:3vh 1vw 0;font-size:3vh;font-weight:700;color:#fff;border:0;border-radius:2vh;padding:2vh 4vw;background:linear-gradient(95deg,#2a6cff,#3fc6ff)}button:focus{outline:.6vh solid #fff;transform:scale(1.05)}"
            + ".ok{width:12vh;height:12vh;border-radius:50%;background:#4be3a6;color:#06301f;font-size:7vh;display:grid;place-items:center;margin:0 auto 3vh}.bad{color:#ff8a98}</style><body><div class=c>"
            + body + (button != null ? "<br><button autofocus onclick=\"RoxTv." + action + "()\">" + button + "</button>" : "") + "</div><script>var b=document.querySelector('button');b&&b.focus()</script></body></html>";
        web.loadDataWithBaseURL("file:///rox/", h, "text/html", "utf-8", null);
    }

    void step() {
        ui.removeCallbacks(refresh);
        if (!Compat.canOverlay(this)) { page("<h1>فعّل العرض فوق التطبيقات</h1><p>بدونه ما تظهر الترجمة فوق اللعبة.<br>1) اضغط «افتح الإعدادات»  2) فعّل <b>ROX TV</b>  3) ارجع بزر الرجوع</p>", "افتح الإعدادات", "settings"); return; }
        RoxService s = RoxService.me;
        if (s != null && s.eng.capturing) {
            String err = "black".equals(s.eng.error) ? "<p class=bad>الصورة اللي نقرأها سودا: هذا التلفزيون يمنع قراءة صورة HDMI.</p>" : "";
            page("<div class=ok>✓</div><h1>ROX شغّال</h1><p>ارجع لمدخل البلايستيشن (HDMI) والعب.<br>الترجمة تطلع فوق اللعبة. التحكم من جوالك.</p>" + err, "رجوع للبلايستيشن", "home");
        } else {
            page("<h1>ROX TV جاهز</h1><p>افتح تطبيق <b>ROX</b> في جوالك، ويلقى التلفزيون لحاله.<br>الجوال والتلفزيون لازم يكونون على <b>نفس الواي فاي</b>.</p><div class=ip>" + ip() + "</div>", "ابدأ القراءة", "capture");
        }
        ui.postDelayed(refresh, 3000);
    }
    String ip() { try { WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE); int i = wm.getConnectionInfo().getIpAddress(); if (i != 0) return (i & 255) + "." + ((i >> 8) & 255) + "." + ((i >> 16) & 255) + "." + ((i >> 24) & 255); } catch (Exception e) {}
        try { for (java.net.NetworkInterface n : java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())) for (java.net.InetAddress a : java.util.Collections.list(n.getInetAddresses())) if (a instanceof java.net.Inet4Address && a.isSiteLocalAddress()) return a.getHostAddress(); } catch (Exception e) {} return ""; }

    class Bridge {
        @JavascriptInterface public void settings() { ui.post(new Runnable() { public void run() {
            try { startActivity(new Intent("android.settings.action.MANAGE_OVERLAY_PERMISSION", Uri.parse("package:" + getPackageName()))); }
            catch (Exception e) { try { startActivity(new Intent("android.settings.APPLICATION_DETAILS_SETTINGS", Uri.parse("package:" + getPackageName()))); } catch (Exception x) {} } } }); }
        @JavascriptInterface public void capture() { ui.post(new Runnable() { public void run() { Intent c = new Intent(TvActivity.this, CaptureActivity.class); c.putExtra("home", true); startActivity(c); if (RoxService.me != null) { RoxService.me.eng.running = true; RoxService.me.eng.reset(); } } }); }
        @JavascriptInterface public void home() { ui.post(new Runnable() { public void run() { Intent h = new Intent(Intent.ACTION_MAIN); h.addCategory(Intent.CATEGORY_HOME); h.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(h); } }); }
    }
}
