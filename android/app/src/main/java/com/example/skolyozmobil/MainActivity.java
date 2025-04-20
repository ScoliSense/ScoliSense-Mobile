package com.example.skolyozmobil;

import android.content.Intent;
import android.os.Build;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private static final String CHANNEL = "com.example.skolyozmobil/background_service";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                try {
                    switch (call.method) {
                        case "startService":
                            Log.d(TAG, "Starting background service");
                            startBackgroundService();
                            result.success(null);
                            break;
                        case "stopService":
                            Log.d(TAG, "Stopping background service");
                            stopBackgroundService();
                            result.success(null);
                            break;
                        default:
                            Log.w(TAG, "Method not implemented: " + call.method);
                            result.notImplemented();
                            break;
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Error handling method call: " + call.method, e);
                    result.error("FAILED", e.getMessage(), null);
                }
            });
    }

    private void startBackgroundService() {
        try {
            Intent serviceIntent = new Intent(this, BackgroundService.class);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Starting foreground service (Android O+)");
                startForegroundService(serviceIntent);
            } else {
                Log.d(TAG, "Starting service (pre-Android O)");
                startService(serviceIntent);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error starting background service", e);
            throw e;
        }
    }

    private void stopBackgroundService() {
        try {
            Log.d(TAG, "Attempting to stop background service");
            Intent serviceIntent = new Intent(this, BackgroundService.class);
            boolean stopped = stopService(serviceIntent);
            Log.d(TAG, "Service stop result: " + stopped);
        } catch (Exception e) {
            Log.e(TAG, "Error stopping background service", e);
            throw e;
        }
    }
}
