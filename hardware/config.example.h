#pragma once

// Copy this file to hardware/ECG_PPG_HR_SPO2/config.h and fill in local values.
// Do not commit hardware/ECG_PPG_HR_SPO2/config.h.

#define WIFI_SSID "your-wifi-name"
#define WIFI_PASSWORD "your-wifi-password"

#define BACKEND_READINGS_URL "http://192.168.1.10:8000/api/readings"
#define DEVICE_ID "device_001"
#define SESSION_ID "session_001"
#define FIRMWARE_VERSION "ecg-ppg-1.0"
#define DEVICE_API_KEY ""

#define I2C_SDA_PIN 21
#define I2C_SCL_PIN 22

// Raise this if "finger detected" appears while the sensor is uncovered.
// Lower it if your MAX30105 reports weak IR values even with a finger placed.
#define FINGER_IR_THRESHOLD 50000
#define FINGER_IR_RELAXED_THRESHOLD 12000
#define FINGER_IR_AC_THRESHOLD 80
#define FINGER_IR_AMPLITUDE_THRESHOLD 150
#define FINGER_CONFIDENCE_MIN 0.35f
// Leave disabled for real captures. DC-only checks can false-trigger on ambient light.
#define FINGER_ALLOW_DC_ONLY 0
// ECG is sampled faster than the MAX30105 FIFO. Keep this below the sensor's
// effective fresh-sample percentage so valid PPG batches are not rejected.
#define PPG_READY_MIN_FRESH_PERCENT 20

// MAX30105 red/IR LED brightness. Raise slightly if the light is too weak;
// lower it if the sensor gets hot or the ESP32 power becomes unstable.
#define PPG_LED_BRIGHTNESS 0x1F
#define PPG_STALE_RESTART_MS 3000
#define PPG_REINIT_RETRY_MS 2000

#define ECG_PIN 34
#define LO_PLUS_PIN 32
#define LO_MINUS_PIN 33

// Set to an ADC pin if you have a battery divider wired, otherwise leave -1.
#define BATTERY_PIN -1
#define BATTERY_PERCENT_FALLBACK 100
