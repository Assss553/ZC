package com.rox.play.rox;

import android.app.Activity;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.PixelCopy;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.Text;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;
import java.util.Map;
import org.json.JSONObject;

// ROX inside the Remote Play stream: reads the game picture straight from the video surface (no screen recording),
// ML Kit OCR on the phone, Arabic translation, subtitle drawn over the stream, and sent to ROX TV over the Wi-Fi.
public final class RoxStream implements Server.Api {
    private static RoxStream me;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final Engine eng; private final Server srv; private final Context app;
    private final TextRecognizer ocr = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS);
    private HandlerThread bgT; private Handler bg;
    private Activity act; private SurfaceView sv; private FrameLayout root; private TextView sub; private Button btn; private RegionView region;
    private volatile boolean busy = false; private long lastShown = 0;

    private RoxStream(Context c) {
        app = c.getApplicationContext(); eng = new Engine(app); eng.running = true;
        srv = new Server(app, this);
        final Server s = srv; eng.onChange = () -> { s.broadcast(eng.state(s.tvCount(), 1).toString()); ui.post(this::showSub); };
        srv.start();
    }

    public static void attach(Activity a, SurfaceView surface, FrameLayout rootLayout) {
        if (me == null) me = new RoxStream(a);
        me.bind(a, surface, rootLayout);
    }
    public static void detach() { if (me != null) me.unbind(); }

    private void bind(Activity a, SurfaceView surface, FrameLayout r) {
        act = a; sv = surface; root = r;
        sub = new TextView(a); sub.setTextColor(Color.WHITE); sub.setGravity(Gravity.CENTER); sub.setTypeface(Typeface.DEFAULT_BOLD); sub.setShadowLayer(5, 0, 2, Color.BLACK); sub.setPadding(dp(16), dp(8), dp(16), dp(8)); sub.setVisibility(View.GONE);
        FrameLayout.LayoutParams sp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL); sp.bottomMargin = dp(28); sp.leftMargin = sp.rightMargin = dp(24);
        root.addView(sub, sp);
        btn = new Button(a); btn.setAllCaps(false); btn.setTextColor(Color.WHITE); btn.setTextSize(13);
        GradientDrawable bgd = new GradientDrawable(); bgd.setColor(Color.argb(200, 42, 108, 255)); bgd.setCornerRadius(dp(20)); btn.setBackground(bgd);
        FrameLayout.LayoutParams bp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, dp(40), Gravity.TOP | Gravity.END); bp.topMargin = dp(12); bp.rightMargin = dp(12);
        btn.setPadding(dp(14), 0, dp(14), 0); root.addView(btn, bp); label();
        btn.setOnClickListener(v -> { eng.running = !eng.running; eng.reset(); if (!eng.running) eng.translated = ""; label(); eng.change(); });
        btn.setOnLongClickListener(v -> { editRegion(); return true; });
        bgT = new HandlerThread("rox-ocr"); bgT.start(); bg = new Handler(bgT.getLooper());
        ui.postDelayed(tick, 1500);
        eng.change();
    }
    private void unbind() {
        ui.removeCallbacks(tick); if (bgT != null) bgT.quitSafely(); bgT = null;
        act = null; sv = null; root = null; sub = null; btn = null; region = null;
    }
    private void label() { if (btn != null) btn.setText(eng.running ? "ROX · ترجمة ✓  (اضغط مطولاً: المكان)" : "ROX · الترجمة مطفّية"); }
    private int dp(int v) { return Math.round(v * app.getResources().getDisplayMetrics().density); }

    // ---- grab the decoded video frame from the SurfaceView (PixelCopy, API 24+), crop the text area, OCR it
    private final Runnable tick = new Runnable() { public void run() {
        SurfaceView s = sv;
        if (s != null && eng.running && !busy && s.getHolder().getSurface().isValid() && s.getWidth() > 0) {
            busy = true;
            final Bitmap full = Bitmap.createBitmap(1280, 720, Bitmap.Config.ARGB_8888);
            try {
                PixelCopy.request(s, full, res -> {
                    if (res != PixelCopy.SUCCESS) { busy = false; return; }
                    double[] r = regionFrac(); int w = full.getWidth(), h = full.getHeight();
                    int x = (int) (r[0] * w), y = (int) (r[1] * h), cw = Math.max(16, Math.min(w - x, (int) (r[2] * w))), ch = Math.max(16, Math.min(h - y, (int) (r[3] * h)));
                    Bitmap crop = Bitmap.createBitmap(full, x, y, cw, ch);
                    ocr.process(InputImage.fromBitmap(crop, 0))
                        .addOnSuccessListener(t -> { eng.onText(join(t)); busy = false; })
                        .addOnFailureListener(e -> busy = false);
                }, bg);
            } catch (Exception e) { busy = false; }
        }
        ui.postDelayed(this, 400);
    } };
    private static String join(Text t) { StringBuilder b = new StringBuilder(); for (Text.TextBlock bl : t.getTextBlocks()) for (Text.Line l : bl.getLines()) { if (b.length() > 0) b.append(' '); b.append(l.getText()); } return b.toString(); }
    private double[] regionFrac() {
        try { String s = eng.prefs.getString("region", ""); if (!s.isEmpty()) { JSONObject o = new JSONObject(s); return new double[] { o.getDouble("x"), o.getDouble("y"), o.getDouble("w"), o.getDouble("h") }; } } catch (Exception e) {}
        return new double[] { 0.05, 0.62, 0.9, 0.33 }; // subtitles live in the lower third
    }

    private void showSub() {
        TextView t = sub; if (t == null) return;
        if (!eng.running || eng.translated.isEmpty() || !eng.prefs.getBoolean("phoneSubs", true)) { t.setVisibility(View.GONE); return; }
        t.setText(eng.translated); t.setTextSize(Math.max(14, eng.prefs.getInt("fontSize", 30) * 0.7f));
        GradientDrawable d = new GradientDrawable(); d.setColor(Color.argb((int) (eng.prefs.getFloat("opacity", 0.85f) * 255), 0, 0, 0)); d.setCornerRadius(dp(8)); t.setBackground(d);
        t.setVisibility(View.VISIBLE); final long at = lastShown = System.currentTimeMillis();
        ui.postDelayed(() -> { if (lastShown == at && sub != null) sub.setVisibility(View.GONE); }, 7000);
    }

    // ---- choose where the English subtitle is: drag the frame over it, corners resize
    private void editRegion() {
        if (root == null || sv == null || region != null) return;
        double[] r = regionFrac();
        region = new RegionView(act, r, sv);
        root.addView(region, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        LinearLayout bar = new LinearLayout(act); bar.setOrientation(LinearLayout.HORIZONTAL); bar.setGravity(Gravity.CENTER);
        Button ok = new Button(act), reset = new Button(act); ok.setText("تم"); reset.setText("الافتراضي"); bar.addView(reset); bar.addView(ok);
        FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.CENTER_HORIZONTAL); lp.topMargin = dp(12);
        root.addView(bar, lp);
        TextView hint = new TextView(act); hint.setText("اسحب الإطار فوق الترجمة الإنجليزية، والزوايا لتغيير الحجم"); hint.setTextColor(Color.WHITE); hint.setBackgroundColor(Color.argb(180, 7, 19, 49)); hint.setPadding(dp(12), dp(6), dp(12), dp(6));
        FrameLayout.LayoutParams hp = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP | Gravity.CENTER_HORIZONTAL); hp.topMargin = dp(64); root.addView(hint, hp);
        Runnable close = () -> { root.removeView(region); root.removeView(bar); root.removeView(hint); region = null; eng.reset(); };
        ok.setOnClickListener(v -> { double[] f = region.frac(); try { JSONObject o = new JSONObject(); o.put("x", f[0]); o.put("y", f[1]); o.put("w", f[2]); o.put("h", f[3]); eng.prefs.edit().putString("region", o.toString()).apply(); } catch (Exception e) {} close.run(); });
        reset.setOnClickListener(v -> { eng.prefs.edit().remove("region").apply(); close.run(); });
    }

    static final class RegionView extends View {
        final RectF box = new RectF(); final Paint line = new Paint(Paint.ANTI_ALIAS_FLAG), dim = new Paint(), dot = new Paint(Paint.ANTI_ALIAS_FLAG); final SurfaceView sv;
        int mode = 0; float lx, ly; final int[] svPos = new int[2], myPos = new int[2];
        RegionView(Context c, double[] f, SurfaceView s) { super(c); sv = s; line.setStyle(Paint.Style.STROKE); line.setStrokeWidth(5); line.setColor(Color.rgb(63, 198, 255)); dim.setColor(Color.argb(110, 0, 0, 0)); dot.setColor(Color.rgb(63, 198, 255));
            post(() -> { RectF v = video(); box.set(v.left + (float) f[0] * v.width(), v.top + (float) f[1] * v.height(), v.left + (float) (f[0] + f[2]) * v.width(), v.top + (float) (f[1] + f[3]) * v.height()); invalidate(); }); }
        RectF video() { sv.getLocationOnScreen(svPos); getLocationOnScreen(myPos); float x = svPos[0] - myPos[0], y = svPos[1] - myPos[1]; return new RectF(x, y, x + sv.getWidth(), y + sv.getHeight()); }
        double[] frac() { RectF v = video(); return new double[] { (box.left - v.left) / v.width(), (box.top - v.top) / v.height(), box.width() / v.width(), box.height() / v.height() }; }
        @Override protected void onDraw(Canvas c) { c.drawRect(0, 0, getWidth(), box.top, dim); c.drawRect(0, box.bottom, getWidth(), getHeight(), dim); c.drawRect(0, box.top, box.left, box.bottom, dim); c.drawRect(box.right, box.top, getWidth(), box.bottom, dim);
            c.drawRoundRect(box, 12, 12, line); float r = 18; c.drawCircle(box.left, box.top, r, dot); c.drawCircle(box.right, box.top, r, dot); c.drawCircle(box.left, box.bottom, r, dot); c.drawCircle(box.right, box.bottom, r, dot); }
        @Override public boolean onTouchEvent(MotionEvent e) {
            float x = e.getX(), y = e.getY(), t = 60;
            if (e.getAction() == MotionEvent.ACTION_DOWN) { mode = near(x, box.left, y, box.top, t) ? 1 : near(x, box.right, y, box.top, t) ? 2 : near(x, box.left, y, box.bottom, t) ? 3 : near(x, box.right, y, box.bottom, t) ? 4 : box.contains(x, y) ? 5 : 0; lx = x; ly = y; return true; }
            if (e.getAction() == MotionEvent.ACTION_MOVE && mode > 0) {
                RectF v = video(); float dx = x - lx, dy = y - ly; lx = x; ly = y; float m = 40;
                if (mode == 5) { float w = box.width(), h = box.height(); box.left = clamp(box.left + dx, v.left, v.right - w); box.top = clamp(box.top + dy, v.top, v.bottom - h); box.right = box.left + w; box.bottom = box.top + h; }
                if (mode == 1 || mode == 3) box.left = clamp(box.left + dx, v.left, box.right - m); if (mode == 2 || mode == 4) box.right = clamp(box.right + dx, box.left + m, v.right);
                if (mode == 1 || mode == 2) box.top = clamp(box.top + dy, v.top, box.bottom - m); if (mode == 3 || mode == 4) box.bottom = clamp(box.bottom + dy, box.top + m, v.bottom);
                invalidate(); return true; }
            return true;
        }
        static boolean near(float a, float b, float c, float d, float t) { return Math.abs(a - b) < t && Math.abs(c - d) < t; }
        static float clamp(float v, float a, float b) { return Math.max(a, Math.min(b, v)); }
    }

    // ---- server for ROX TV (finds the phone by /rox.json, shows /tv over the HDMI input)
    @Override public byte[] get(String path, Map<String, String> q, String[] type) {
        try {
            if (path.equals("/rox.json")) { type[0] = "application/json"; return "{\"app\":\"rox\",\"phone\":true,\"play\":true}".getBytes(); }
            if (path.equals("/tv")) { type[0] = "text/html; charset=utf-8"; return Server.readAll(app.getAssets().open("www/tv.html")); }
            if (path.equals("/tv.apk")) { type[0] = "application/vnd.android.package-archive"; return Server.readAll(app.getAssets().open("tv.apk")); }
            if (path.equals("/api/state")) { type[0] = "application/json; charset=utf-8"; return eng.state(srv.tvCount(), 1).toString().getBytes("UTF-8"); }
        } catch (Exception e) {}
        return null;
    }
    @Override public String post(String path, Map<String, String> q, byte[] body) {
        if (path.equals("/hello")) { ui.postDelayed(eng::change, 200); return "{}"; }
        return null;
    }
}
