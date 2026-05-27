#pragma once

// Copy this file to hardware/config.h and fill in local values.
// Do not commit hardware/config.h.

#define WIFI_SSID "your-wifi-name"
#define WIFI_PASSWORD "your-wifi-password"

#define BACKEND_READINGS_URL "http://192.168.1.10:8000/api/readings"
#define DEVICE_ID "device_001"
#define SESSION_ID "session_001"
#define FIRMWARE_VERSION "ecg-ppg-1.0"
#define DEVICE_API_KEY ""

#define ECG_PIN 34
#define LO_PLUS_PIN 32
#define LO_MINUS_PIN 33

// Set to an ADC pin if you have a battery divider wired, otherwise leave -1.
#define BATTERY_PIN -1
#define BATTERY_PERCENT_FALLBACK 100
