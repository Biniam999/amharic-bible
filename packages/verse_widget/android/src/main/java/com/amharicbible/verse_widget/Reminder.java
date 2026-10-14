package com.amharicbible.verse_widget;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

import java.util.Calendar;

/** Schedules the daily reminder. Each alarm schedules the next one. */
final class Reminder {
    private Reminder() {}

    static void schedule(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarms == null) return;
        PendingIntent pending = pending(context);
        alarms.cancel(pending);
        if (!Store.reminderOn(context)) return;

        Calendar next = Calendar.getInstance();
        next.set(Calendar.HOUR_OF_DAY, Store.reminderHour(context));
        next.set(Calendar.MINUTE, Store.reminderMinute(context));
        next.set(Calendar.SECOND, 0);
        next.set(Calendar.MILLISECOND, 0);
        if (next.getTimeInMillis() <= System.currentTimeMillis() + 1000) {
            next.add(Calendar.DAY_OF_YEAR, 1);
        }
        // Not an exact alarm (no special permission needed); Android may
        // deliver it a few minutes late to save battery.
        if (Build.VERSION.SDK_INT >= 23) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.getTimeInMillis(), pending);
        } else {
            alarms.set(AlarmManager.RTC_WAKEUP, next.getTimeInMillis(), pending);
        }
    }

    static void cancel(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarms != null) alarms.cancel(pending(context));
    }

    private static PendingIntent pending(Context context) {
        Intent intent = new Intent(context, ReminderReceiver.class);
        return PendingIntent.getBroadcast(context, 7401, intent,
                VerseWidgetProvider.immutable(PendingIntent.FLAG_UPDATE_CURRENT));
    }
}
