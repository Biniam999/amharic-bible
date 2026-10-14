package com.amharicbible.verse_widget;

import android.Manifest;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/** Connects the Flutter app to the widget and the reminder. */
public class VerseWidgetPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
        PluginRegistry.RequestPermissionsResultListener {

    private static final int PERMISSION_REQUEST = 7403;

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activity;
    private MethodChannel.Result pendingPermission;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "amharic_bible/verse_widget");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "saveVerses": {
                String json = call.argument("json");
                if (json != null) Store.saveVerses(context, json);
                VerseWidgetProvider.updateAll(context);
                result.success(null);
                break;
            }
            case "scheduleReminder": {
                Integer hour = call.argument("hour");
                Integer minute = call.argument("minute");
                String title = call.argument("title");
                String fallback = call.argument("fallback");
                Store.saveReminder(context, true,
                        hour == null ? 7 : hour, minute == null ? 0 : minute,
                        title == null ? "" : title, fallback == null ? "" : fallback);
                Reminder.schedule(context);
                result.success(null);
                break;
            }
            case "cancelReminder": {
                Store.saveReminder(context, false, Store.reminderHour(context), Store.reminderMinute(context),
                        Store.reminderTitle(context), Store.reminderFallback(context));
                Reminder.cancel(context);
                result.success(null);
                break;
            }
            case "requestNotificationPermission":
                requestPermission(result);
                break;
            case "requestPinWidget": {
                boolean asked = false;
                if (Build.VERSION.SDK_INT >= 26) {
                    AppWidgetManager manager = AppWidgetManager.getInstance(context);
                    if (manager.isRequestPinAppWidgetSupported()) {
                        asked = manager.requestPinAppWidget(
                                new ComponentName(context, VerseWidgetProvider.class), null, null);
                    }
                }
                result.success(asked);
                break;
            }
            default:
                result.notImplemented();
        }
    }

    private void requestPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT < 33
                || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                == PackageManager.PERMISSION_GRANTED) {
            result.success(true);
            return;
        }
        if (activity == null || pendingPermission != null) {
            result.success(false);
            return;
        }
        pendingPermission = result;
        ActivityCompat.requestPermissions(activity.getActivity(),
                new String[] {Manifest.permission.POST_NOTIFICATIONS}, PERMISSION_REQUEST);
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                              @NonNull int[] grantResults) {
        if (requestCode != PERMISSION_REQUEST) return false;
        boolean granted = grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
        if (pendingPermission != null) {
            pendingPermission.success(granted);
            pendingPermission = null;
        }
        return true;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activity != null) activity.removeRequestPermissionsResultListener(this);
        activity = null;
    }
}
