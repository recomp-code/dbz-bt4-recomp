package io.github.recompcode.dbzbt4;

import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.system.ErrnoException;
import android.system.Os;
import android.view.Display;
import android.view.WindowManager;

import org.libsdl.app.SDLActivity;

// The game: SDL's activity around libmain.so (the recompiled runner, with SDL linked in), in a process of its own
// (":game"). The launcher's environment arrives as the "env" extra and is set before libmain.so loads; an ISO the document
// picker granted (content://) is opened here and handed to the runtime as /proc/self/fd/<n>.
public class GameActivity extends SDLActivity {
    @Override
    protected String[] getLibraries() {
        return new String[] { "main" };
    }

    @Override
    protected void onCreate(Bundle state) {
        // The environment goes in BEFORE super.onCreate loads libmain.so: the runtime reads some of it in static
        // initializers, at load time (PS2X_FIBERS -> frame stepping, which online play needs to stay in sync).
        String[] env = getIntent().getStringArrayExtra("env");
        if (env != null) {
            for (String kv : env) {
                int eq = kv.indexOf('=');
                if (eq <= 0) continue;
                String k = kv.substring(0, eq), v = kv.substring(eq + 1);
                if (k.equals("PS2X_CD_IMAGE") && v.startsWith("content://")) {
                    try {
                        ParcelFileDescriptor p = getContentResolver().openFileDescriptor(Uri.parse(v), "r");
                        if (p != null) v = "/proc/self/fd/" + p.detachFd();
                    } catch (Exception e) {
                        android.util.Log.e("recomp", "ISO", e);
                    }
                }
                try {
                    Os.setenv(k, v, true);
                } catch (ErrnoException e) {
                    android.util.Log.e("recomp", "setenv " + k, e);
                }
            }
        }
        super.onCreate(state);   // loads libmain.so
        if (mBrokenLibraries) return;
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        prefer60Hz();
    }

    // The game runs at 60 (or 30): a 90/120 Hz panel is asked for its 60 Hz mode at the same resolution -- even frame
    // pacing (no 2-3-2 cadence), less power. Phones without one keep their mode.
    private void prefer60Hz() {
        Display d = getWindowManager().getDefaultDisplay();
        Display.Mode cur = d.getMode(), best = null;
        for (Display.Mode m : d.getSupportedModes()) {
            if (m.getPhysicalWidth() != cur.getPhysicalWidth() || m.getPhysicalHeight() != cur.getPhysicalHeight()) continue;
            if (Math.abs(m.getRefreshRate() - 60f) < 1f) best = m;
        }
        if (best != null) {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.preferredDisplayModeId = best.getModeId();
            getWindow().setAttributes(lp);
        }
    }
}
