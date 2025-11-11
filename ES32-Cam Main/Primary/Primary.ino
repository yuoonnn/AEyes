#include "esp_camera.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "driver/i2s.h"

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

// ===================== BLE CONFIG =====================
BLEServer *pServer = nullptr;
BLECharacteristic *pCharacteristic = nullptr;
BLEAdvertising *pAdvertising = nullptr;
bool deviceConnected = false;

#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcd1234-ab12-cd34-ef56-1234567890ab"
// Audio write characteristic (phone -> ESP32 I2S)
#define AUDIO_CHARACTERISTIC_UUID "f00dbabe-0000-4000-8000-000000000001"

// ===================== I2S (MAX98357A) CONFIG =====================
// ESP32-S3 WROOM suggested pins (free of camera usage):
// BCLK=GPIO40, LRCLK=GPIO39, DIN=GPIO38
#define I2S_BCLK  40
#define I2S_LRC   39
#define I2S_DOUT  38
static constexpr int AUDIO_SAMPLE_RATE = 16000; // 16 kHz, 16-bit, mono

// ===================== BUTTON CONFIG =====================
#define BUTTON_MANUAL_SCAN  1   // GPIO for testing manual scan

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

// Receive PCM audio from phone and output to MAX98357A via I2S
class AudioCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    auto v = c->getValue();
    if (!v.length()) return;
    size_t written = 0;
    const void *ptr = (const void*)v.c_str();
    size_t len = (size_t)v.length();
    // Write raw PCM (16 kHz, 16-bit LE, mono) to I2S
    i2s_write(I2S_NUM_0, ptr, len, &written, portMAX_DELAY);
  }
};

// Initialize I2S for MAX98357A
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

// ===================== CAMERA CAPTURE =====================
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

  // Send protocol header expected by the mobile app: "IMG\n<size>\n"
  // This header MUST be sent as a single notification before the binary chunks.
  {
    char header[32];
    int n = snprintf(header, sizeof(header), "IMG\n%d\n", fb->len);
    if (n > 0) {
      pCharacteristic->setValue((uint8_t*)header, (size_t)n);
      pCharacteristic->notify();
      Serial.printf("[BLE] Sent header: %s", header);
      delay(15); // small gap to keep header separate from first chunk
    } else {
      Serial.println("[WARN] Failed to format BLE header.");
    }
  }

  const size_t CHUNK_SIZE = 180;
  for (size_t i = 0; i < fb->len; i += CHUNK_SIZE) {
    size_t len = (i + CHUNK_SIZE < fb->len) ? CHUNK_SIZE : fb->len - i;
    pCharacteristic->setValue(fb->buf + i, len);
    pCharacteristic->notify();
    Serial.printf("[BLE] Sent %d/%d bytes\n", len, fb->len);
    delay(10);
  }

  esp_camera_fb_return(fb);
  Serial.println("[OK] Image sent via BLE.");
}

// ===================== SETUP =====================
void setup() {
  Serial.begin(115200);
  Serial.println("\n=== ESP32-S3 BLE Image Sender ===");

  pinMode(BUTTON_MANUAL_SCAN, INPUT_PULLUP);

  // ==== AUDIO (I2S) INIT ====
  setupI2S();

  // ==== CAMERA INIT ====
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

  // ==== BLE INIT ====
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

  // Audio write characteristic (phone -> ESP32 I2S)
  BLECharacteristic *pAudioChar = pService->createCharacteristic(
    AUDIO_CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pAudioChar->setCallbacks(new AudioCallbacks());

  pService->start();

  BLEDevice::setMTU(200);  // Increase MTU for larger chunks

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("[OK] BLE Advertising started.");
}

// ===================== LOOP =====================
void loop() {
  if (digitalRead(BUTTON_MANUAL_SCAN) == LOW) {
    delay(100); // debounce
    sendCameraImage();
    while (digitalRead(BUTTON_MANUAL_SCAN) == LOW); // wait for release
  }

  delay(50);
}
