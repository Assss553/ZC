package app.rox.mobile;

import android.app.Activity;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.Image;
import android.media.ImageReader;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebView;
import android.widget.TextView;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.Map;
import org.json.JSONObject;

// Runs everything on the phone: screen capture of PS Remote Play, OCR (tesseract in a tiny hidden WebView), translation,
// the subtitle over the phone screen, and the server the TV app listens to.
public class RoxService extends Service implements Server.Api {
    static RoxService me;
    Engine eng; Server srv; final Handler ui = new Handler(Looper.getMainLooper());
    MediaProjection proj; VirtualDisplay vd; ImageReader reader; HandlerThread capThread; Handler cap;
    volatile byte[] frameJpg = null, ocrJpg = null; volatile long ocrSeq = 0, ocrTaken = 0, lastOcrAt = 0, darkSince = 0;
    final Object ocrLock = new Object();
    WebView ocrWeb; TextView sub; WindowManager wm; long lastShown = 0; boolean isTv;

    @Override public IBinder onBind(Intent i) { return null; }

    @Override public void onCreate() {
        super.onCreate(); me = this;
        Compat.foreground(this, 1, Compat.notification(this, "ROX", "الترجمة جاهزة"));
        eng = new Engine(this);
        eng.onChange = new Runnable() { public void run() { push(); } };
        srv = new Server(this, this); srv.start();
        wm = (WindowManager) getSystemService(WINDOW_SERVICE); isTv = getPackageName().endsWith(".tv");
        if (isTv) ui.postDelayed(new Runnable() { public void run() { ensureOcr(); } }, 500); // the TV does the reading; the phone app is only the remote
    }

    @Override public int onStartCommand(Intent i, int f, int id) {
        if (i != null && i.hasExtra("code")) startCapture(i.getIntExtra("code", 0), (Intent) i.getParcelableExtra("data"));
        return START_STICKY;
    }

    @Override public void onDestroy() { stopCapture(); srv.stop(); if (ocrWeb != null) { try { wm.removeView(ocrWeb); } catch (Exception e) {} ocrWeb.destroy(); } if (sub != null) { try { wm.removeView(sub); } catch (Exception e) {} } me = null; super.onDestroy(); }

    // ---------- OCR host: tesseract.js runs in a 1x1 overlay WebView so it keeps working while PS Remote Play is in front
    void ensureOcr() {
        if (ocrWeb != null) return;
        ocrWeb = new WebView(this); ocrWeb.getSettings().setJavaScriptEnabled(true); ocrWeb.getSettings().setDomStorageEnabled(true);
        if (Compat.canOverlay(this)) {
            WindowManager.LayoutParams p = new WindowManager.LayoutParams(1, 1, Compat.overlayType(), WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE, PixelFormat.TRANSLUCENT);
            p.gravity = Gravity.TOP | Gravity.START; try { wm.addView(ocrWeb, p); } catch (Exception e) {}
        }
        ocrWeb.loadUrl("http://127.0.0.1:" + Server.PORT + "/www/ocr.html");
    }

    // ---------- subtitle over the phone screen
    void showSub() {
        if (!Compat.canOverlay(this)) return;
        boolean want = eng.running && eng.prefs.getBoolean("phoneSubs", true) && !eng.translated.isEmpty();
        if (sub == null && want) {
            sub = new TextView(this); sub.setTextColor(Color.WHITE); sub.setGravity(Gravity.CENTER); sub.setTypeface(Typeface.DEFAULT_BOLD); sub.setPadding(28, 14, 28, 14); sub.setShadowLayer(4, 0, 1, Color.BLACK);
            WindowManager.LayoutParams p = new WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT, Compat.overlayType(), WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN, PixelFormat.TRANSLUCENT);
            p.gravity = Gravity.BOTTOM; p.y = 40; try { wm.addView(sub, p); } catch (Exception e) { sub = null; return; }
        }
        if (sub == null) return;
        if (!want) { sub.setVisibility(View.GONE); return; }
        sub.setText(eng.translated); sub.setTextSize(Math.max(14, eng.prefs.getInt("fontSize", 30) * 0.6f));
        sub.setBackgroundColor(Color.argb((int) (eng.prefs.getFloat("opacity", 0.85f) * 255), 0, 0, 0)); sub.setVisibility(View.VISIBLE);
        final long at = lastShown = System.currentTimeMillis();
        ui.postDelayed(new Runnable() { public void run() { if (lastShown == at && sub != null) sub.setVisibility(View.GONE); } }, 7000);
    }

    // ---------- screen capture
    void startCapture(int code, Intent data) {
        stopCapture();
        try {
            MediaProjectionManager m = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
            proj = m.getMediaProjection(code, data); if (proj == null) return;
            DisplayMetrics dm = getResources().getDisplayMetrics(); int w = Math.max(dm.widthPixels, dm.heightPixels), h = Math.min(dm.widthPixels, dm.heightPixels);
            if (dm.widthPixels < dm.heightPixels) { int t = w; w = h; h = t; } // keep the real orientation
            float k = Math.min(1f, 1280f / Math.max(w, h)); final int W = Math.round(w * k), H = Math.round(h * k);
            capThread = new HandlerThread("cap"); capThread.start(); cap = new Handler(capThread.getLooper());
            reader = ImageReader.newInstance(W, H, PixelFormat.RGBA_8888, 2);
            vd = proj.createVirtualDisplay("rox", W, H, dm.densityDpi, DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, reader.getSurface(), null, cap);
            eng.capturing = true; eng.error = ""; push();
            cap.postDelayed(grab, 400);
        } catch (Exception e) { eng.error = "capture_failed"; push(); }
    }
    void stopCapture() {
        eng.capturing = false;
        try { if (vd != null) vd.release(); } catch (Exception e) {} vd = null;
        try { if (reader != null) reader.close(); } catch (Exception e) {} reader = null;
        try { if (proj != null) proj.stop(); } catch (Exception e) {} proj = null;
        if (capThread != null) capThread.quitSafely(); capThread = null;
    }
    long lastFull = 0;
    final Runnable grab = new Runnable() { public void run() {
        if (reader == null) return;
        try {
            Image img = reader.acquireLatestImage();
            if (img != null) {
                Image.Plane pl = img.getPlanes()[0]; ByteBuffer buf = pl.getBuffer(); int ps = pl.getPixelStride(), rs = pl.getRowStride(), w = img.getWidth(), h = img.getHeight();
                Bitmap b = Bitmap.createBitmap(rs / ps, h, Bitmap.Config.ARGB_8888); b.copyPixelsFromBuffer(buf); img.close();
                if (b.getWidth() != w) b = Bitmap.createBitmap(b, 0, 0, w, h);
                long now = System.currentTimeMillis();
                // black picture for a while = the app being captured blocks screen recording (or the stream is off)
                int lum = 0; for (int i = 0; i < 64; i++) { int c = b.getPixel((i * 37) % w, (i * 53) % h); lum += (Color.red(c) + Color.green(c) + Color.blue(c)) / 3; }
                if (lum / 64 < 4) { if (darkSince == 0) darkSince = now; if (now - darkSince > 8000 && !"black".equals(eng.error)) { eng.error = "black"; push(); } }
                else { darkSince = 0; if ("black".equals(eng.error)) { eng.error = ""; push(); } }
                if (now - lastFull > 1500) { frameJpg = jpg(b, 70); lastFull = now; }
                if (eng.running && now - lastOcrAt > 350 && ocrTaken == ocrSeq) { // only when the OCR page is free
                    JSONObject r = null; try { String rs2 = eng.prefs.getString("region", ""); if (!rs2.isEmpty()) r = new JSONObject(rs2); } catch (Exception e) {}
                    double x = r != null ? r.optDouble("x", .05) : .05, y = r != null ? r.optDouble("y", .62) : .62, rw = r != null ? r.optDouble("w", .9) : .9, rh = r != null ? r.optDouble("h", .33) : .33;
                    int cx = clamp((int) (x * w), 0, w - 8), cy = clamp((int) (y * h), 0, h - 8), cw = clamp((int) (rw * w), 8, w - cx), ch = clamp((int) (rh * h), 8, h - cy);
                    Bitmap crop = Bitmap.createBitmap(b, cx, cy, cw, ch);
                    if (cw < 1100) crop = Bitmap.createScaledBitmap(crop, 1100, Math.max(8, ch * 1100 / cw), true);
                    synchronized (ocrLock) { ocrJpg = jpg(crop, 88); ocrSeq++; ocrLock.notifyAll(); }
                    lastOcrAt = now;
                }
            }
        } catch (Exception e) {}
        if (cap != null) cap.postDelayed(this, 250);
    } };
    static int clamp(int v, int a, int b) { return Math.max(a, Math.min(b, v)); }
    static byte[] jpg(Bitmap b, int q) { ByteArrayOutputStream o = new ByteArrayOutputStream(); b.compress(Bitmap.CompressFormat.JPEG, q, o); return o.toByteArray(); }

    // ---------- pages <-> phone
    void push() { final String s = eng.state(srv.tvCount(), 0).toString(); srv.broadcast(s); ui.post(new Runnable() { public void run() { showSub(); } }); }

    @Override public byte[] get(String path, Map<String, String> q, String[] type) {
        try {
            if (path.equals("/rox.json")) { type[0] = "application/json"; return (isTv ? "{\"app\":\"rox\",\"tv\":true,\"engine\":true,\"v\":3}" : "{\"app\":\"rox\",\"remote\":true,\"v\":3}").getBytes(); }
            if (path.equals("/api/state")) { type[0] = "application/json; charset=utf-8"; return eng.state(srv.tvCount(), 0).toString().getBytes("UTF-8"); }
            if (path.equals("/frame.jpg")) { type[0] = "image/jpeg"; byte[] f = frameJpg; if (f == null) { type[0] = "204"; return new byte[0]; } return f; }
            if (path.equals("/ocr/next")) { // long poll from the OCR page
                synchronized (ocrLock) { long until = System.currentTimeMillis() + 8000; while (ocrTaken == ocrSeq && System.currentTimeMillis() < until) ocrLock.wait(500); if (ocrTaken == ocrSeq) { type[0] = "204"; return new byte[0]; } ocrTaken = ocrSeq; type[0] = "image/jpeg"; return ocrJpg; }
            }
            if (path.equals("/tv.apk")) { type[0] = "application/vnd.android.package-archive"; return Server.readAll(getAssets().open("tv.apk")); }
            if (path.equals("/") || path.equals("/tv")) { type[0] = "text/html; charset=utf-8"; return Server.readAll(getAssets().open(path.equals("/") ? "www/app.html" : "www/tv.html")); }
        } catch (Exception e) {}
        return null;
    }

    @Override public String post(String path, Map<String, String> q, byte[] body) {
        try {
            if (path.equals("/hello")) { ui.postDelayed(new Runnable() { public void run() { push(); } }, 200); return "{}"; }
            String text = body == null ? "" : new String(body, "UTF-8");
            if (path.equals("/ocr/result")) { eng.onText(text); return "{}"; }
            if (path.equals("/api/import")) { int[] r = eng.importText(text); push(); return "{\"ok\":true,\"added\":" + r[0] + ",\"skipped\":" + r[1] + ",\"memory\":" + eng.memorySize() + "}"; }
            if (path.equals("/api/cmd")) {
                JSONObject m = new JSONObject(text); String t = m.optString("type");
                if (t.equals("toggle")) { eng.running = !eng.running; eng.reset(); if (!eng.running) { eng.translated = ""; } }
                else if (t.equals("region")) { if (m.isNull("frac")) eng.prefs.edit().remove("region").apply(); else eng.prefs.edit().putString("region", m.getJSONObject("frac").toString()).apply(); eng.reset(); }
                else if (t.equals("save")) { JSONObject p = m.getJSONObject("patch"); android.content.SharedPreferences.Editor e = eng.prefs.edit();
                    if (p.has("fontSize")) e.putInt("fontSize", Math.max(16, Math.min(60, p.getInt("fontSize")))); if (p.has("opacity")) e.putFloat("opacity", (float) Math.max(0.2, Math.min(1, p.getDouble("opacity"))));
                    if (p.has("position")) e.putString("position", p.getString("position")); if (p.has("phoneSubs")) e.putBoolean("phoneSubs", p.getBoolean("phoneSubs")); e.apply(); }
                else if (t.equals("capture")) { Intent c = new Intent(this, CaptureActivity.class); c.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); c.putExtra("home", true); startActivity(c); if (!eng.running) eng.running = true; eng.reset(); }
                else if (t.equals("stopCapture")) { stopCapture(); eng.running = false; eng.translated = ""; }
                else if (t.equals("test")) { eng.running = true; eng.publish("Where's the money, Franklin?", "وين الفلوس يا فرانكلين؟"); }
                push(); return "{\"ok\":true}";
            }
        } catch (Exception e) { return "{\"ok\":false}"; }
        return null;
    }
}
