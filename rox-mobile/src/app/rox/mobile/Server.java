package app.rox.mobile;

import android.content.Context;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

// Tiny HTTP server on the phone (port 8765): the app pages, the OCR page, the TV page, and Server-Sent Events so the TV
// gets each translated line the moment it is ready. LAN only; the TV finds the phone by asking every address for /rox.json.
final class Server {
    static final int PORT = 8765;
    interface Api { byte[] get(String path, Map<String, String> q, String[] type); String post(String path, Map<String, String> q, byte[] body); }
    final Context ctx; final Api api; ServerSocket ss; volatile boolean on = true;
    final List<OutputStream[]> streams = new ArrayList<OutputStream[]>(); final List<Boolean> streamIsTv = new ArrayList<Boolean>();

    Server(Context c, Api a) { ctx = c; api = a; }

    void start() {
        new Thread(new Runnable() { public void run() {
            try { ss = new ServerSocket(PORT, 50, InetAddress.getByName("0.0.0.0")); ss.setReuseAddress(true); } catch (Exception e) { return; }
            while (on) { try { final Socket s = ss.accept(); new Thread(new Runnable() { public void run() { handle(s); } }).start(); } catch (Exception e) {} }
        } }).start();
    }
    void stop() { on = false; try { ss.close(); } catch (Exception e) {} synchronized (streams) { for (OutputStream[] o : streams) { try { o[0].close(); } catch (Exception e) {} } streams.clear(); streamIsTv.clear(); } }

    int tvCount() { synchronized (streams) { int n = 0; for (Boolean b : streamIsTv) if (b) n++; return n; } }

    void broadcast(String json) {
        byte[] b; try { b = ("data: " + json + "\n\n").getBytes("UTF-8"); } catch (Exception e) { return; }
        synchronized (streams) {
            for (int i = streams.size() - 1; i >= 0; i--) { try { streams.get(i)[0].write(b); streams.get(i)[0].flush(); } catch (Exception e) { streams.remove(i); streamIsTv.remove(i); } }
        }
    }

    static Map<String, String> query(String qs) {
        Map<String, String> m = new HashMap<String, String>(); if (qs == null) return m;
        for (String p : qs.split("&")) { int i = p.indexOf('='); try { if (i > 0) m.put(p.substring(0, i), java.net.URLDecoder.decode(p.substring(i + 1), "UTF-8")); } catch (Exception e) {} }
        return m;
    }
    static String mime(String p) {
        if (p.endsWith(".html")) return "text/html; charset=utf-8"; if (p.endsWith(".js")) return "text/javascript; charset=utf-8"; if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".png")) return "image/png"; if (p.endsWith(".svg")) return "image/svg+xml"; if (p.endsWith(".wasm")) return "application/wasm"; if (p.endsWith(".apk")) return "application/vnd.android.package-archive";
        return "application/octet-stream";
    }

    private void handle(Socket s) {
        try {
            s.setSoTimeout(30000); InputStream in = s.getInputStream(); OutputStream out = s.getOutputStream();
            ByteArrayOutputStream hb = new ByteArrayOutputStream(); int c, st = 0;
            while ((c = in.read()) != -1) { hb.write(c); st = (c == '\r' || c == '\n') ? st + 1 : 0; if (st == 4 || hb.size() > 16384) break; }
            String head = hb.toString("UTF-8"); String[] lines = head.split("\r\n"); if (lines.length == 0) { s.close(); return; }
            String[] rq = lines[0].split(" "); if (rq.length < 2) { s.close(); return; }
            String method = rq[0], full = rq[1], path = full, qs = null; int qi = full.indexOf('?'); if (qi >= 0) { path = full.substring(0, qi); qs = full.substring(qi + 1); }
            int len = 0; for (String l : lines) if (l.toLowerCase().startsWith("content-length:")) len = Integer.parseInt(l.substring(15).trim());
            Map<String, String> q = query(qs);
            if (path.equals("/events")) { // Server-Sent Events: stays open
                s.setSoTimeout(0);
                out.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: keep-alive\r\n\r\n".getBytes("UTF-8")); out.flush();
                synchronized (streams) { streams.add(new OutputStream[] { out }); streamIsTv.add("1".equals(q.get("tv"))); }
                api.post("/hello", q, null);
                return; // socket kept open by the stream list
            }
            if (method.equals("POST")) {
                if (len > 64 * 1024 * 1024) { reply(out, 413, "text/plain", "too big".getBytes()); s.close(); return; }
                byte[] body = new byte[len]; int got = 0; while (got < len) { int n = in.read(body, got, len - got); if (n < 0) break; got += n; }
                String r = api.post(path, q, body); reply(out, r == null ? 404 : 200, "application/json; charset=utf-8", (r == null ? "{}" : r).getBytes("UTF-8"));
            } else {
                String[] type = { null }; byte[] b = api.get(path, q, type);
                if (b == null && path.startsWith("/www/")) { try { InputStream a = ctx.getAssets().open(path.substring(1)); b = readAll(a); type[0] = mime(path); } catch (Exception e) {} }
                if (b == null) reply(out, 404, "text/plain", "not found".getBytes()); else if (b.length == 0 && "204".equals(type[0])) reply(out, 204, "text/plain", b); else reply(out, 200, type[0] == null ? mime(path) : type[0], b);
            }
            s.close();
        } catch (Exception e) { try { s.close(); } catch (Exception x) {} }
    }
    static byte[] readAll(InputStream a) throws Exception { ByteArrayOutputStream o = new ByteArrayOutputStream(); byte[] buf = new byte[65536]; int n; while ((n = a.read(buf)) > 0) o.write(buf, 0, n); a.close(); return o.toByteArray(); }
    static void reply(OutputStream out, int code, String type, byte[] body) throws Exception {
        out.write(("HTTP/1.1 " + code + (code == 200 ? " OK" : " X") + "\r\nContent-Type: " + type + "\r\nContent-Length: " + body.length + "\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n").getBytes("UTF-8"));
        out.write(body); out.flush();
    }
}
