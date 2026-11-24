package app.rox.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.media.projection.MediaProjectionManager;
import android.net.Uri;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebViewClient;

// Phone app: everything runs here (no PC). The page is served by RoxService on 127.0.0.1.
public class MainActivity extends Activity {
    WebView web; final Handler ui = new Handler(Looper.getMainLooper()); ValueCallback<Uri[]> fileCb; volatile String tvHost = null; volatile boolean scanning = false;

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        getWindow().setStatusBarColor(Color.parseColor("#071331")); getWindow().setNavigationBarColor(Color.parseColor("#071331"));
        Compat.startService(this, new Intent(this, RoxService.class));
        web = new WebView(this); web.setBackgroundColor(Color.parseColor("#071331"));
        web.getSettings().setJavaScriptEnabled(true); web.getSettings().setDomStorageEnabled(true);
        web.addJavascriptInterface(new Bridge(), "RoxApp");
        web.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView v, String url) {
                if (url.startsWith("http://127.0.0.1") || (tvHost != null && url.startsWith("http://" + tvHost + ":"))) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); } catch (Exception e) {} return true;
            }
            @Override public void onReceivedError(WebView v, int c, String d, String u) { if (tvHost != null && u != null && u.contains(tvHost)) { new Bridge().rescan(); } ui.postDelayed(new Runnable() { public void run() { web.loadUrl(home()); } }, 1200); } // TV gone or server still starting
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams p) {
                if (fileCb != null) fileCb.onReceiveValue(null); fileCb = cb;
                Intent i = new Intent(Intent.ACTION_GET_CONTENT); i.addCategory(Intent.CATEGORY_OPENABLE); i.setType("*/*");
                try { startActivityForResult(Intent.createChooser(i, "ملف الجمل"), 8); } catch (Exception e) { fileCb = null; return false; } return true;
            }
        });
        setContentView(web); scanTv();
        ui.postDelayed(new Runnable() { public void run() { web.loadUrl(home()); } }, 600);
    }
    static String home() { return "http://127.0.0.1:" + Server.PORT + "/"; }

    @Override protected void onActivityResult(int req, int res, Intent data) {
        if (req == 7) { // screen capture allowed -> the service starts reading
            if (res == RESULT_OK && data != null) { Intent i = new Intent(this, RoxService.class); i.putExtra("code", res); i.putExtra("data", data); Compat.startService(this, i); ui.postDelayed(new Runnable() { public void run() { web.evaluateJavascript("window.onCapture&&onCapture(true)", null); } }, 800); }
            else web.evaluateJavascript("window.onCapture&&onCapture(false)", null);
        }
        if (req == 8 && fileCb != null) { fileCb.onReceiveValue(res == RESULT_OK && data != null && data.getData() != null ? new Uri[]{ data.getData() } : null); fileCb = null; }
    }
    @Override protected void onResume() { super.onResume(); if (web != null) web.evaluateJavascript("window.onResumeApp&&onResumeApp()", null); }
    @Override public void onBackPressed() { if (web.canGoBack()) web.goBack(); else moveTaskToBack(true); } // keep running in the background

    static boolean isTv(String host, int ms) {
        java.net.HttpURLConnection c = null;
        try { c = (java.net.HttpURLConnection) new java.net.URL("http://" + host + ":" + Server.PORT + "/rox.json").openConnection(); c.setConnectTimeout(ms); c.setReadTimeout(ms);
            if (c.getResponseCode() != 200) return false; java.io.InputStream in = c.getInputStream(); byte[] b = new byte[200]; int n = in.read(b); in.close(); return n > 0 && new String(b, 0, n).contains("\"engine\":true");
        } catch (Exception e) { return false; } finally { if (c != null) c.disconnect(); }
    }
    void scanTv() {
        if (scanning) return; scanning = true;
        new Thread(new Runnable() { public void run() {
            final android.content.SharedPreferences p = getSharedPreferences("rox", MODE_PRIVATE);
            while (tvHost == null && !isFinishing()) {
                String last = p.getString("tv", null); if (last != null && isTv(last, 1200)) { tvHost = last; break; }
                String me = new Bridge().ip(); if (me.isEmpty()) { try { Thread.sleep(3000); } catch (Exception e) {} continue; }
                final String pre = me.substring(0, me.lastIndexOf('.') + 1); final java.util.concurrent.atomic.AtomicReference<String> hit = new java.util.concurrent.atomic.AtomicReference<String>(null);
                java.util.concurrent.ExecutorService ex = java.util.concurrent.Executors.newFixedThreadPool(48);
                for (int i = 1; i < 255; i++) { final String h = pre + i; if (h.equals(me)) continue; ex.execute(new Runnable() { public void run() { if (hit.get() == null && isTv(h, 700)) hit.compareAndSet(null, h); } }); }
                ex.shutdown(); try { long end = System.currentTimeMillis() + 9000; while (!ex.isTerminated() && hit.get() == null && System.currentTimeMillis() < end) ex.awaitTermination(100, java.util.concurrent.TimeUnit.MILLISECONDS); } catch (Exception e) {}
                ex.shutdownNow(); if (hit.get() != null) { tvHost = hit.get(); break; } try { Thread.sleep(2500); } catch (Exception e) {}
            }
            scanning = false; if (tvHost != null) p.edit().putString("tv", tvHost).apply();
        } }).start();
    }

    class Bridge {
        @JavascriptInterface public String tvHost() { return tvHost == null ? "" : tvHost; }
        @JavascriptInterface public void rescan() { tvHost = null; getSharedPreferences("rox", MODE_PRIVATE).edit().remove("tv").apply(); scanTv(); }
        @JavascriptInterface public void capture() { ui.post(new Runnable() { public void run() {
            MediaProjectionManager m = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE); startActivityForResult(m.createScreenCaptureIntent(), 7); } }); }
        @JavascriptInterface public boolean canOverlay() { return Compat.canOverlay(MainActivity.this); }
        @JavascriptInterface public void overlaySettings() { ui.post(new Runnable() { public void run() {
            try { startActivity(new Intent("android.settings.action.MANAGE_OVERLAY_PERMISSION", Uri.parse("package:" + getPackageName()))); }
            catch (Exception e) { try { startActivity(new Intent("android.settings.APPLICATION_DETAILS_SETTINGS", Uri.parse("package:" + getPackageName()))); } catch (Exception x) {} } } }); }
        @JavascriptInterface public boolean hasRemotePlay() { return getPackageManager().getLaunchIntentForPackage("com.playstation.remoteplay") != null; }
        @JavascriptInterface public void openRemotePlay() { ui.post(new Runnable() { public void run() {
            Intent i = getPackageManager().getLaunchIntentForPackage("com.playstation.remoteplay");
            if (i != null) startActivity(i); else { try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=com.playstation.remoteplay"))); } catch (Exception e) { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=com.playstation.remoteplay"))); } } } }); }
        @JavascriptInterface public String ip() {
            try { WifiManager wm = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE); int i = wm.getConnectionInfo().getIpAddress(); if (i != 0) return (i & 255) + "." + ((i >> 8) & 255) + "." + ((i >> 16) & 255) + "." + ((i >> 24) & 255); } catch (Exception e) {}
            try { for (java.net.NetworkInterface n : java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())) for (java.net.InetAddress a : java.util.Collections.list(n.getInetAddresses())) if (a instanceof java.net.Inet4Address && a.isSiteLocalAddress()) return a.getHostAddress(); } catch (Exception e) {}
            return "";
        }
    }
}
