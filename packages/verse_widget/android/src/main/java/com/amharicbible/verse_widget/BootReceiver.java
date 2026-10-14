package com.amharicbible.verse_widget;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Alarms are cleared on restart and app update; put the reminder back. */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        Reminder.schedule(context);
        VerseWidgetProvider.updateAll(context);
    }
}
