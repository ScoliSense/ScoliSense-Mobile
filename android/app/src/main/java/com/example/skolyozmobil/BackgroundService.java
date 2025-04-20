package com.example.skolyozmobil;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import java.util.UUID;
import java.util.List;
import java.nio.charset.StandardCharsets;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.ArrayList;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.RequestBody;
import okhttp3.MediaType;
import okhttp3.Call;
import okhttp3.Callback;
import java.io.IOException;

public class BackgroundService extends Service {
    private BluetoothManager bluetoothManager;
    private BluetoothAdapter bluetoothAdapter;
    private BluetoothGatt bluetoothGatt;
    private String deviceAddress;
    private StringBuilder buffer = new StringBuilder();
    private static final Pattern SENSOR_PATTERN = Pattern.compile("^FSR\\d+$");
    private static final OkHttpClient client = new OkHttpClient();
    private static final MediaType JSON = MediaType.parse("application/json; charset=utf-8");
    private static final String TAG = "BackgroundService";
    private static final String CHANNEL_ID = "ForegroundServiceChannel";
    private static final int NOTIFICATION_ID = 1;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "Service onCreate called");
        createNotificationChannel();
        
        bluetoothManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);
        if (bluetoothManager != null) {
            bluetoothAdapter = bluetoothManager.getAdapter();
        }
        
        SharedPreferences prefs = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE);
        deviceAddress = prefs.getString("lastDeviceAddress", null);
        if (deviceAddress != null) {
            connectToDevice(deviceAddress);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "Service onStartCommand called");
        try {
            Notification notification = createNotification();
            startForeground(NOTIFICATION_ID, notification);
            Log.d(TAG, "Service started successfully in foreground");
            
            if (intent != null) {
                String action = intent.getStringExtra("action");
                if ("takeOver".equals(action)) {
                    Log.d(TAG, "Taking over Bluetooth connection");
                    handleTakeOver();
                } else if (intent.hasExtra("deviceAddress")) {
                    deviceAddress = intent.getStringExtra("deviceAddress");
                    SharedPreferences.Editor editor = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE).edit();
                    editor.putString("lastDeviceAddress", deviceAddress);
                    editor.apply();
                    
                    if (bluetoothGatt == null) {
                        connectToDevice(deviceAddress);
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error starting service in foreground", e);
        }
        return START_STICKY;
    }

    private void handleTakeOver() {
        if (bluetoothGatt != null) {
            Log.d(TAG, "Already connected, no need to take over");
            return;
        }

        SharedPreferences prefs = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE);
        String savedAddress = prefs.getString("lastDeviceAddress", null);
        
        if (savedAddress != null) {
            Log.d(TAG, "Taking over connection for device: " + savedAddress);
            connectToDevice(savedAddress);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (bluetoothGatt != null) {
            bluetoothGatt.close();
            bluetoothGatt = null;
        }
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private UUID notifyServiceUUID;
    private UUID notifyCharacteristicUUID;

    private void loadSavedUUIDs() {
        SharedPreferences prefs = getSharedPreferences("BlePrefs", Context.MODE_PRIVATE);
        String serviceUUID = prefs.getString("notifyServiceUUID", null);
        String characteristicUUID = prefs.getString("notifyCharacteristicUUID", null);
        
        if (serviceUUID != null && characteristicUUID != null) {
            try {
                notifyServiceUUID = UUID.fromString(serviceUUID);
                notifyCharacteristicUUID = UUID.fromString(characteristicUUID);
                Log.d(TAG, "Loaded UUIDs - Service: " + serviceUUID + ", Char: " + characteristicUUID);
            } catch (IllegalArgumentException e) {
                Log.e(TAG, "Error parsing UUIDs", e);
            }
        }
    }

    private void connectToDevice(String address) {
        if (bluetoothAdapter == null || address == null) {
            Log.w(TAG, "BluetoothAdapter not initialized or unspecified address.");
            return;
        }

        loadSavedUUIDs();
        if (notifyServiceUUID == null || notifyCharacteristicUUID == null) {
            Log.e(TAG, "Missing service or characteristic UUID");
            return;
        }

        try {
            BluetoothDevice device = bluetoothAdapter.getRemoteDevice(address);
            Log.d(TAG, "Trying to connect to " + address);
            
            bluetoothGatt = device.connectGatt(this, true, gattCallback);
        } catch (IllegalArgumentException e) {
            Log.w(TAG, "Device not found with provided address. Unable to connect.");
        }
    }

    private final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "Connected to GATT server.");
                bluetoothGatt.discoverServices();
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.i(TAG, "Disconnected from GATT server.");
                // Try to reconnect
                if (deviceAddress != null) {
                    connectToDevice(deviceAddress);
                }
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                BluetoothGattService service = gatt.getService(notifyServiceUUID);
                if (service != null) {
                    BluetoothGattCharacteristic characteristic = 
                        service.getCharacteristic(notifyCharacteristicUUID);
                    if (characteristic != null) {
                        boolean success = gatt.setCharacteristicNotification(characteristic, true);
                        Log.d(TAG, "Set characteristic notification: " + success);
                    } else {
                        Log.e(TAG, "Characteristic not found: " + notifyCharacteristicUUID);
                    }
                } else {
                    Log.e(TAG, "Service not found: " + notifyServiceUUID);
                }
            }
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            byte[] data = characteristic.getValue();
            if (data != null) {
                String value = new String(data, StandardCharsets.UTF_8);
                processIncomingData(value);
            }
        }
    };

    private void processIncomingData(String newData) {
        buffer.append(newData);
        String bufferStr = buffer.toString();
        
        if (bufferStr.contains("\n")) {
            String[] messages = bufferStr.split("\n");
            
            // Process all complete messages
            for (int i = 0; i < messages.length - 1; i++) {
                String message = messages[i].trim();
                if (message.contains(":")) {
                    String[] parts = message.split(":");
                    if (parts.length == 2) {
                        String sensorName = parts[0].trim();
                        try {
                            double value = Double.parseDouble(parts[1].trim());
                            if (SENSOR_PATTERN.matcher(sensorName).matches()) {
                                sendSensorData(sensorName, value);
                            }
                        } catch (NumberFormatException e) {
                            Log.e(TAG, "Error parsing sensor value: " + parts[1]);
                        }
                    }
                }
            }
            
            // Keep the incomplete message in buffer
            buffer = new StringBuilder(messages[messages.length - 1]);
        }
    }

    private void sendSensorData(String sensorName, double value) {
        SharedPreferences prefs = getSharedPreferences("com.example.skolyozmobil_preferences", Context.MODE_PRIVATE);
        String token = prefs.getString("authToken", "");
        
        if (token.isEmpty()) {
            Log.e(TAG, "No auth token available");
            return;
        }

        try {
            JSONObject json = new JSONObject();
            json.put("sensorName", sensorName);
            json.put("value", value);
            json.put("timeStamp", java.time.Instant.now().toString());

            RequestBody body = RequestBody.create(json.toString(), JSON);
            Request request = new Request.Builder()
                .url("https://mybackendhaha.store/api/SensorData/by-name")
                .addHeader("Authorization", "Bearer " + token)
                .post(body)
                .build();

            client.newCall(request).enqueue(new Callback() {
                @Override
                public void onFailure(Call call, IOException e) {
                    Log.e(TAG, "Failed to send sensor data", e);
                    storeSensorData(sensorName, value);
                }

                @Override
                public void onResponse(Call call, Response response) {
                    if (!response.isSuccessful()) {
                        Log.e(TAG, "Unsuccessful response: " + response.code());
                        storeSensorData(sensorName, value);
                    }
                    response.close();
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Error preparing sensor data", e);
            storeSensorData(sensorName, value);
        }
    }

    private void storeSensorData(String sensorName, double value) {
        try {
            SharedPreferences prefs = getSharedPreferences("UnsentData", Context.MODE_PRIVATE);
            String key = "unsent_" + sensorName;
            String existingData = prefs.getString(key, "[]");
            
            JSONArray dataArray = new JSONArray(existingData);
            JSONObject dataPoint = new JSONObject();
            dataPoint.put("timeStamp", java.time.Instant.now().toString());
            dataPoint.put("value", value);
            
            dataArray.put(dataPoint);
            
            SharedPreferences.Editor editor = prefs.edit();
            editor.putString(key, dataArray.toString());
            editor.apply();
        } catch (Exception e) {
            Log.e(TAG, "Error storing sensor data", e);
        }
    }

    private void createNotificationChannel() {
        Log.d(TAG, "Creating notification channel");
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                CHANNEL_ID,
                "Foreground Service Channel",
                NotificationManager.IMPORTANCE_LOW
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(serviceChannel);
                Log.d(TAG, "Notification channel created successfully");
            } else {
                Log.e(TAG, "NotificationManager is null");
            }
        }
    }

    private Notification createNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Running in Background")
            .setContentText("Tap to return to app")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .build();
    }
}
