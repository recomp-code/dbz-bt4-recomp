package io.github.recompcode.dbzbt4;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;

// While a game runs, the launcher's process (online session, invitations, the match's end) is in the background:
// Android would freeze or close it. This foreground service keeps it running until the game ends.
public class GameService extends Service {
    static void start(Context c) {
        try { c.startForegroundService(new Intent(c, GameService.class)); } catch (Exception e) { android.util.Log.e("recomp", "service", e); }
    }

    static void stop(Context c) { c.stopService(new Intent(c, GameService.class)); }

    @Override
    public int onStartCommand(Intent intent, int flags, int id) {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel("game", "Partida en curso", NotificationManager.IMPORTANCE_LOW));
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, LauncherActivity.class), PendingIntent.FLAG_IMMUTABLE);
        Notification n = new Notification.Builder(this, "game").setContentTitle("DBZ Budokai Tenkaichi 4")
            .setContentText("Recomp sigue conectado mientras juegas").setSmallIcon(org.libsdl.app.R.mipmap.ic_launcher).setContentIntent(open).build();
        if (Build.VERSION.SDK_INT >= 34) startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE);
        else startForeground(1, n);
        return START_NOT_STICKY;
    }

    @Override public IBinder onBind(Intent i) { return null; }
}
