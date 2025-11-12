/*
 * ESP32-S3 BLE Image Sender (Audio-Free Version)
 * Camera + BLE image transfer only
 */

 #include "esp_camera.h"
 #include <BLEDevice.h>
 #include <BLEServer.h>
 #include <BLEUtils.h>
 #include <BLE2902.h>
 
 // ===================== CAMERA CONFIG =====================
 #define PWDN_GPIO_NUM  -1
 #define RESET_GPIO_NUM -1
 #define XCLK_GPIO_NUM  15
 #define SIOD_GPIO_NUM  4
 #define SIOC_GPIO_NUM  5
 #define Y2_GPIO_NUM    11
 #define Y3_GPIO_NUM    9
 #define Y4_GPIO_NUM    8
 #define Y5_GPIO_NUM    10
 #define Y6_GPIO_NUM    12
 #define Y7_GPIO_NUM    18
 #define Y8_GPIO_NUM    17
 #define Y9_GPIO_NUM    16
 #define VSYNC_GPIO_NUM 6
 #define HREF_GPIO_NUM  7
 #define PCLK_GPIO_NUM  13
 
 // ===================== WIFI CONFIG =====================
 const char* STA_SSID = "HUAWEI-2.4G-e78Y";
 const char* STA_PASSWORD = "PediaSure1-3";
 
 #include <WiFi.h>
 #include <WebServer.h>
 WebServer server(8080);
 
 // ===================== BLE CONFIG =====================
 BLEServer *pServer = nullptr;
 BLECharacteristic *pCharacteristic = nullptr;
 bool deviceConnected = false;
 
 #define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
 #define CHARACTERISTIC_UUID "abcd1234-ab12-cd34-ef56-1234567890ab"
 #define BUTTONS_CHARACTERISTIC_UUID "f00dbabe-0000-4000-8000-000000000010"
 BLECharacteristic *pButtonsChar = nullptr;
 
 // ===================== BUTTON CONFIG =====================
 #define BUTTON1_PIN  1 // power button - hold for 5 seconds on/off
 #define BUTTON2_PIN  2 // tap for manual scan, hold for 5 seconds to enable/disable auto-scan
 #define BUTTON3_PIN  3 // push-to-talk open mic when held then capture after
 #define BUTTON4_PIN  14 // Tap play/Pause Media Control
 #define BUTTON5_PIN  21 // Tap volume up, hold for 5 seconds to skip track
 #define BUTTON6_PIN  47 // tap volume down, hold for 5 seconds to previous 
 
 struct ButtonState {
   uint8_t pin;
   bool lastLevel;
   unsigned long pressStartMs;
   bool longSent;
 };
 
 static ButtonState g_buttons[] = {
   {BUTTON1_PIN, true, 0, false}, {BUTTON2_PIN, true, 0, false},
   {BUTTON3_PIN, true, 0, false}, {BUTTON4_PIN, true, 0, false},
   {BUTTON5_PIN, true, 0, false}, {BUTTON6_PIN, true, 0, false},
 };
 
static bool g_autoCaptureEnabled = false;
static unsigned long g_lastAutoCaptureMs = 0;
static constexpr unsigned long AUTO_CAPTURE_INTERVAL_MS = 120000;

// Forward declaration
void sendCameraImage();

// ===================== BLE CALLBACKS =====================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Client connected!");
  }
  void onDisconnect(BLEServer *pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Client disconnected");
    delay(500);
    BLEDevice::startAdvertising();
  }
};

// Callback to handle write commands on the image characteristic
class ImageCharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    // getValue() returns Arduino String
    String value = pCharacteristic->getValue();
    
    // Check if the command is "CAPTURE" (with or without newline)
    if (value.indexOf("CAPTURE") >= 0) {
      Serial.println("[CMD] Received CAPTURE command from app");
      sendCameraImage();
    } else {
      Serial.printf("[CMD] Received unknown command: %s\n", value.c_str());
    }
  }
};
 
static inline void notifyButtonEvent(int btn, const char *event) {
  if (!deviceConnected || pButtonsChar == nullptr) return;
  char msg[32];
  int n = snprintf(msg, sizeof(msg), "BTN\n%d\n%s\n", btn, event);
  if (n > 0) {
    pButtonsChar->setValue((uint8_t*)msg, (size_t)n);
    pButtonsChar->notify();
    Serial.printf("[BTN] %s", msg);
  }
}

// Send voice command text to phone (ESP32 processes voice to text, then sends it)
static inline void sendVoiceCommand(const char *voiceText) {
  if (!deviceConnected || pButtonsChar == nullptr) return;
  char msg[128];
  int n = snprintf(msg, sizeof(msg), "VOICE\n%s\n", voiceText);
  if (n > 0) {
    pButtonsChar->setValue((uint8_t*)msg, (size_t)n);
    pButtonsChar->notify();
    Serial.printf("[VOICE] Sent: %s\n", voiceText);
  }
}

// Send recording control commands to phone
static inline void sendRecordingCommand(const char *command) {
  if (!deviceConnected || pButtonsChar == nullptr) return;
  char msg[32];
  int n = snprintf(msg, sizeof(msg), "RECORD\n%s\n", command);
  if (n > 0) {
    pButtonsChar->setValue((uint8_t*)msg, (size_t)n);
    pButtonsChar->notify();
    Serial.printf("[RECORD] Sent: %s\n", command);
  }
}
 
 // ===================== WIFI SETUP =====================
 void setupWiFi() {
   WiFi.mode(WIFI_STA);
   WiFi.begin(STA_SSID, STA_PASSWORD);
   Serial.print("[WIFI] Connecting to ");
   Serial.print(STA_SSID);
   
   int attempts = 0;
   while (WiFi.status() != WL_CONNECTED && attempts < 30) {
     delay(500);
     Serial.print(".");
     attempts++;
   }
   
   if (WiFi.status() == WL_CONNECTED) {
     Serial.println("");
     Serial.print("[WIFI] ✅ Connected! IP: ");
     Serial.println(WiFi.localIP());
   } else {
     Serial.println("");
     Serial.println("[WIFI] ❌ Failed to connect");
   }
 }
 
 // ===================== HTTP SERVER HANDLERS =====================
 void handlePing() {
   server.send(200, "text/plain", "OK");
 }
 
 void setupServer() {
   server.on("/ping", handlePing);
   server.begin();
   Serial.println("[HTTP] ✅ Server started on port 8080");
 }
 
 // ===================== CAMERA SETUP =====================
 void setupCamera() {
   camera_config_t config;
   config.ledc_channel = LEDC_CHANNEL_0;
   config.ledc_timer = LEDC_TIMER_0;
   config.pin_d0 = Y2_GPIO_NUM;
   config.pin_d1 = Y3_GPIO_NUM;
   config.pin_d2 = Y4_GPIO_NUM;
   config.pin_d3 = Y5_GPIO_NUM;
   config.pin_d4 = Y6_GPIO_NUM;
   config.pin_d5 = Y7_GPIO_NUM;
   config.pin_d6 = Y8_GPIO_NUM;
   config.pin_d7 = Y9_GPIO_NUM;
   config.pin_xclk = XCLK_GPIO_NUM;
   config.pin_pclk = PCLK_GPIO_NUM;
   config.pin_vsync = VSYNC_GPIO_NUM;
   config.pin_href = HREF_GPIO_NUM;
   config.pin_sscb_sda = SIOD_GPIO_NUM;
   config.pin_sscb_scl = SIOC_GPIO_NUM;
   config.pin_pwdn = PWDN_GPIO_NUM;
   config.pin_reset = RESET_GPIO_NUM;
   config.xclk_freq_hz = 20000000;
   config.pixel_format = PIXFORMAT_JPEG;
 
   if (psramFound()) {
     config.frame_size = FRAMESIZE_QVGA;
     config.jpeg_quality = 12;
     config.fb_count = 2;
     config.fb_location = CAMERA_FB_IN_PSRAM;
   } else {
     config.frame_size = FRAMESIZE_QQVGA;
     config.jpeg_quality = 20;
     config.fb_count = 1;
     config.fb_location = CAMERA_FB_IN_DRAM;
   }
 
   if (esp_camera_init(&config) != ESP_OK) {
     Serial.println("[ERROR] Camera init failed");
     delay(3000);
     ESP.restart();
   } else {
     Serial.println("[OK] Camera initialized.");
   }
 }
 
 void sendCameraImage() {
   Serial.println("[ACTION] Manual scan triggered — capturing image...");
   if (!deviceConnected) {
     Serial.println("[WARN] No BLE client connected");
     return;
   }
 
   camera_fb_t *fb = esp_camera_fb_get();
   if (!fb) {
     Serial.println("[ERROR] Camera capture failed");
     return;
   }
 
   Serial.printf("[INFO] Captured %d bytes\n", fb->len);
 
   {
     char header[32];
     int n = snprintf(header, sizeof(header), "IMG\n%d\n", fb->len);
     if (n > 0) {
       pCharacteristic->setValue((uint8_t*)header, (size_t)n);
       pCharacteristic->notify();
       delay(15);
     }
   }
 
   const size_t CHUNK_SIZE = 180;
   for (size_t i = 0; i < fb->len; i += CHUNK_SIZE) {
     size_t len = (i + CHUNK_SIZE < fb->len) ? CHUNK_SIZE : fb->len - i;
     pCharacteristic->setValue(fb->buf + i, len);
     pCharacteristic->notify();
     delay(10);
   }
 
   esp_camera_fb_return(fb);
   Serial.println("[OK] Image sent via BLE.");
 }
 
 // ===================== SETUP =====================
 void setup() {
   Serial.begin(115200);
   Serial.println("\n=== ESP32-S3 BLE Image Sender (No Audio) ===");
 
   // Buttons init
   for (auto &b : g_buttons) {
     pinMode(b.pin, INPUT_PULLUP);
     b.lastLevel = digitalRead(b.pin);
     b.pressStartMs = 0;
     b.longSent = false;
   }
 
   // Camera setup
   setupCamera();
 
   // Wi-Fi setup (optional, for future extensions)
   setupWiFi();
 
   // HTTP server setup (optional, for ping/status)
   setupServer();
 
   // BLE setup
   BLEDevice::init("ESP32S3-CAM (AEyes)");
   pServer = BLEDevice::createServer();
   pServer->setCallbacks(new MyServerCallbacks());
 
   BLEService *pService = pServer->createService(SERVICE_UUID);
 
  // Image characteristic: both NOTIFY (for sending images) and WRITE (for receiving CAPTURE command)
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_WRITE
  );

  // Set callback to handle write commands (CAPTURE command from app)
  pCharacteristic->setCallbacks(new ImageCharacteristicCallbacks());

  BLE2902 *desc = new BLE2902();
  desc->setNotifications(true);
  pCharacteristic->addDescriptor(desc);
 
   pButtonsChar = pService->createCharacteristic(
     BUTTONS_CHARACTERISTIC_UUID,
     BLECharacteristic::PROPERTY_NOTIFY
   );
   BLE2902 *bdesc = new BLE2902();
   bdesc->setNotifications(true);
   pButtonsChar->addDescriptor(bdesc);
 
   pService->start();
 
   BLEDevice::setMTU(200);
   pServer->getAdvertising()->addServiceUUID(SERVICE_UUID);
   pServer->getAdvertising()->setScanResponse(true);
   BLEDevice::startAdvertising();
 
   Serial.println("[OK] BLE Advertising started.");
   Serial.println("[OK] 🎯 System ready - Camera + BLE only");
 }
 
// ===================== LOOP =====================
void loop() {
   server.handleClient();
 
   unsigned long now = millis();
   for (int i = 0; i < 6; i++) {
     auto &b = g_buttons[i];
     bool level = digitalRead(b.pin);
     if (b.lastLevel != level) {
       delay(5);
       level = digitalRead(b.pin);
         if (b.lastLevel != level) {
           b.lastLevel = level;
           if (level == LOW) {
             b.pressStartMs = now;
             b.longSent = false;
             
             // Button 3 - push-to-talk: Send START_RECORDING when pressed
             if (i == 2) {
               sendRecordingCommand("START_RECORDING");
             }
           } else {
           unsigned long held = now - b.pressStartMs;
           bool wasLong = held >= 5000; // 5 second hold for all buttons
           
           // Button 1 - power button
           if (i == 0) {
             if (!wasLong) {
               notifyButtonEvent(1, "POWER_SHORT");
               // Short press action for power button
             } else {
               notifyButtonEvent(1, "POWER_LONG");
               // Long press action for power button (on/off)
             }
           }
           // Button 2 - manual/auto scan
           else if (i == 1) {
             if (!wasLong) {
               notifyButtonEvent(2, "CAPTURE");
               sendCameraImage();
             } else {
               g_autoCaptureEnabled = !g_autoCaptureEnabled;
               notifyButtonEvent(2, g_autoCaptureEnabled ? "AUTO_ON" : "AUTO_OFF");
             }
           }
          // Button 3 - push-to-talk
          else if (i == 2) {
            if (!wasLong) {
              notifyButtonEvent(3, "PTT_SHORT");
              // Short press action for PTT
            } else {
              notifyButtonEvent(3, "PTT_LONG");
              // Long press action for PTT - phone records voice, then captures image
              // Flow: Button released after long press → Phone stops recording → Phone processes to text → Phone sends CAPTURE command → ESP32 captures image
              // Note: START_RECORDING is sent when button is first pressed (see below)
              // STOP_RECORDING is sent here when button is released
              // ESP32 will wait for CAPTURE command from phone (sent after transcription completes)
              sendRecordingCommand("STOP_RECORDING");
              
              // Don't capture image here - wait for phone to send CAPTURE command after transcription
              // The phone will call requestImageCapture() which sends "CAPTURE" command
            }
          }
           // Button 4 - media control
           else if (i == 3) {
             if (!wasLong) {
               notifyButtonEvent(4, "MEDIA_PLAYPAUSE");
               // Tap for play/pause
             } else {
               notifyButtonEvent(4, "MEDIA_LONG");
               // Long press action for media button
             }
           }
           // Button 5 - volume up / skip track
           else if (i == 4) {
             if (!wasLong) {
               notifyButtonEvent(5, "VOLUME_UP");
               // Tap for volume up
             } else {
               notifyButtonEvent(5, "SKIP_TRACK");
               // Hold for skip track
             }
           }
           // Button 6 - volume down / previous track
           else if (i == 5) {
             if (!wasLong) {
               notifyButtonEvent(6, "VOLUME_DOWN");
               // Tap for volume down
             } else {
               notifyButtonEvent(6, "PREVIOUS_TRACK");
               // Hold for previous track
             }
           }
         }
       }
     }
   }
 
   if (g_autoCaptureEnabled && deviceConnected && (now - g_lastAutoCaptureMs) >= AUTO_CAPTURE_INTERVAL_MS) {
     g_lastAutoCaptureMs = now;
     notifyButtonEvent(2, "AUTO_CAPTURE");
     sendCameraImage();
   }
 
   delay(20);
 }