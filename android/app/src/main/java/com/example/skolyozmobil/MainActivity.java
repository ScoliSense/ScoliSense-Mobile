package com.example.skolyozmobil;

import android.content.Intent;
import android.content.SharedPreferences;
import android.content.Context;
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
                        case "saveDeviceAddress":
                            Log.d(TAG, "Saving device address");
                            String address = call.argument("address");
                            saveDeviceAddress(address);
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

    private void saveDeviceAddress(String address) {
        if (address != null && !address.isEmpty()) {
            SharedPreferences prefs = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.putString("lastDeviceAddress", address);
            editor.apply();
            Log.d(TAG, "Device address saved: " + address);
        }
    }

    private void startBackgroundService() {
        try {
            Intent serviceIntent = new Intent(this, BackgroundService.class);
            
            // Get the device address from SharedPreferences
            SharedPreferences prefs = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE);
            String deviceAddress = prefs.getString("lastDeviceAddress", null);
            
            if (deviceAddress != null) {
                serviceIntent.putExtra("deviceAddress", deviceAddress);
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "Starting foreground service (Android O+) with device: " + deviceAddress);
                startForegroundService(serviceIntent);
            } else {
                Log.d(TAG, "Starting service (pre-Android O) with device: " + deviceAddress);
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
