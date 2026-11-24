package app.rox.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.GZIPInputStream;
import org.json.JSONArray;
import org.json.JSONObject;

// Text -> Arabic on the phone: memory (your past lines, up to 600,000) and the game phrase list answer instantly and offline,
// then Google Translate; when there is no internet the line is built from the 87k-word dictionary.
final class Engine {
    static final int CAP = 600000;
    final Context ctx; final SharedPreferences prefs;
    final LinkedHashMap<String, String> memory = new LinkedHashMap<String, String>(1024, 0.75f, false);
    final HashMap<String, String> phrases = new HashMap<String, String>();
    HashMap<String, String> base = null;
    final ExecutorService pool = Executors.newSingleThreadExecutor();
    File memFile;
    // state shared with the pages
    volatile String original = "", translated = "", error = "";
    volatile boolean running = false, capturing = false;
    final List<String[]> log = new ArrayList<String[]>();
    Runnable onChange;
    private String lastKey = "";

    Engine(Context c) {
        ctx = c; prefs = c.getSharedPreferences("rox", Context.MODE_PRIVATE);
        memFile = new File(c.getFilesDir(), "memory-en-ar.tsv");
        new Thread(new Runnable() { public void run() { load(); } }).start();
    }

    static String key(String s) {
        return String.valueOf(s).toLowerCase().replace('’', '\'').replace('‘', '\'').replaceAll("[\"“”]", "").replaceAll("[.!?…,;:]+$", "").replaceAll("\\s+", " ").trim();
    }

    private void load() {
        try { BufferedReader r = new BufferedReader(new InputStreamReader(ctx.getAssets().open("data/phrases-en-ar.tsv"), "UTF-8")); String l;
            while ((l = r.readLine()) != null) { if (l.startsWith("#")) continue; int i = l.indexOf('\t'); if (i > 0) phrases.put(key(l.substring(0, i)), l.substring(i + 1).trim()); } r.close(); } catch (Exception e) {}
        try { if (memFile.exists()) { BufferedReader r = new BufferedReader(new FileReader(memFile)); String l;
            synchronized (memory) { while ((l = r.readLine()) != null) { int i = l.indexOf('\t'); if (i > 0) { String k = l.substring(0, i); memory.remove(k); memory.put(k, l.substring(i + 1)); } } trim(); } r.close(); } } catch (Exception e) {}
    }
    private HashMap<String, String> base() {
        if (base != null) return base;
        HashMap<String, String> m = new HashMap<String, String>(140000);
        try { BufferedReader r = new BufferedReader(new InputStreamReader(new GZIPInputStream(ctx.getAssets().open("data/dict-en-ar.tsv.gz")), "UTF-8")); String l;
            while ((l = r.readLine()) != null) { int i = l.indexOf('\t'); if (i > 0) m.put(l.substring(0, i), l.substring(i + 1)); } r.close(); } catch (Exception e) {}
        return base = m;
    }
    private void trim() { Iterator<String> it = memory.keySet().iterator(); while (memory.size() > CAP && it.hasNext()) { it.next(); it.remove(); } }

    int memorySize() { synchronized (memory) { return memory.size(); } }

    void learn(String src, String out) {
        String k = key(src); if (k.isEmpty() || out == null || out.trim().isEmpty() || k.length() > 600) return;
        String v = out.replaceAll("[\\t\\r\\n]+", " ").trim();
        synchronized (memory) { memory.remove(k); memory.put(k, v); trim(); }
        try { FileOutputStream f = new FileOutputStream(memFile, true); f.write((k + "\t" + v + "\n").getBytes("UTF-8")); f.close(); } catch (Exception e) {}
    }

    // "english<TAB>arabic", "english = arabic" or "english,arabic" per line
    int[] importText(String text) {
        int added = 0, bad = 0;
        StringBuilder out = new StringBuilder();
        for (String l : text.split("\\r?\\n")) {
            if (l.trim().isEmpty() || l.startsWith("#")) continue;
            java.util.regex.Matcher m = java.util.regex.Pattern.compile("^(.+?)\\s*(?:\\t|=|,|;|\\|)\\s*(.+)$").matcher(l);
            if (!m.find() || !m.group(2).matches(".*[\\u0600-\\u06FF].*")) { bad++; continue; }
            String k = key(m.group(1)), v = m.group(2).trim(); if (k.isEmpty()) { bad++; continue; }
            synchronized (memory) { memory.remove(k); memory.put(k, v); } out.append(k).append('\t').append(v).append('\n'); added++;
        }
        synchronized (memory) { trim(); }
        try { FileOutputStream f = new FileOutputStream(memFile, true); f.write(out.toString().getBytes("UTF-8")); f.close(); } catch (Exception e) {}
        return new int[] { added, bad };
    }

    String lookup(String src) { String k = key(src); synchronized (memory) { String v = memory.get(k); if (v != null) return v; } return phrases.get(k); }

    String rough(String src) { // offline: longest known phrases
        HashMap<String, String> b = base(); String[] w = key(src).split(" "); StringBuilder o = new StringBuilder(); int hits = 0;
        for (int i = 0; i < w.length;) {
            boolean done = false;
            for (int n = Math.min(5, w.length - i); n >= 1 && !done; n--) {
                StringBuilder p = new StringBuilder(); for (int j = 0; j < n; j++) { if (j > 0) p.append(' '); p.append(w[i + j]); }
                String ps = p.toString(), v; synchronized (memory) { v = memory.get(ps); } if (v == null) v = phrases.get(ps); if (v == null) v = b.get(ps);
                if (v != null) { if (o.length() > 0) o.append(' '); o.append(v); i += n; hits += n; done = true; }
            }
            if (!done) { if (o.length() > 0) o.append(' '); o.append(w[i]); i++; }
        }
        return w.length > 0 && hits * 2 >= w.length ? o.toString() : null;
    }

    static String google(String text) throws Exception {
        URL u = new URL("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ar&dt=t&q=" + URLEncoder.encode(text, "UTF-8"));
        HttpURLConnection c = (HttpURLConnection) u.openConnection(); c.setConnectTimeout(5000); c.setReadTimeout(6000);
        BufferedReader r = new BufferedReader(new InputStreamReader(c.getInputStream(), "UTF-8")); StringBuilder sb = new StringBuilder(); String l; while ((l = r.readLine()) != null) sb.append(l); r.close();
        JSONArray a = new JSONArray(sb.toString()).getJSONArray(0); StringBuilder o = new StringBuilder();
        for (int i = 0; i < a.length(); i++) { Object s = a.getJSONArray(i).opt(0); if (s instanceof String) o.append((String) s); }
        String out = o.toString().trim(); if (!out.matches("(?s).*[\\u0600-\\u06FF].*")) throw new Exception("not_arabic");
        return out;
    }

    static String clean(String raw) {
        String t = String.valueOf(raw).replaceAll("[|_~^`<>{}\\[\\]]", " ").replaceAll("\\s+", " ").trim();
        return t;
    }
    static boolean plausible(String t) { // real dialogue, not scenery noise
        if (t.length() < 4) return false; int letters = 0; for (char ch : t.toCharArray()) if (Character.isLetter(ch)) letters++;
        if (letters * 10 < t.length() * 6) return false; String[] w = t.split(" "); int good = 0; for (String x : w) if (x.replaceAll("[^A-Za-z']", "").length() >= 2) good++;
        return good >= 2 || (good == 1 && w.length == 1 && t.length() >= 4);
    }
    static int sim(String a, String b) { a = key(a); b = key(b); if (a.equals(b)) return 100; int n = Math.max(a.length(), b.length()); if (n == 0) return 100; int same = 0; for (int i = 0; i < Math.min(a.length(), b.length()); i++) if (a.charAt(i) == b.charAt(i)) same++; return same * 100 / n; }

    // called with every OCR result
    void onText(final String raw) {
        if (!running) return;
        final String t = clean(raw);
        if (!plausible(t)) { if (!translated.isEmpty() && t.isEmpty()) { /* text gone: keep the last line a moment, the TV hides it after a while */ } return; }
        if (sim(t, lastKey) >= 85) return; // same line still on screen (OCR jitter)
        lastKey = t;
        String hit = lookup(t);
        if (hit != null) { publish(t, hit); return; }
        pool.execute(new Runnable() { public void run() {
            String out;
            try { out = google(t); learn(t, out); error = ""; }
            catch (Exception e) { out = rough(t); error = out == null ? "offline" : ""; if (out == null) { change(); return; } }
            if (t.equals(lastKey)) publish(t, out);
        } });
    }
    void publish(String src, String out) {
        original = src; translated = out;
        synchronized (log) { log.add(0, new String[] { src, out }); while (log.size() > 40) log.remove(log.size() - 1); }
        change();
    }
    void change() { Runnable r = onChange; if (r != null) r.run(); }
    void reset() { lastKey = ""; }

    JSONObject state(int tvs, int phones) {
        JSONObject o = new JSONObject();
        try {
            o.put("running", running); o.put("capturing", capturing); o.put("original", original); o.put("translated", translated); o.put("error", error);
            o.put("fontSize", prefs.getInt("fontSize", 30)); o.put("opacity", prefs.getFloat("opacity", 0.85f)); o.put("position", prefs.getString("position", "bottom"));
            o.put("phoneSubs", prefs.getBoolean("phoneSubs", true)); o.put("overlay", Compat.canOverlay(ctx));
            String r = prefs.getString("region", ""); o.put("region", r.isEmpty() ? JSONObject.NULL : new JSONObject(r));
            o.put("tvs", tvs); o.put("memory", memorySize()); o.put("base", base == null ? 87400 : base.size()); o.put("cap", CAP);
            JSONArray l = new JSONArray(); synchronized (log) { for (String[] e : log) { JSONArray x = new JSONArray(); x.put(e[0]); x.put(e[1]); l.put(x); } } o.put("log", l);
        } catch (Exception e) {}
        return o;
    }
}
