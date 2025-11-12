/*
 * ESP32-S3 Wi-Fi Audio Receiver for Bone Conduction Speaker
 * 
 * This sketch receives audio streams via Wi-Fi HTTP POST requests
 * and plays them through the MAX98357A I2S amplifier to the bone conduction speaker.
 * 
 * Features:
 * - Wi-Fi Access Point (AP) mode or Station (STA) mode
 * - HTTP server to receive audio streams
 * - I2S audio output to MAX98357A
 * - BLE for images and button events (existing functionality)
 * 
 * Hardware:
 * - ESP32-S3 WROOM
 * - MAX98357A I2S amplifier
 * - Bone conduction speaker
 * - Camera (OV2640)
 * - 6 buttons
 */

 #include "esp_camera.h"
 #include <BLEDevice.h>
 #include <BLEServer.h>
 #include <BLEUtils.h>
 #include <BLE2902.h>
 #include "driver/i2s.h"
 #include <WiFi.h>
 #include <WebServer.h>
 #include <ArduinoJson.h>
 
 // ===================== CAMERA CONFIG (OV2640) =====================
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
 // Option 1: Access Point (AP) mode - ESP32 creates its own Wi-Fi network
 //const char* AP_SSID = "ESP32S3-AEyes";
 //const char* AP_PASSWORD = "aeyes1234"; // Min 8 chars for WPA2
 
 // Option 2: Station (STA) mode - ESP32 connects to existing Wi-Fi
 // Uncomment and configure if you want STA mode instead
 const char* STA_SSID = "HUAWEI-2.4G-e78Y";
 const char* STA_PASSWORD = "PediaSure1-3";
 
 WebServer server(8080); // HTTP server on port 8080
 
 // ===================== BLE CONFIG =====================
 BLEServer *pServer = nullptr;
 BLECharacteristic *pCharacteristic = nullptr;
 BLEAdvertising *pAdvertising = nullptr;
 bool deviceConnected = false;
 
 #define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
 #define CHARACTERISTIC_UUID "abcd1234-ab12-cd34-ef56-1234567890ab"
 #define AUDIO_CHARACTERISTIC_UUID "f00dbabe-0000-4000-8000-000000000001"
 #define BUTTONS_CHARACTERISTIC_UUID "f00dbabe-0000-4000-8000-000000000010"
 
 // ===================== I2S (MAX98357A) CONFIG =====================
 #define I2S_BCLK  40
 #define I2S_LRC   39
 #define I2S_DOUT  38
 static constexpr int AUDIO_SAMPLE_RATE = 16000; // 16 kHz, 16-bit, mono
 
 // Audio streaming state
 static volatile bool g_audioStreaming = false;
 static volatile int g_currentSampleRate = AUDIO_SAMPLE_RATE;
 static TaskHandle_t g_audioTaskHandle = nullptr;
 
 // Audio buffer queue
 #include <queue>
 std::queue<uint8_t*> g_audioBufferQueue;
 SemaphoreHandle_t g_audioQueueMutex = xSemaphoreCreateMutex();
 
 // ===================== BUTTON CONFIG =====================
 #define BUTTON1_PIN  1
 #define BUTTON2_PIN  2
 #define BUTTON3_PIN  3
 #define BUTTON4_PIN  14
 #define BUTTON5_PIN  21
 #define BUTTON6_PIN  47
 
 struct ButtonState {
   uint8_t pin;
   bool lastLevel;
   unsigned long pressStartMs;
   bool longSent;
 };
 
 static ButtonState g_buttons[] = {
   {BUTTON1_PIN, true, 0, false},
   {BUTTON2_PIN, true, 0, false},
   {BUTTON3_PIN, true, 0, false},
   {BUTTON4_PIN, true, 0, false},
   {BUTTON5_PIN, true, 0, false},
   {BUTTON6_PIN, true, 0, false},
 };
 
 static constexpr unsigned long LONG_HOLD_5S = 5000;
 static constexpr unsigned long LONG_HOLD_3S = 3000;
 static bool g_autoCaptureEnabled = false;
 static unsigned long g_lastAutoCaptureMs = 0;
 static constexpr unsigned long AUTO_CAPTURE_INTERVAL_MS = 5000; // 5 seconds for testing
 
 static BLECharacteristic *pButtonsChar = nullptr;
 
 // ===================== BLE CALLBACKS =====================
 class MyServerCallbacks : public BLEServerCallbacks {
   void onConnect(BLEServer *pServer) override {
     deviceConnected = true;
     Serial.println("[BLE] Client connected!");
   }
   void onDisconnect(BLEServer *pServer) override {
     deviceConnected = false;
     Serial.println("[BLE] Client disconnected, restarting advertising...");
     delay(500);
     BLEDevice::startAdvertising();
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
 
 // ===================== I2S INITIALIZATION =====================
 void setupI2S() {
   i2s_config_t cfg = {
     .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
     .sample_rate = AUDIO_SAMPLE_RATE,
     .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
     .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
     .communication_format = I2S_COMM_FORMAT_I2S_MSB,
     .intr_alloc_flags = 0,
     .dma_buf_count = 8,
     .dma_buf_len = 256,
     .use_apll = false,
     .tx_desc_auto_clear = true,
     .fixed_mclk = 0,
   };
 
   i2s_pin_config_t pins = {
     .bck_io_num = I2S_BCLK,
     .ws_io_num = I2S_LRC,
     .data_out_num = I2S_DOUT,
     .data_in_num = I2S_PIN_NO_CHANGE
   };
 
   if (i2s_driver_install(I2S_NUM_0, &cfg, 0, nullptr) != ESP_OK) {
     Serial.println("[AUDIO] i2s_driver_install failed");
     return;
   }
   if (i2s_set_pin(I2S_NUM_0, &pins) != ESP_OK) {
     Serial.println("[AUDIO] i2s_set_pin failed");
     return;
   }
   i2s_set_clk(I2S_NUM_0, AUDIO_SAMPLE_RATE, I2S_BITS_PER_SAMPLE_16BIT, I2S_CHANNEL_MONO);
   Serial.println("[AUDIO] I2S initialized (MAX98357A, 16kHz mono)");
 }
 
 // ===================== AUDIO PLAYBACK TASK =====================
 void audioPlaybackTask(void *parameter) {
   const size_t chunkSize = 256;
   uint8_t* buffer = (uint8_t*)malloc(chunkSize * sizeof(int16_t));
   
   if (buffer == nullptr) {
     Serial.println("[AUDIO] Failed to allocate playback buffer");
     vTaskDelete(nullptr);
     return;
   }
 
   while (true) {
     // Check if we have audio data to play
     xSemaphoreTake(g_audioQueueMutex, portMAX_DELAY);
     bool hasData = !g_audioBufferQueue.empty();
     xSemaphoreGive(g_audioQueueMutex);
 
     if (hasData && g_audioStreaming) {
       // Get audio data from queue
       xSemaphoreTake(g_audioQueueMutex, portMAX_DELAY);
       if (!g_audioBufferQueue.empty()) {
         uint8_t* audioData = g_audioBufferQueue.front();
         g_audioBufferQueue.pop();
         size_t dataSize = *(size_t*)audioData; // First 4 bytes are size
         uint8_t* actualData = audioData + sizeof(size_t);
         
         xSemaphoreGive(g_audioQueueMutex);
 
         // Play audio data
         size_t written = 0;
         i2s_write(I2S_NUM_0, actualData, dataSize, &written, portMAX_DELAY);
         
         // Free buffer
         free(audioData);
       } else {
         xSemaphoreGive(g_audioQueueMutex);
       }
     } else {
       vTaskDelay(pdMS_TO_TICKS(10)); // Small delay when no data
     }
   }
 }
 
 // ===================== WIFI SETUP =====================
 void setupWiFi() {
   // Try STA mode first (if configured), otherwise use AP mode
   #ifdef STA_SSID
   WiFi.mode(WIFI_STA);
   WiFi.begin(STA_SSID, STA_PASSWORD);
   Serial.print("[WIFI] Connecting to ");
   Serial.print(STA_SSID);
   
   int attempts = 0;
   while (WiFi.status() != WL_CONNECTED && attempts < 20) {
     delay(500);
     Serial.print(".");
     attempts++;
   }
   
   if (WiFi.status() == WL_CONNECTED) {
     Serial.println("");
     Serial.print("[WIFI] Connected! IP address: ");
     Serial.println(WiFi.localIP());
     return;
   }
   Serial.println("");
   Serial.println("[WIFI] Failed to connect to STA, falling back to AP mode");
   #endif
 
   // AP mode (Access Point)
   WiFi.mode(WIFI_AP);
   WiFi.softAP(AP_SSID, AP_PASSWORD);
   IPAddress IP = WiFi.softAPIP();
   Serial.print("[WIFI] AP mode - SSID: ");
   Serial.print(AP_SSID);
   Serial.print(", IP address: ");
   Serial.println(IP);
 }
 
 // ===================== HTTP SERVER HANDLERS =====================
 void handlePing() {
   server.send(200, "text/plain", "OK");
 }
 
 void handleAudio() {
   if (server.method() != HTTP_POST) {
     server.send(405, "text/plain", "Method Not Allowed");
     return;
   }
 
   // Get audio parameters from form data
   int sampleRate = server.arg("sample_rate").toInt();
   int bitsPerSample = server.arg("bits_per_sample").toInt();
   int channels = server.arg("channels").toInt();
   int dataSize = server.arg("data_size").toInt();
 
   if (sampleRate == 0) sampleRate = AUDIO_SAMPLE_RATE;
   if (bitsPerSample == 0) bitsPerSample = 16;
   if (channels == 0) channels = 1;
 
   // Update I2S sample rate if changed
   if (sampleRate != g_currentSampleRate) {
     g_currentSampleRate = sampleRate;
     i2s_set_clk(I2S_NUM_0, g_currentSampleRate, I2S_BITS_PER_SAMPLE_16BIT, I2S_CHANNEL_MONO);
     Serial.printf("[AUDIO] Sample rate updated to %d Hz\n", sampleRate);
   }
 
   // Check if audio data is in the request
   if (server.hasArg("audio_data")) {
     String audioData = server.arg("audio_data");
     size_t audioLen = audioData.length();
     
     if (audioLen > 0) {
       // Allocate buffer for audio data
       uint8_t* buffer = (uint8_t*)malloc(sizeof(size_t) + audioLen);
       if (buffer != nullptr) {
         *(size_t*)buffer = audioLen;
         memcpy(buffer + sizeof(size_t), audioData.c_str(), audioLen);
         
         // Add to queue
         xSemaphoreTake(g_audioQueueMutex, portMAX_DELAY);
         g_audioBufferQueue.push(buffer);
         g_audioStreaming = true;
         xSemaphoreGive(g_audioQueueMutex);
         
         Serial.printf("[AUDIO] Received %d bytes, sample rate: %d Hz\n", audioLen, sampleRate);
         server.send(200, "text/plain", "OK");
       } else {
         server.send(507, "text/plain", "Insufficient Storage");
       }
     } else {
       server.send(400, "text/plain", "No audio data");
     }
   } else {
     // Try to get raw binary data from request body
     if (server.hasArg("plain")) {
       String audioData = server.arg("plain");
       // Similar handling as above
       server.send(200, "text/plain", "OK");
     } else {
       server.send(400, "text/plain", "No audio data found");
     }
   }
 }
 
 void handleAudioStart() {
   if (server.method() != HTTP_POST) {
     server.send(405, "text/plain", "Method Not Allowed");
     return;
   }
 
   // Parse JSON request body
   if (server.hasArg("plain")) {
     String body = server.arg("plain");
     StaticJsonDocument<200> doc;
     deserializeJson(doc, body);
     
     int sampleRate = doc["sample_rate"] | AUDIO_SAMPLE_RATE;
     int bitsPerSample = doc["bits_per_sample"] | 16;
     int channels = doc["channels"] | 1;
     
     // Update I2S configuration
     if (sampleRate != g_currentSampleRate) {
       g_currentSampleRate = sampleRate;
       i2s_set_clk(I2S_NUM_0, g_currentSampleRate, I2S_BITS_PER_SAMPLE_16BIT, I2S_CHANNEL_MONO);
     }
     
     g_audioStreaming = true;
     Serial.printf("[AUDIO] Stream started: %d Hz, %d-bit, %d channel(s)\n", 
                   sampleRate, bitsPerSample, channels);
     server.send(200, "text/plain", "OK");
   } else {
     server.send(400, "text/plain", "Invalid request");
   }
 }
 
 void handleAudioChunked() {
   if (server.method() != HTTP_POST) {
     server.send(405, "text/plain", "Method Not Allowed");
     return;
   }
 
   // Get Content-Length header
   int contentLength = server.headers().has("Content-Length") 
     ? server.header("Content-Length").toInt() 
     : 0;
 
   if (contentLength == 0) {
     server.send(400, "text/plain", "No content length");
     return;
   }
 
   // Limit chunk size to prevent memory issues (max 8KB)
   if (contentLength > 8192) {
     server.send(413, "text/plain", "Chunk too large");
     return;
   }
 
   // Read binary data from request body
   WiFiClient client = server.client();
   uint8_t* buffer = (uint8_t*)malloc(sizeof(size_t) + contentLength);
   
   if (buffer == nullptr) {
     server.send(507, "text/plain", "Insufficient Storage");
     return;
   }
 
   // Store size in first 4 bytes
   *(size_t*)buffer = contentLength;
   
   // Read binary data directly from client
   size_t bytesRead = 0;
   uint8_t* dataPtr = buffer + sizeof(size_t);
   
   unsigned long startTime = millis();
   while (bytesRead < contentLength && (millis() - startTime) < 5000) {
     if (client.available()) {
       size_t toRead = min((size_t)client.available(), contentLength - bytesRead);
       size_t actuallyRead = client.readBytes(dataPtr + bytesRead, toRead);
       bytesRead += actuallyRead;
     } else {
       delay(1);
     }
   }
 
   if (bytesRead != contentLength) {
     free(buffer);
     server.send(400, "text/plain", "Incomplete data");
     Serial.printf("[AUDIO] Failed to read chunk: expected %d, got %d\n", contentLength, bytesRead);
     return;
   }
 
   // Add to queue
   xSemaphoreTake(g_audioQueueMutex, portMAX_DELAY);
   g_audioBufferQueue.push(buffer);
   g_audioStreaming = true;
   xSemaphoreGive(g_audioQueueMutex);
 
   Serial.printf("[AUDIO] Received chunk: %d bytes\n", contentLength);
   server.send(200, "text/plain", "OK");
 }
 
 void handleAudioEnd() {
   g_audioStreaming = false;
   Serial.println("[AUDIO] Stream ended");
   server.send(200, "text/plain", "OK");
 }
 
 void handleAudioStop() {
   g_audioStreaming = false;
   
   // Clear audio queue
   xSemaphoreTake(g_audioQueueMutex, portMAX_DELAY);
   while (!g_audioBufferQueue.empty()) {
     uint8_t* buffer = g_audioBufferQueue.front();
     g_audioBufferQueue.pop();
     free(buffer);
   }
   xSemaphoreGive(g_audioQueueMutex);
   
   Serial.println("[AUDIO] Stopped and queue cleared");
   server.send(200, "text/plain", "OK");
 }
 
 void handleStatus() {
   StaticJsonDocument<200> doc;
   doc["status"] = "connected";
   doc["ip"] = WiFi.softAPIP().toString();
   doc["sample_rate"] = g_currentSampleRate;
   doc["streaming"] = g_audioStreaming;
   doc["queue_size"] = g_audioBufferQueue.size();
   
   String response;
   serializeJson(doc, response);
   server.send(200, "application/json", response);
 }
 
 void setupServer() {
   server.on("/ping", handlePing);
   server.on("/audio", HTTP_POST, handleAudio);
   server.on("/audio_start", HTTP_POST, handleAudioStart);
   server.on("/audio_chunked", HTTP_POST, handleAudioChunked);
   server.on("/audio_end", HTTP_POST, handleAudioEnd);
   server.on("/audio_stop", HTTP_POST, handleAudioStop);
   server.on("/status", handleStatus);
   
   server.begin();
   Serial.println("[HTTP] Server started on port 8080");
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
     Serial.println("[WARN] No BLE client connected. Cannot send image.");
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
       Serial.printf("[BLE] Sent header: %s", header);
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
   Serial.println("\n=== ESP32-S3 Wi-Fi Audio Receiver ===");
 
   // Buttons init
   for (auto &b : g_buttons) {
     pinMode(b.pin, INPUT_PULLUP);
     b.lastLevel = digitalRead(b.pin);
     b.pressStartMs = 0;
     b.longSent = false;
   }
 
   // I2S setup
   setupI2S();
 
   // Create audio playback task
   xTaskCreate(audioPlaybackTask, "AudioPlayback", 4096, nullptr, 5, &g_audioTaskHandle);
 
   // Camera setup
   setupCamera();
 
   // Wi-Fi setup
   setupWiFi();
 
   // HTTP server setup
   setupServer();
 
   // BLE setup
   BLEDevice::init("ESP32S3-CAM (AEyes)");
   pServer = BLEDevice::createServer();
   pServer->setCallbacks(new MyServerCallbacks());
 
   BLEService *pService = pServer->createService(SERVICE_UUID);
 
   pCharacteristic = pService->createCharacteristic(
     CHARACTERISTIC_UUID,
     BLECharacteristic::PROPERTY_NOTIFY
   );
 
   BLE2902 *desc = new BLE2902();
   desc->setNotifications(true);
   pCharacteristic->addDescriptor(desc);
 
   pButtonsChar = pService->createCharacteristic(
     BUTTONS_CHARACTERISTIC_UUID,
     BLECharacteristic::PROPERTY_NOTIFY
   );
   {
     BLE2902 *bdesc = new BLE2902();
     bdesc->setNotifications(true);
     pButtonsChar->addDescriptor(bdesc);
   }
 
   pService->start();
 
   BLEDevice::setMTU(200);
   pAdvertising = BLEDevice::getAdvertising();
   pAdvertising->addServiceUUID(SERVICE_UUID);
   pAdvertising->setScanResponse(true);
   BLEDevice::startAdvertising();
 
   Serial.println("[OK] BLE Advertising started.");
   Serial.println("[OK] System ready!");
 }
 
 // ===================== LOOP =====================
 void loop() {
   // Handle HTTP server requests
   server.handleClient();
 
   // Handle buttons (same as before)
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
         } else {
           unsigned long held = now - b.pressStartMs;
           unsigned long need = (i == 4 || i == 5) ? LONG_HOLD_3S : LONG_HOLD_5S;
           bool wasLong = held >= need;
           
           if (i == 1 && !wasLong) {
             notifyButtonEvent(2, "CAPTURE");
             sendCameraImage();
           } else if (i == 1 && wasLong) {
             g_autoCaptureEnabled = !g_autoCaptureEnabled;
             notifyButtonEvent(2, g_autoCaptureEnabled ? "AUTO_ON" : "AUTO_OFF");
           }
           // Add other button handlers as needed
         }
       }
     }
   }
 
   // Auto capture
   if (g_autoCaptureEnabled && deviceConnected && (now - g_lastAutoCaptureMs) >= AUTO_CAPTURE_INTERVAL_MS) {
     g_lastAutoCaptureMs = now;
     notifyButtonEvent(2, "AUTO_CAPTURE");
     sendCameraImage();
   }
 
   delay(20);
 }
 
 