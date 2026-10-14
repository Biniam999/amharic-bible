package com.amharicbible.verse_widget;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.widget.RemoteViews;

/** The "Verse of the day" home-screen widget. */
public class VerseWidgetProvider extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids) {
            manager.updateAppWidget(id, build(context));
        }
    }

    static RemoteViews build(Context context) {
        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.verse_widget);
        Store.Entry entry = Store.today(context);
        if (entry != null) {
            views.setTextViewText(R.id.verse_widget_label, entry.label);
            views.setTextViewText(R.id.verse_widget_text, "“" + entry.text + "”");
            views.setTextViewText(R.id.verse_widget_ref, entry.reference);
        }
        PendingIntent open = openApp(context, 0);
        if (open != null) views.setOnClickPendingIntent(R.id.verse_widget_root, open);
        return views;
    }

    /** Opens the app (used by the widget and the reminder). */
    static PendingIntent openApp(Context context, int requestCode) {
        Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (launch == null) return null;
        launch.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context, requestCode, launch, immutable(PendingIntent.FLAG_UPDATE_CURRENT));
    }

    static int immutable(int flags) {
        return Build.VERSION.SDK_INT >= 23 ? flags | PendingIntent.FLAG_IMMUTABLE : flags;
    }

    /** Redraws every placed widget with the latest saved verse. */
    static void updateAll(Context context) {
        AppWidgetManager manager = AppWidgetManager.getInstance(context);
        int[] ids = manager.getAppWidgetIds(new ComponentName(context, VerseWidgetProvider.class));
        for (int id : ids) {
            manager.updateAppWidget(id, build(context));
        }
    }
}
