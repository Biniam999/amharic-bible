package com.amharicbible.verse_widget;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Calendar;
import java.util.Locale;

/** What the Flutter app saved for the widget and the reminder. */
final class Store {
    private static final String PREFS = "amharic_bible_verse_widget";

    private Store() {}

    /** One day's verse. */
    static final class Entry {
        final String label;
        final String text;
        final String reference;

        Entry(String label, String text, String reference) {
            this.label = label;
            this.text = text;
            this.reference = reference;
        }
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static void saveVerses(Context c, String json) {
        prefs(c).edit().putString("verses", json).apply();
    }

    static void saveReminder(Context c, boolean on, int hour, int minute, String title, String fallback) {
        prefs(c).edit()
                .putBoolean("reminder_on", on)
                .putInt("reminder_hour", hour)
                .putInt("reminder_minute", minute)
                .putString("reminder_title", title)
                .putString("reminder_fallback", fallback)
                .apply();
    }

    static boolean reminderOn(Context c) { return prefs(c).getBoolean("reminder_on", false); }
    static int reminderHour(Context c) { return prefs(c).getInt("reminder_hour", 7); }
    static int reminderMinute(Context c) { return prefs(c).getInt("reminder_minute", 0); }
    static String reminderTitle(Context c) { return prefs(c).getString("reminder_title", "Verse of the day"); }
    static String reminderFallback(Context c) { return prefs(c).getString("reminder_fallback", ""); }

    static String todayKey() {
        Calendar now = Calendar.getInstance();
        return String.format(Locale.US, "%04d-%02d-%02d",
                now.get(Calendar.YEAR), now.get(Calendar.MONTH) + 1, now.get(Calendar.DAY_OF_MONTH));
    }

    /**
     * Today's verse. If the app hasn't been opened for a while, the most recent
     * saved day is used; null when nothing has been saved yet.
     */
    static Entry today(Context c) {
        String raw = prefs(c).getString("verses", null);
        if (raw == null) return null;
        try {
            JSONObject root = new JSONObject(raw);
            String label = root.optString("label", "Verse of the day");
            JSONArray items = root.optJSONArray("items");
            if (items == null || items.length() == 0) return null;
            String today = todayKey();
            JSONObject best = null;
            for (int i = 0; i < items.length(); i++) {
                JSONObject item = items.getJSONObject(i);
                String day = item.optString("d", "");
                if (day.compareTo(today) <= 0) best = item; // items are in date order
                if (day.equals(today)) break;
            }
            if (best == null) best = items.getJSONObject(0);
            return new Entry(label, best.optString("t", ""), best.optString("r", ""));
        } catch (Exception e) {
            return null;
        }
    }
}
