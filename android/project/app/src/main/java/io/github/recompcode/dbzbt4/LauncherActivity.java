package io.github.recompcode.dbzbt4;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageInfo;
import android.content.res.AssetManager;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

// The launcher: recomp-online's frontend (assets/launcher) in a WebView, talking to the Go side through RecompBridge.
// android_bridge.js gives the frontend the window.go.main.App / window.runtime it has under Wails.
public class LauncherActivity extends Activity {
    private static final int PICK_ISO = 1;
    private WebView web;
    private boolean pageReady;
    private final List<String> queued = new ArrayList<>();
    private final ExecutorService calls = Executors.newCachedThreadPool();
    volatile boolean resumed;
    private RecompBridge.Wait<String> pickWait;

    @SuppressLint({"SetJavaScriptEnabled", "AddJavascriptInterface"})
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        RecompBridge.activity = new java.lang.ref.WeakReference<>(this);
        web = new WebView(this);
        web.setBackgroundColor(0xFF0E121A);
        setContentView(web);
        immersive();
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setUseWideViewPort(true);   // android_bridge.js sizes the page's viewport for the screen
        s.setLoadWithOverviewMode(true);
        s.setSupportZoom(false);
        web.addJavascriptInterface(new Js(), "RecompAndroid");
        web.setWebViewClient(new WebViewClient() {
            @Override public void onPageFinished(WebView v, String url) {
                pageReady = true;
                for (String js : queued) v.evaluateJavascript(js, null);
                queued.clear();
            }
            @Override public boolean shouldOverrideUrlLoading(WebView v, android.webkit.WebResourceRequest r) {
                startActivity(new Intent(Intent.ACTION_VIEW, r.getUrl()));
                return true;
            }
        });
        calls.execute(() -> {
            extractRuntime();
            RecompBridge.nativeInit(getFilesDir().getAbsolutePath(), "");
            runOnUiThread(() -> web.loadUrl("file:///android_asset/launcher/index.html"));
        });
        handleInstallResult(getIntent());
    }

    private void immersive() {
        if (android.os.Build.VERSION.SDK_INT >= 30 && getWindow().getInsetsController() != null) {
            getWindow().getInsetsController().hide(WindowInsets.Type.systemBars());
            getWindow().getInsetsController().setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        }
    }

    @Override protected void onResume() { super.onResume(); resumed = true; immersive(); }
    @Override protected void onPause() { super.onPause(); resumed = false; }

    @Override protected void onNewIntent(Intent i) { super.onNewIntent(i); handleInstallResult(i); }

    // The package installer's answer: it needs the player's confirmation first.
    private void handleInstallResult(Intent i) {
        if (i == null || !"io.github.recompcode.dbzbt4.INSTALLED".equals(i.getAction())) return;
        if (i.getIntExtra(PackageInstaller.EXTRA_STATUS, 0) == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            Intent confirm = i.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirm != null) startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }

    // The game's runtime files (assets, fps60_sites.txt, settings.toml) come out of the APK once per version.
    private void extractRuntime() {
        try {
            PackageInfo pi = getPackageManager().getPackageInfo(getPackageName(), 0);
            File res = new File(getFilesDir(), "res");
            File mark = new File(res, ".version");
            String want = pi.versionName + "/" + pi.getLongVersionCode() + "/" + pi.lastUpdateTime;
            if (mark.exists() && want.equals(new String(java.nio.file.Files.readAllBytes(mark.toPath())))) return;
            deleteTree(new File(res, "runtime"));
            copyAssets(getAssets(), "runtime", new File(res, "runtime"));
            try (OutputStream o = new FileOutputStream(mark)) { o.write(want.getBytes()); }
        } catch (Exception e) {
            android.util.Log.e("recomp", "extract", e);
        }
    }

    private static void deleteTree(File f) {
        File[] c = f.listFiles();
        if (c != null) for (File x : c) deleteTree(x);
        f.delete();
    }

    private static void copyAssets(AssetManager am, String path, File dst) throws Exception {
        String[] list = am.list(path);
        if (list != null && list.length > 0) {
            dst.mkdirs();
            for (String n : list) copyAssets(am, path + "/" + n, new File(dst, n));
            return;
        }
        dst.getParentFile().mkdirs();
        try (InputStream in = am.open(path); OutputStream out = new FileOutputStream(dst)) {
            byte[] b = new byte[1 << 16];
            for (int n; (n = in.read(b)) > 0; ) out.write(b, 0, n);
        }
    }

    // From Go: an event for the frontend. The game's end also ends the foreground service that kept this process alive.
    void deliverEvent(String name, String json) {
        if ("game".equals(name) && json.contains("\"running\":false")) GameService.stop(this);
        String js = "window.__recompEmit && window.__recompEmit(" + JSONObject.quote(name) + "," + json + ")";
        runOnUiThread(() -> { if (pageReady) web.evaluateJavascript(js, null); else queued.add(js); });
    }

    // From Go (a Go thread): the document picker; blocks until the player chose (or cancelled).
    String pickIso() {
        RecompBridge.Wait<String> w = new RecompBridge.Wait<>();
        pickWait = w;
        runOnUiThread(() -> {
            Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            i.addCategory(Intent.CATEGORY_OPENABLE);
            i.setType("*/*");
            i.putExtra(Intent.EXTRA_MIME_TYPES, new String[] {"application/x-iso9660-image", "application/octet-stream", "*/*"});
            startActivityForResult(i, PICK_ISO);
        });
        return w.get();
    }

    @Override
    protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req, res, data);
        if (req != PICK_ISO || pickWait == null) return;
        RecompBridge.Wait<String> w = pickWait;
        pickWait = null;
        if (res != RESULT_OK || data == null || data.getData() == null) { w.set(""); return; }
        Uri u = data.getData();
        try { getContentResolver().takePersistableUriPermission(u, Intent.FLAG_GRANT_READ_URI_PERMISSION); } catch (Exception ignored) { }
        w.set(u.toString());
    }

    @Override
    public void onBackPressed() { moveTaskToBack(true); }

    // What the page calls (android_bridge.js).
    private final class Js {
        @JavascriptInterface
        public void call(int id, String method, String argsJson) {
            calls.execute(() -> {
                String r = RecompBridge.nativeCall(method, argsJson);
                String js = "window.__recompResolve(" + id + "," + r + ")";
                runOnUiThread(() -> web.evaluateJavascript(js, null));
            });
        }
        @JavascriptInterface public void minimise() { runOnUiThread(() -> moveTaskToBack(true)); }
        @JavascriptInterface public void quit() { runOnUiThread(LauncherActivity.this::finishAndRemoveTask); }
        @JavascriptInterface public void openUrl(String u) { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(u))); }
    }
}
