package com.devasy.repforge;

import android.Manifest;
import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.media.AudioAttributes;
import android.os.Build;

/** Posts a rest completion alert even when the Flutter activity is suspended. */
public final class RestAlertReceiver extends BroadcastReceiver {
    private static final String PREFS = "rest_alert";
    private static final String DEADLINE = "deadline";
    private static final String SOUND = "sound";
    private static final String VIBRATION = "vibration";
    private static final int REQUEST_CODE = 9042;
    private static final int NOTIFICATION_ID = 9042;

    public static boolean notificationsAllowed(Context context) {
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        return manager != null && manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED);
    }

    private static PendingIntent alarmIntent(Context context, int flags) {
        Intent intent = new Intent(context, RestAlertReceiver.class);
        intent.setAction(context.getPackageName() + ".REST_COMPLETE");
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent,
            flags | PendingIntent.FLAG_IMMUTABLE);
    }

    public static void schedule(Context context, long deadline, boolean sound, boolean vibration) {
        cancel(context);
        if (deadline <= System.currentTimeMillis() || !notificationsAllowed(context)) return;
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        // Commit before scheduling: the receiver may start in a fresh process.
        if (!prefs.edit().putLong(DEADLINE, deadline).putBoolean(SOUND, sound)
            .putBoolean(VIBRATION, vibration).commit()) return;
        AlarmManager alarms = context.getSystemService(AlarmManager.class);
        if (alarms == null) return;
        PendingIntent pending = alarmIntent(context, PendingIntent.FLAG_UPDATE_CURRENT);
        try {
            if (Build.VERSION.SDK_INT >= 31 && !alarms.canScheduleExactAlarms()) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, pending);
            } else {
                alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, pending);
            }
        } catch (SecurityException revokedWhileScheduling) {
            // Exact alarm access can change between the check and the call.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, deadline, pending);
        }
    }

    public static void cancel(Context context) {
        // Clear the token first so an already-delivered broadcast becomes inert.
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(DEADLINE).commit();
        AlarmManager alarms = context.getSystemService(AlarmManager.class);
        PendingIntent pending = alarmIntent(context, PendingIntent.FLAG_NO_CREATE);
        if (alarms != null && pending != null) {
            alarms.cancel(pending);
            pending.cancel();
        }
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        if (manager != null) manager.cancel(NOTIFICATION_ID);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        long deadline = prefs.getLong(DEADLINE, 0);
        if (deadline == 0 || System.currentTimeMillis() + 1000 < deadline ||
            !notificationsAllowed(context)) return;
        boolean sound = prefs.getBoolean(SOUND, true);
        boolean vibration = prefs.getBoolean(VIBRATION, true);
        prefs.edit().remove(DEADLINE).commit();

        NotificationManager manager = context.getSystemService(NotificationManager.class);
        String channelId = "rest_complete_" + (sound ? "sound" : "silent") +
            (vibration ? "_vibrate" : "_still");
        NotificationChannel channel = new NotificationChannel(channelId, "Rest complete",
            NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("Alerts when a workout rest period ends");
        channel.setSound(
            sound ? android.provider.Settings.System.DEFAULT_NOTIFICATION_URI : null,
            sound ? new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION).build() : null);
        channel.enableVibration(vibration);
        if (vibration) channel.setVibrationPattern(new long[]{0, 250, 150, 250});
        manager.createNotificationChannel(channel);

        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        PendingIntent openApp = launch == null ? null : PendingIntent.getActivity(context,
            REQUEST_CODE, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder builder = new Notification.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Rest complete")
            .setContentText("Time for your next set")
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC);
        if (openApp != null) builder.setContentIntent(openApp);
        manager.notify(NOTIFICATION_ID, builder.build());
    }
}
