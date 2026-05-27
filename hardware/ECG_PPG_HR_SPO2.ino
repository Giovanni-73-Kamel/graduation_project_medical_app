#include <HTTPClient.h>
#include <WiFi.h>
#include <Wire.h>
#include <sys/time.h>
#include <time.h>

#include "MAX30105.h"

#if __has_include("config.h")
#include "config.h"
#else
#define WIFI_SSID ""
#define WIFI_PASSWORD ""
#define BACKEND_READINGS_URL "http://192.168.1.10:8000/api/readings"
#define DEVICE_ID "device_001"
#define SESSION_ID "session_001"
#define FIRMWARE_VERSION "ecg-ppg-1.0"
#define DEVICE_API_KEY ""
#define BATTERY_PERCENT_FALLBACK 100
#endif

#ifndef ECG_PIN
#define ECG_PIN 34
#endif

#ifndef LO_PLUS_PIN
#define LO_PLUS_PIN 32
#endif

#ifndef LO_MINUS_PIN
#define LO_MINUS_PIN 33
#endif

#ifndef BATTERY_PIN
#define BATTERY_PIN -1
#endif

#define SAMPLING_RATE_HZ 250
#define SAMPLE_INTERVAL_US (1000000UL / SAMPLING_RATE_HZ)
#define BATCH_SIZE 125
#define WIFI_RETRY_MS 5000
#define HTTP_RETRY_MS 3000
#define HTTP_TIMEOUT_MS 2500

MAX30105 particleSensor;

struct SampleBatch {
  float ecg[BATCH_SIZE];
  long ppg[BATCH_SIZE];
  int count = 0;
  unsigned long startedAtMs = 0;
};

SampleBatch activeBatch;
SampleBatch pendingBatch;

bool pendingReady = false;
unsigned long nextWifiAttemptMs = 0;
unsigned long nextUploadAttemptMs = 0;
unsigned long lastSampleUs = 0;
unsigned long droppedBatches = 0;
long irBaseline = 0;
String sessionId;

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }
  const unsigned long now = millis();
  if (now < nextWifiAttemptMs) {
    return;
  }
  nextWifiAttemptMs = now + WIFI_RETRY_MS;

  if (String(WIFI_SSID).length() == 0) {
    Serial.println("WiFi SSID is empty. Create hardware/config.h from config.example.h.");
    return;
  }

  Serial.print("Connecting WiFi to ");
  Serial.println(WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void syncClock() {
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.println("NTP time sync requested.");
}

String isoTimestamp() {
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  if (tv.tv_sec < 1700000000) {
    char fallback[40];
    snprintf(
      fallback,
      sizeof(fallback),
      "1970-01-01T00:%02lu:%02lu.%03luZ",
      (millis() / 60000UL) % 60,
      (millis() / 1000UL) % 60,
      millis() % 1000UL
    );
    return String(fallback);
  }

  struct tm timeinfo;
  gmtime_r(&tv.tv_sec, &timeinfo);
  char buffer[40];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  char withMillis[48];
  snprintf(withMillis, sizeof(withMillis), "%s.%03ldZ", buffer, tv.tv_usec / 1000L);
  return String(withMillis);
}

int readBatteryPercent() {
#if BATTERY_PIN >= 0
  int raw = analogRead(BATTERY_PIN);
  return constrain(map(raw, 0, 4095, 0, 100), 0, 100);
#else
  return BATTERY_PERCENT_FALLBACK;
#endif
}

bool leadsOff() {
  return digitalRead(LO_PLUS_PIN) == HIGH || digitalRead(LO_MINUS_PIN) == HIGH;
}

void sampleSensors() {
  const unsigned long nowUs = micros();
  if (nowUs - lastSampleUs < SAMPLE_INTERVAL_US) {
    return;
  }
  lastSampleUs += SAMPLE_INTERVAL_US;

  if (activeBatch.count == 0) {
    activeBatch.startedAtMs = millis();
  }

  particleSensor.check();
  long irRaw = particleSensor.getIR();
  if (particleSensor.available()) {
    irRaw = particleSensor.getIR();
    particleSensor.nextSample();
  }

  irBaseline = (irBaseline * 31 + irRaw) / 32;
  long ppgAc = irRaw - irBaseline;

  int ecgRaw = leadsOff() ? 0 : analogRead(ECG_PIN);
  float ecgVolts = (float)ecgRaw * 3.3f / 4095.0f;

  activeBatch.ecg[activeBatch.count] = ecgVolts;
  activeBatch.ppg[activeBatch.count] = ppgAc;
  activeBatch.count++;

  if (activeBatch.count >= BATCH_SIZE) {
    if (!pendingReady) {
      pendingBatch = activeBatch;
      pendingReady = true;
    } else {
      droppedBatches++;
      Serial.print("Upload backlog full. Dropped batches: ");
      Serial.println(droppedBatches);
    }
    activeBatch.count = 0;
  }
}

String buildPayload(const SampleBatch &batch) {
  String payload;
  payload.reserve(4096);
  payload += "{";
  payload += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  payload += "\"session_id\":\"" + sessionId + "\",";
  payload += "\"timestamp\":\"" + isoTimestamp() + "\",";
  payload += "\"sampling_rate\":" + String(SAMPLING_RATE_HZ) + ",";
  payload += "\"ecg\":[";
  for (int i = 0; i < batch.count; i++) {
    if (i > 0) payload += ",";
    payload += String(batch.ecg[i], 4);
  }
  payload += "],\"ppg\":[";
  for (int i = 0; i < batch.count; i++) {
    if (i > 0) payload += ",";
    payload += String(batch.ppg[i]);
  }
  payload += "],";
  payload += "\"battery\":" + String(readBatteryPercent()) + ",";
  payload += "\"status\":\"";
  payload += leadsOff() ? "leads_off" : "active";
  payload += "\",";
  payload += "\"metadata\":{\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";
  payload += "}";
  return payload;
}

bool uploadBatch(const SampleBatch &batch) {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }

  HTTPClient http;
  http.setTimeout(HTTP_TIMEOUT_MS);
  http.begin(BACKEND_READINGS_URL);
  http.addHeader("Content-Type", "application/json");
  if (String(DEVICE_API_KEY).length() > 0) {
    http.addHeader("X-Device-Token", DEVICE_API_KEY);
  }

  String payload = buildPayload(batch);
  int statusCode = http.POST(payload);
  String response = http.getString();
  http.end();

  Serial.print("POST ");
  Serial.print(BACKEND_READINGS_URL);
  Serial.print(" -> ");
  Serial.println(statusCode);
  if (statusCode >= 200 && statusCode < 300) {
    Serial.print("Uploaded samples: ");
    Serial.println(batch.count);
    if (response.length() > 0) {
      Serial.println("Backend response:");
      Serial.println(response);
    }
    return true;
  }

  Serial.print("Upload failed: ");
  Serial.println(response);
  return false;
}

void processUploads() {
  if (!pendingReady || millis() < nextUploadAttemptMs) {
    return;
  }
  if (uploadBatch(pendingBatch)) {
    pendingReady = false;
    pendingBatch.count = 0;
  } else {
    nextUploadAttemptMs = millis() + HTTP_RETRY_MS;
  }
}

void setupSensor() {
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30105 not found. Check wiring.");
    while (true) {
      delay(1000);
    }
  }
  particleSensor.setup(0x1F, 4, 2, 400, 411, 4096);
  particleSensor.setPulseAmplitudeRed(0x1F);
  particleSensor.setPulseAmplitudeIR(0x1F);
  particleSensor.setPulseAmplitudeGreen(0);
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("ECG/PPG uploader booting.");

  pinMode(LO_PLUS_PIN, INPUT);
  pinMode(LO_MINUS_PIN, INPUT);
  analogReadResolution(12);

  sessionId = String(SESSION_ID);
  if (sessionId.length() == 0) {
    sessionId = String(DEVICE_ID) + "_" + String(millis());
  }

  setupSensor();
  connectWiFi();
  syncClock();
  lastSampleUs = micros();
}

void loop() {
  connectWiFi();
  sampleSensors();
  processUploads();

  static unsigned long lastDebugMs = 0;
  if (millis() - lastDebugMs > 2000) {
    lastDebugMs = millis();
    Serial.print("WiFi=");
    Serial.print(WiFi.status() == WL_CONNECTED ? "connected" : "offline");
    Serial.print(" active_samples=");
    Serial.print(activeBatch.count);
    Serial.print(" pending=");
    Serial.print(pendingReady ? "yes" : "no");
    Serial.print(" dropped=");
    Serial.println(droppedBatches);
  }
}
