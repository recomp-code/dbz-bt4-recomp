package io.github.recompcode.dbzbt4;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.DisplayMetrics;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.ref.WeakReference;
import java.util.concurrent.CountDownLatch;

// The launcher's bridge: the Go side (liblauncher.so, recomp-online's launcher/main_android.go) runs the same App as the
// desktop launchers; LauncherActivity's WebView calls it through nativeCall, and it calls back here for the events
// (onEvent -> the WebView) and for what only Android can do (platform: the document picker, starting the game...).
// Every string is ASCII JSON both ways.
public final class RecompBridge {
    static { System.loadLibrary("launcher"); }

    static native void nativeInit(String root, String server);
    static native String nativeCall(String method, String argsJson);

    static WeakReference<LauncherActivity> activity = new WeakReference<>(null);

    static void onEvent(String name, String json) {
        LauncherActivity a = activity.get();
        if (a != null) a.deliverEvent(name, json);
    }

    // platform(op, json) -> the answer, or "error:<text>". Called on Go's threads: it may block (the picker waits for the player).
    static String platform(String op, String json) {
        LauncherActivity a = activity.get();
        try {
            switch (op) {
                case "pickIso": return a == null ? "error:no hay ventana" : a.pickIso();
                case "openFd": return openFd(a, Json.str(json));
                case "startGame": return startGame(a, json);
                case "openUrl":
                    if (a != null) a.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(Json.str(json))));
                    return "";
                case "inFront": return a != null && a.resumed ? "1" : "0";
                case "toFront":
                case "show":
                    if (a != null) {
                        Intent i = new Intent(a, LauncherActivity.class);
                        i.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_NEW_TASK);
                        a.startActivity(i);
                    }
                    return "";
                case "screen": {
                    if (a == null) return "error:no hay ventana";
                    DisplayMetrics m = a.getResources().getDisplayMetrics();
                    return "[" + Math.max(m.widthPixels, m.heightPixels) + "," + Math.min(m.widthPixels, m.heightPixels) + "]";
                }
                case "device": return Build.MANUFACTURER + " " + Build.MODEL + (Build.VERSION.SDK_INT >= 31 ? " (" + Build.SOC_MODEL + ")" : "");
                case "micAccess": return "0";
                case "nativeLibDir": return a == null ? "error:no hay ventana" : a.getApplicationInfo().nativeLibraryDir;
                case "installApk": return installApk(a, Json.str(json));
                case "quit":
                    if (a != null) a.runOnUiThread(a::finishAndRemoveTask);
                    return "";
                case "log": Log.i("recomp", Json.str(json)); return "";
                default: return "error:" + op + " no existe";
            }
        } catch (Exception e) {
            Log.e("recomp", "platform " + op, e);
            return "error:" + e.getMessage();
        }
    }

    // A file descriptor of the document (detached: the receiver owns it). The launcher's Go side reads the ISO this way.
    static String openFd(Activity a, String uri) throws Exception {
        if (a == null) return "error:no hay ventana";
        ParcelFileDescriptor p = a.getContentResolver().openFileDescriptor(Uri.parse(uri), "r");
        if (p == null) return "error:no pude abrir la ISO";
        return Integer.toString(p.detachFd());
    }

    static String startGame(Activity a, String json) {
        if (a == null) return "error:no hay ventana";
        String[] env = Json.strArray(json, "env");
        Intent i = new Intent(a, GameActivity.class);
        i.putExtra("env", env);
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
        GameService.start(a);
        a.startActivity(i);
        return "";
    }

    // The new APK goes to the system's installer, which asks the player to confirm.
    static String installApk(Activity a, String path) throws Exception {
        if (a == null) return "error:no hay ventana";
        if (Build.VERSION.SDK_INT >= 26 && !a.getPackageManager().canRequestPackageInstalls()) {
            a.startActivity(new Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + a.getPackageName())));
            return "error:permite que Recomp instale actualizaciones y vuelve a intentarlo";
        }
        PackageInstaller pi = a.getPackageManager().getPackageInstaller();
        PackageInstaller.SessionParams sp = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
        int id = pi.createSession(sp);
        try (PackageInstaller.Session s = pi.openSession(id)) {
            File f = new File(path);
            try (InputStream in = new FileInputStream(f); OutputStream out = s.openWrite("recomp.apk", 0, f.length())) {
                byte[] b = new byte[1 << 16];
                for (int n; (n = in.read(b)) > 0; ) out.write(b, 0, n);
                s.fsync(out);
            }
            Intent cb = new Intent(a, LauncherActivity.class).setAction("io.github.recompcode.dbzbt4.INSTALLED");
            android.app.PendingIntent pend = android.app.PendingIntent.getActivity(a, 0, cb, android.app.PendingIntent.FLAG_MUTABLE | android.app.PendingIntent.FLAG_UPDATE_CURRENT);
            s.commit(pend.getIntentSender());
        }
        return "";
    }

    // Blocks a Go thread until the UI thread has an answer.
    static final class Wait<T> {
        private final CountDownLatch latch = new CountDownLatch(1);
        private T value;
        void set(T v) { value = v; latch.countDown(); }
        T get() { try { latch.await(); } catch (InterruptedException ignored) { } return value; }
    }
}
