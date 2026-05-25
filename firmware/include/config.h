#pragma once

#ifndef PIN_DHT_DISSIPATOR
#define PIN_DHT_DISSIPATOR 4
#endif
#ifndef PIN_DHT_AMBIENT
#define PIN_DHT_AMBIENT 15
#endif

#ifndef PIN_PELTIER_PWM
#define PIN_PELTIER_PWM 25
#endif
#ifndef PIN_FAN_INT_PWM
#define PIN_FAN_INT_PWM 26
#endif
#ifndef PIN_FAN_EXT_PWM
#define PIN_FAN_EXT_PWM 27
#endif

#ifndef PIN_LCD_SDA
#define PIN_LCD_SDA 21
#endif
#ifndef PIN_LCD_SCL
#define PIN_LCD_SCL 22
#endif
#ifndef LCD_I2C_ADDR
#define LCD_I2C_ADDR 0x27
#endif

// Canais LEDC distintos por carga PWM.
#ifndef LEDC_CH_PELTIER
#define LEDC_CH_PELTIER 0
#endif
#ifndef LEDC_CH_FAN_INT
#define LEDC_CH_FAN_INT 1
#endif
#ifndef LEDC_CH_FAN_EXT
#define LEDC_CH_FAN_EXT 2
#endif
#ifndef LEDC_FREQ_HZ
#define LEDC_FREQ_HZ 20000  // 20 kHz: acima da audição e suportado pelos MOSFETs
#endif
#ifndef LEDC_RESOLUTION_BITS
#define LEDC_RESOLUTION_BITS 8
#endif

#ifndef PID_KP
#define PID_KP 2.0
#endif
#ifndef PID_KI
#define PID_KI 0.5
#endif
#ifndef PID_KD
#define PID_KD 1.0
#endif
#ifndef PID_SAMPLE_MS
#define PID_SAMPLE_MS 2000  // DHT22 limita ~0.5 Hz; abaixo disso a leitura repete
#endif
#ifndef PID_OUTPUT_MIN
#define PID_OUTPUT_MIN -255.0
#endif
#ifndef PID_OUTPUT_MAX
#define PID_OUTPUT_MAX 255.0
#endif
#ifndef PID_SLEW_PER_SEC
#define PID_SLEW_PER_SEC 20.0  // protege a Peltier de degrau térmico
#endif

#ifndef SETPOINT_C
#define SETPOINT_C 18.0
#endif

#ifndef WIFI_SSID
#define WIFI_SSID "changeme-ssid"
#endif
#ifndef WIFI_PASS
#define WIFI_PASS "changeme-pass"
#endif
#ifndef MQTT_HOST
#define MQTT_HOST "192.168.0.10"
#endif
#ifndef MQTT_PORT
#define MQTT_PORT 1883
#endif
#ifndef MQTT_BUFFER_SIZE
#define MQTT_BUFFER_SIZE 512
#endif

#ifndef NTP_SERVER
#define NTP_SERVER "pool.ntp.org"
#endif
#ifndef NTP_TIMEOUT_MS
#define NTP_TIMEOUT_MS 10000
#endif
#ifndef FW_VERSION
#define FW_VERSION "1.1.0"
#endif

#ifndef OFFLINE_BUFFER_SIZE
#define OFFLINE_BUFFER_SIZE 128
#endif

#ifndef TELEMETRY_PERIOD_MS
#define TELEMETRY_PERIOD_MS 5000
#endif
#ifndef DISPLAY_REFRESH_MS
#define DISPLAY_REFRESH_MS 1000
#endif

// MQTT authentication via device JWT stored in NVS.
// Set to 1 in platformio.local.ini once the device has been provisioned:
//   build_flags = ${common.build_flags} -DMQTT_USE_AUTH=1
#ifndef MQTT_USE_AUTH
#define MQTT_USE_AUTH 0
#endif
// NVS key used to persist the device JWT across reboots.
#ifndef MQTT_NVS_JWT_KEY
#define MQTT_NVS_JWT_KEY "device_jwt"
#endif

// ─── BLE Configuration ─────────────────────────────────────────────────────
#ifndef BLE_DEVICE_PREFIX
#define BLE_DEVICE_PREFIX "Vena-"
#endif
#ifndef BLE_NOTIFY_INTERVAL_MS
#define BLE_NOTIFY_INTERVAL_MS 2000
#endif
#ifndef BLE_MTU
#define BLE_MTU 247
#endif

// ─── Wi-Fi Provisioning (NVS keys) ─────────────────────────────────────────
#ifndef NVS_NAMESPACE
#define NVS_NAMESPACE "vena_cfg"
#endif
#ifndef NVS_KEY_SSID
#define NVS_KEY_SSID "wifi_ssid"
#endif
#ifndef NVS_KEY_PSK
#define NVS_KEY_PSK "wifi_psk"
#endif
#ifndef NVS_KEY_JWT
#define NVS_KEY_JWT "device_jwt"
#endif
