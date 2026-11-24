package app.rox.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.media.projection.MediaProjectionManager;
import android.os.Bundle;

// Asks Android for screen-capture permission (on the TV: one OK on the remote), hands it to RoxService, closes.
public class CaptureActivity extends Activity {
    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        MediaProjectionManager m = (MediaProjectionManager) getSystemService(Context.MEDIA_PROJECTION_SERVICE);
        try { startActivityForResult(m.createScreenCaptureIntent(), 7); } catch (Exception e) { finish(); }
    }
    @Override protected void onActivityResult(int req, int res, Intent data) {
        if (req == 7 && res == RESULT_OK && data != null) { Intent i = new Intent(this, RoxService.class); i.putExtra("code", res); i.putExtra("data", data); Compat.startService(this, i); }
        else if (RoxService.me != null) { RoxService.me.eng.error = "capture_denied"; RoxService.me.push(); }
        if (getIntent().getBooleanExtra("home", false)) { Intent h = new Intent(Intent.ACTION_MAIN); h.addCategory(Intent.CATEGORY_HOME); h.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(h); } // back to the HDMI input
        finish();
    }
}
