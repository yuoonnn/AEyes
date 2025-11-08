# ESP32-S3 Bluetooth Detection Troubleshooting Guide

## Common Issues and Solutions

### 1. **ESP32 Not Detected During Scan**

#### Check ESP32 Side:
- ✅ **ESP32 is powered on** - Check LED indicators
- ✅ **ESP32 is in BLE advertising mode** - Make sure the ESP32 code is running and advertising
- ✅ **ESP32 BLE name is set** - Check if ESP32 has a recognizable name (e.g., "ESP32", "AEyes", etc.)
- ✅ **ESP32 is not already connected** - Disconnect from other devices first

#### Check Phone Side:
- ✅ **Bluetooth is enabled** - Check phone settings
- ✅ **Location permission is granted** - Android requires location permission for BLE scanning
- ✅ **App has Bluetooth permissions** - Check app permissions in phone settings
- ✅ **Phone is close to ESP32** - Try within 1-2 meters for initial connection

### 2. **Location Permission Required**

**Why?** Android requires location permission to scan for BLE devices (privacy feature).

**How to grant:**
1. Go to Phone Settings → Apps → AEyes User App
2. Tap "Permissions"
3. Enable "Location" permission
4. Restart the app

### 3. **Bluetooth Permissions (Android 12+)**

The app requests these permissions automatically, but you can check:
1. Phone Settings → Apps → AEyes User App → Permissions
2. Make sure "Bluetooth" and "Location" are enabled

### 4. **ESP32 Not Advertising**

**Check ESP32 code:**
```cpp
// ESP32 should be advertising with a name
BLEDevice::init("ESP32-AEyes");  // Set a recognizable name
BLEServer *pServer = BLEDevice::createServer();
BLEService *pService = pServer->createService(SERVICE_UUID);
pService->start();
BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
pAdvertising->addServiceUUID(SERVICE_UUID);
pAdvertising->setScanResponse(true);
pAdvertising->setMinPreferred(0x06);
BLEDevice::startAdvertising();
```

### 5. **Scan Timeout Too Short**

**Solution:** The app now scans for 15 seconds by default. If ESP32 still isn't found:
- Make sure ESP32 is advertising continuously
- Try moving phone closer to ESP32
- Check if ESP32 appears in other BLE scanner apps

### 6. **Device Shows as "Unknown Device"**

**This is normal!** If ESP32 doesn't have a name set, it will show as "Unknown Device" with its MAC address.

**How to identify ESP32:**
- Look for devices with strong RSSI (signal strength)
- Check the device ID - ESP32 MAC addresses usually start with specific patterns
- Devices with "ESP" or "ESP32" in the name will be highlighted in green

### 7. **Multiple ESP32 Devices**

If multiple ESP32 devices are nearby:
- All will be shown in the list
- Devices are sorted by signal strength (RSSI) - strongest first
- ESP32 devices are highlighted in green with an "ESP32" badge

### 8. **Connection Fails After Detection**

**Possible causes:**
- ESP32 is already connected to another device
- ESP32 went to sleep or stopped advertising
- Connection timeout (15 seconds)
- ESP32 services not properly configured

**Solution:**
- Make sure ESP32 is ready to accept connections
- Check ESP32 serial monitor for connection attempts
- Try disconnecting and reconnecting

## Debugging Steps

### Step 1: Check App Logs
1. Open the app
2. Go to Bluetooth screen
3. Tap "Scan for Devices"
4. Check the console/logs for:
   - `Started BLE scan`
   - `Found BLE device: [name]`
   - Any error messages

### Step 2: Verify ESP32 is Advertising
1. Use another BLE scanner app (e.g., "nRF Connect" or "BLE Scanner")
2. Scan for devices
3. Check if ESP32 appears in the list
4. If it appears there but not in our app, check permissions

### Step 3: Check Permissions
1. Phone Settings → Apps → AEyes User App → Permissions
2. Verify:
   - ✅ Location: Allowed
   - ✅ Bluetooth: Allowed (Android 12+)
   - ✅ Nearby devices: Allowed (Android 12+)

### Step 4: Test with Different Phone
- Try scanning with a different Android phone
- This helps identify if it's a phone-specific issue

## ESP32 Code Checklist

Make sure your ESP32 code includes:

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// 1. Initialize BLE with a name
BLEDevice::init("ESP32-AEyes");

// 2. Create server
BLEServer *pServer = BLEDevice::createServer();

// 3. Create service
BLEService *pService = pServer->createService(SERVICE_UUID);

// 4. Create characteristics
BLECharacteristic *pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
);

// 5. Start service
pService->start();

// 6. Start advertising
BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
pAdvertising->addServiceUUID(SERVICE_UUID);
pAdvertising->setScanResponse(true);
pAdvertising->setMinPreferred(0x06);
BLEDevice::startAdvertising();

// 7. Keep advertising (don't stop)
// Advertising should continue until connected
```

## Quick Test

1. **Enable Bluetooth** on phone
2. **Grant Location permission** to the app
3. **Power on ESP32** and make sure it's advertising
4. **Open app** → Bluetooth screen
5. **Tap "Scan for Devices"**
6. **Wait 15 seconds** for scan to complete
7. **Check device list** - ESP32 should appear

## Still Not Working?

1. **Check console logs** for specific error messages
2. **Try another BLE scanner app** to verify ESP32 is advertising
3. **Check ESP32 serial monitor** for any errors
4. **Verify ESP32 code** is correct and running
5. **Try resetting ESP32** and restarting the app
6. **Check phone Bluetooth settings** - make sure it's not in airplane mode

## App Improvements Made

✅ **Increased scan timeout** to 15 seconds
✅ **Better error messages** showing what to check
✅ **Bluetooth state checking** before scanning
✅ **Permission checking** with helpful messages
✅ **Device sorting by RSSI** (signal strength)
✅ **ESP32 device highlighting** in green
✅ **Better debugging** with console logs
✅ **Improved UI** with troubleshooting tips

## Contact

If ESP32 still doesn't appear after trying all these steps, check:
- ESP32 serial monitor output
- App console logs
- Phone Bluetooth settings
- ESP32 hardware connections

