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
#define BACKEND_READINGS_URL "http://192.168.1.7:8000/api/readings"
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
#define HTTP_TIMEOUT_MS 10000

#ifndef FINGER_IR_THRESHOLD
#define FINGER_IR_THRESHOLD 50000
#endif

#ifndef FINGER_IR_RELAXED_THRESHOLD
#define FINGER_IR_RELAXED_THRESHOLD 12000
#endif

#ifndef FINGER_IR_AC_THRESHOLD
#define FINGER_IR_AC_THRESHOLD 25
#endif

#ifndef FINGER_IR_AMPLITUDE_THRESHOLD
#define FINGER_IR_AMPLITUDE_THRESHOLD 150
#endif

#ifndef FINGER_CONFIDENCE_MIN
#define FINGER_CONFIDENCE_MIN 0.35f
#endif

#ifndef FINGER_ALLOW_DC_ONLY
#define FINGER_ALLOW_DC_ONLY 0
#endif

#ifndef PPG_LED_BRIGHTNESS
#define PPG_LED_BRIGHTNESS 0x1F
#endif

#ifndef PPG_STALE_RESTART_MS
#define PPG_STALE_RESTART_MS 3000
#endif

#ifndef PPG_REINIT_RETRY_MS
#define PPG_REINIT_RETRY_MS 2000
#endif

#ifndef PPG_READY_MIN_FRESH_PERCENT
#define PPG_READY_MIN_FRESH_PERCENT 20
#endif

#ifndef I2C_SDA_PIN
#define I2C_SDA_PIN 21
#endif

#ifndef I2C_SCL_PIN
#define I2C_SCL_PIN 22
#endif

#define BACKEND_RESPONSE_PREVIEW_CHARS 512

MAX30105 particleSensor;

struct SampleBatch {
  float ecg[BATCH_SIZE];
  long ppg[BATCH_SIZE];
  int count = 0;
  unsigned long startedAtMs = 0;
  double redAcSquareSum = 0;
  double irAcSquareSum = 0;
  double redDcSum = 0;
  double irDcSum = 0;
  int spo2SampleCount = 0;
  int ppgOnlineSampleCount = 0;
  int fingerSampleCount = 0;
  int leadsOffSampleCount = 0;
  float fingerConfidence = 0;
  float irMean = 0;
  float irAcRms = 0;
  long irMin = 0;
  long irMax = 0;
  String fingerDetectionMode = "none";
  bool ppgSensorReady = false;
  bool ecgLeadsAttached = false;
  bool fingerDetected = false;
  float spo2Percent = 0;
  bool spo2Valid = false;
};

SampleBatch activeBatch;
SampleBatch pendingBatch;

bool pendingReady = false;
unsigned long nextWifiAttemptMs = 0;
unsigned long nextUploadAttemptMs = 0;
unsigned long lastSampleUs = 0;
unsigned long droppedBatches = 0;
unsigned long lastPpgSampleMs = 0;
unsigned long nextPpgReinitMs = 0;
unsigned long ppgReinitCount = 0;
bool ppgSensorReady = false;
long lastIrRaw = 0;
long lastRedRaw = 0;
long irBaseline = 0;
long redBaseline = 0;
bool ppgBaselinePrimed = false;
String sessionId;

void resetBatch(SampleBatch &batch) {
  batch.count = 0;
  batch.startedAtMs = 0;
  batch.redAcSquareSum = 0;
  batch.irAcSquareSum = 0;
  batch.redDcSum = 0;
  batch.irDcSum = 0;
  batch.spo2SampleCount = 0;
  batch.ppgOnlineSampleCount = 0;
  batch.fingerSampleCount = 0;
  batch.leadsOffSampleCount = 0;
  batch.fingerConfidence = 0;
  batch.irMean = 0;
  batch.irAcRms = 0;
  batch.irMin = 0;
  batch.irMax = 0;
  batch.fingerDetectionMode = "none";
  batch.ppgSensorReady = false;
  batch.ecgLeadsAttached = false;
  batch.fingerDetected = false;
  batch.spo2Percent = 0;
  batch.spo2Valid = false;
}

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

void finalizeVitals(SampleBatch &batch) {
  batch.spo2Valid = false;
  batch.irMean = batch.spo2SampleCount > 0 ? batch.irDcSum / batch.spo2SampleCount : 0;
  if (batch.spo2SampleCount > 1) {
    const double irMean = batch.irDcSum / batch.spo2SampleCount;
    const double irVariance = (batch.irAcSquareSum / batch.spo2SampleCount) - (irMean * irMean);
    batch.irAcRms = sqrt(max(0.0, irVariance));
  } else {
    batch.irAcRms = 0;
  }
  const int minFreshPpgSamples =
    max(1, (batch.spo2SampleCount * PPG_READY_MIN_FRESH_PERCENT) / 100);
  batch.ppgSensorReady =
    batch.spo2SampleCount > 0 && batch.ppgOnlineSampleCount >= minFreshPpgSamples;
  batch.ecgLeadsAttached =
    batch.count > 0 && batch.leadsOffSampleCount <= (batch.count / 2);
  batch.fingerConfidence =
    batch.ppgOnlineSampleCount > 0 ? (float)batch.fingerSampleCount / (float)batch.ppgOnlineSampleCount : 0;
  const long irAmplitude = batch.irMax - batch.irMin;
  const bool dcContact =
    batch.fingerConfidence >= FINGER_CONFIDENCE_MIN && batch.irMean >= FINGER_IR_THRESHOLD;
  const bool pulsatileFinger =
    batch.fingerConfidence >= FINGER_CONFIDENCE_MIN &&
    batch.irMean >= FINGER_IR_RELAXED_THRESHOLD &&
    batch.irAcRms >= FINGER_IR_AC_THRESHOLD &&
    irAmplitude >= FINGER_IR_AMPLITUDE_THRESHOLD;
  const bool strongDcFinger = FINGER_ALLOW_DC_ONLY && dcContact;
  batch.fingerDetected = batch.ppgSensorReady && (strongDcFinger || pulsatileFinger);
  if (strongDcFinger) {
    batch.fingerDetectionMode = "dc_threshold";
  } else if (pulsatileFinger) {
    batch.fingerDetectionMode = "pulsatile_ir";
  } else {
    batch.fingerDetectionMode = "none";
  }

  if (batch.spo2SampleCount < 20) {
    return;
  }
  if (!batch.fingerDetected) {
    return;
  }

  const double redDc = batch.redDcSum / batch.spo2SampleCount;
  const double irDc = batch.irDcSum / batch.spo2SampleCount;
  const double redVariance = (batch.redAcSquareSum / batch.spo2SampleCount) - (redDc * redDc);
  const double irVariance = (batch.irAcSquareSum / batch.spo2SampleCount) - (irDc * irDc);
  const double redAc = sqrt(max(0.0, redVariance));
  const double irAc = sqrt(max(0.0, irVariance));
  if (redDc < 1000 || irDc < 1000 || redAc <= 0 || irAc <= 0) {
    return;
  }

  const double ratio = (redAc / redDc) / (irAc / irDc);
  const double estimatedSpo2 = 110.0 - 25.0 * ratio;
  batch.spo2Percent = constrain(estimatedSpo2, 70.0, 100.0);
  batch.spo2Valid = true;
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

  long irRaw = 0;
  long redRaw = 0;
  bool freshPpgSample = false;
  if (ppgSensorReady) {
    particleSensor.check();
    if (particleSensor.available()) {
      irRaw = particleSensor.getIR();
      redRaw = particleSensor.getRed();
      particleSensor.nextSample();
      freshPpgSample = true;
      lastPpgSampleMs = millis();
    } else {
      irRaw = particleSensor.getIR();
      redRaw = particleSensor.getRed();
      if (millis() - lastPpgSampleMs > PPG_STALE_RESTART_MS) {
        Serial.println("MAX30105 stopped returning fresh samples. Reinitializing PPG sensor.");
        ppgSensorReady = false;
        nextPpgReinitMs = 0;
      }
    }
  } else if (millis() >= nextPpgReinitMs) {
    Serial.println("PPG sensor is offline. Trying to reinitialize MAX30105.");
    setupSensor();
  }

  if (freshPpgSample) {
    if (!ppgBaselinePrimed) {
      irBaseline = irRaw;
      redBaseline = redRaw;
      ppgBaselinePrimed = true;
    } else {
      irBaseline = (irBaseline * 31 + irRaw) / 32;
      redBaseline = (redBaseline * 31 + redRaw) / 32;
    }
  }
  lastIrRaw = irRaw;
  lastRedRaw = redRaw;
  long ppgAc = irRaw - irBaseline;
  long redAc = redRaw - redBaseline;

  const bool ecgLeadsOff = leadsOff();
  int ecgRaw = ecgLeadsOff ? 0 : analogRead(ECG_PIN);
  float ecgVolts = (float)ecgRaw * 3.3f / 4095.0f;

  activeBatch.ecg[activeBatch.count] = ecgVolts;
  activeBatch.ppg[activeBatch.count] = irRaw;
  if (activeBatch.ppgOnlineSampleCount == 0) {
    activeBatch.irMin = irRaw;
    activeBatch.irMax = irRaw;
  } else if (freshPpgSample) {
    if (irRaw < activeBatch.irMin) activeBatch.irMin = irRaw;
    if (irRaw > activeBatch.irMax) activeBatch.irMax = irRaw;
  }
  if (freshPpgSample) {
    activeBatch.redAcSquareSum += (double)redRaw * (double)redRaw;
    activeBatch.irAcSquareSum += (double)irRaw * (double)irRaw;
    activeBatch.redDcSum += redRaw;
    activeBatch.irDcSum += irRaw;
    activeBatch.spo2SampleCount++;
    activeBatch.ppgOnlineSampleCount++;
  }
  if (ecgLeadsOff) {
    activeBatch.leadsOffSampleCount++;
  }
  if (freshPpgSample && irRaw >= FINGER_IR_RELAXED_THRESHOLD) {
    activeBatch.fingerSampleCount++;
  }
  activeBatch.count++;

  if (activeBatch.count >= BATCH_SIZE) {
    finalizeVitals(activeBatch);
    if (!pendingReady) {
      pendingBatch = activeBatch;
      pendingReady = true;
    } else {
      droppedBatches++;
      Serial.print("Upload backlog full. Dropped batches: ");
      Serial.println(droppedBatches);
    }
    resetBatch(activeBatch);
  }
}

String buildPayload(const SampleBatch &batch) {
  String payload;
  payload.reserve(8192);
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
  if (!batch.ppgSensorReady) {
    payload += "ppg_sensor_off";
  } else if (!batch.fingerDetected) {
    payload += "no_finger";
  } else {
    payload += batch.ecgLeadsAttached ? "active" : "leads_off";
  }
  payload += "\",";
  payload += "\"metadata\":{\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\",";
  payload += "\"ppg_sensor_ready\":";
  payload += batch.ppgSensorReady ? "true" : "false";
  payload += ",\"ppg_reinit_count\":" + String(ppgReinitCount);
  payload += ",";
  payload += "\"finger_detected\":";
  payload += batch.fingerDetected ? "true" : "false";
  payload += ",\"finger_confidence\":" + String(batch.fingerConfidence, 2);
  payload += ",\"ir_mean\":" + String(batch.irMean, 1);
  payload += ",\"ir_ac_rms\":" + String(batch.irAcRms, 1);
  payload += ",\"ir_amplitude\":" + String(batch.irMax - batch.irMin);
  payload += ",\"ppg_fresh_samples\":" + String(batch.ppgOnlineSampleCount);
  payload += ",\"ppg_ready_min_fresh_percent\":" + String(PPG_READY_MIN_FRESH_PERCENT);
  payload += ",\"leads_off_samples\":" + String(batch.leadsOffSampleCount);
  payload += ",\"ecg_leads_attached\":";
  payload += batch.ecgLeadsAttached ? "true" : "false";
  payload += ",\"finger_detection_mode\":\"" + batch.fingerDetectionMode + "\"";
  payload += ",\"finger_ir_threshold\":" + String(FINGER_IR_THRESHOLD);
  payload += ",\"finger_ir_relaxed_threshold\":" + String(FINGER_IR_RELAXED_THRESHOLD);
  payload += ",\"finger_ir_ac_threshold\":" + String(FINGER_IR_AC_THRESHOLD);
  payload += ",\"finger_ir_amplitude_threshold\":" + String(FINGER_IR_AMPLITUDE_THRESHOLD);
  payload += ",\"finger_allow_dc_only\":";
  payload += FINGER_ALLOW_DC_ONLY ? "true" : "false";
  payload += ",";
  payload += "\"spo2_valid\":";
  payload += batch.spo2Valid ? "true" : "false";
  if (batch.spo2Valid) {
    payload += ",\"spo2_percent\":" + String(batch.spo2Percent, 1);
  }
  payload += "}";
  payload += "}";
  return payload;
}

bool responseHasCommand(const String &response, const char *commandType) {
  String needle = "\"command_type\":\"";
  needle += commandType;
  needle += "\"";
  return response.indexOf(needle) >= 0;
}

void handleBackendCommands(const String &response) {
  if (response.length() == 0 || response.indexOf("\"commands\"") < 0) {
    return;
  }

  if (responseHasCommand(response, "check_sensor_contact")) {
    Serial.println("Backend command: check ECG electrodes and PPG sensor contact.");
  }
  if (responseHasCommand(response, "low_battery_warning")) {
    Serial.println("Backend command: battery is low; recharge soon.");
  }
  if (responseHasCommand(response, "retry_capture")) {
    Serial.println("Backend command: signal quality is low; reposition sensors and keep sampling.");
  }
  if (responseHasCommand(response, "clinical_review")) {
    Serial.println("Backend command: clinical review requested for this session.");
  }
  if (responseHasCommand(response, "continue")) {
    Serial.println("Backend command: continue sampling.");
  }
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
      Serial.print("Backend response bytes: ");
      Serial.println(response.length());
      Serial.println("Backend response preview:");
      Serial.println(response.substring(0, BACKEND_RESPONSE_PREVIEW_CHARS));
      handleBackendCommands(response);
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
    resetBatch(pendingBatch);
  } else {
    nextUploadAttemptMs = millis() + HTTP_RETRY_MS;
  }
}

bool setupSensor() {
  nextPpgReinitMs = millis() + PPG_REINIT_RETRY_MS;
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30105 not found. Check wiring.");
    ppgSensorReady = false;
    return false;
  }
  particleSensor.setup(PPG_LED_BRIGHTNESS, 4, 2, 400, 411, 4096);
  particleSensor.setPulseAmplitudeRed(PPG_LED_BRIGHTNESS);
  particleSensor.setPulseAmplitudeIR(PPG_LED_BRIGHTNESS);
  particleSensor.setPulseAmplitudeGreen(0);
  particleSensor.clearFIFO();
  ppgSensorReady = true;
  ppgBaselinePrimed = false;
  lastPpgSampleMs = millis();
  ppgReinitCount++;
  Serial.print("MAX30105 ready. Red/IR LEDs enabled. Reinit count=");
  Serial.println(ppgReinitCount);
  return true;
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

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
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
    Serial.print(droppedBatches);
    Serial.print(" ppg=");
    Serial.print(ppgSensorReady ? "ready" : "offline");
    Serial.print(" ir=");
    Serial.print(lastIrRaw);
    Serial.print(" red=");
    Serial.print(lastRedRaw);
    Serial.print(" ppg_reinit=");
    Serial.println(ppgReinitCount);
  }
}
