package com.amharicbible.verse_widget;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

/** Shows the daily reminder with today's verse, then schedules tomorrow's. */
public class ReminderReceiver extends BroadcastReceiver {
    private static final String CHANNEL = "daily_verse";

    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            show(context);
        } finally {
            Reminder.schedule(context);
        }
        // The widget may also need the new day's verse.
        VerseWidgetProvider.updateAll(context);
    }

    private static void show(Context context) {
        if (Build.VERSION.SDK_INT >= 33
                && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            return;
        }
        String title = Store.reminderTitle(context);
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = context.getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(
                        new NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_DEFAULT));
            }
        }
        Store.Entry entry = Store.today(context);
        String body = entry != null ? entry.text : Store.reminderFallback(context);
        String heading = entry != null && !entry.reference.isEmpty() ? title + " · " + entry.reference : title;

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(R.drawable.ic_stat_verse)
                .setColor(0xFF1A5FD0)
                .setContentTitle(heading)
                .setContentText(body)
                .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);
        if (VerseWidgetProvider.openApp(context, 7402) != null) {
            builder.setContentIntent(VerseWidgetProvider.openApp(context, 7402));
        }
        try {
            NotificationManagerCompat.from(context).notify(7402, builder.build());
        } catch (SecurityException ignored) {
            // Notifications were turned off for the app.
        }
    }
}
