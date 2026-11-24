package app.rox.mobile;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.view.WindowManager;
import java.lang.reflect.Constructor;

// Newer Android APIs called by reflection: the app is compiled against the API 23 jar but runs on Android 5 to 15.
final class Compat {
    static final String CH = "rox";

    static int overlayType() { return Build.VERSION.SDK_INT >= 26 ? 2038 /* TYPE_APPLICATION_OVERLAY */ : WindowManager.LayoutParams.TYPE_PHONE; }

    static boolean canOverlay(Context c) {
        if (Build.VERSION.SDK_INT < 23) return true;
        try { return (Boolean) android.provider.Settings.class.getMethod("canDrawOverlays", Context.class).invoke(null, c); } catch (Exception e) { return true; }
    }

    static void startService(Context c, Intent i) {
        if (Build.VERSION.SDK_INT >= 26) { try { Context.class.getMethod("startForegroundService", Intent.class).invoke(c, i); return; } catch (Exception e) {} }
        c.startService(i);
    }

    static Notification notification(Context c, String title, String text) {
        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) {
            try {
                Class<?> chC = Class.forName("android.app.NotificationChannel");
                Object ch = chC.getConstructor(String.class, CharSequence.class, int.class).newInstance(CH, "ROX", 2);
                NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
                NotificationManager.class.getMethod("createNotificationChannel", chC).invoke(nm, ch);
                Constructor<Notification.Builder> k = Notification.Builder.class.getConstructor(Context.class, String.class);
                b = k.newInstance(c, CH);
            } catch (Exception e) { b = new Notification.Builder(c); }
        } else b = new Notification.Builder(c);
        b.setContentTitle(title).setContentText(text).setSmallIcon(R.drawable.icon).setOngoing(true);
        return b.build();
    }

    static void foreground(Service s, int id, Notification n) { s.startForeground(id, n); }
}
