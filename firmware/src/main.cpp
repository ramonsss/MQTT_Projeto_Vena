#include <Arduino.h>
#include <Wire.h>
#include <ArduinoJson.h>
#include <time.h>
#include <esp_mac.h>
#include <esp_system.h>
#include <Preferences.h>
#include <WiFi.h>

#include "config.h"
#include "SensorManager.h"
#include "PeltierController.h"
#include "DisplayManager.h"
#include "OfflineBuffer.h"
#include "MqttPublisher.h"
#include "NvsJwt.h"
#include "BleManager.h"
#include "WifiProvisioner.h"

namespace {
    SensorManager sensors(PIN_DHT_AMBIENT, PIN_ONEWIRE);
    PeltierController peltier(PIN_PELTIER_PWM,
                              PID_KP, PID_KI, PID_KD,
                              PID_SAMPLE_MS,
                              PID_OUTPUT_MIN, PID_OUTPUT_MAX);
    DisplayManager display(LCD_I2C_ADDR, 20, 4);
    OfflineBuffer buffer(OFFLINE_BUFFER_SIZE);
    MqttPublisher mqtt(WIFI_SSID, WIFI_PASS, MQTT_HOST, MQTT_PORT);
    BleManager ble;
    WifiProvisioner provisioner;

    char deviceId[20];  // "vena-xxxxxxxxxxxx\0"
    char bleName[12];   // "Vena-XXXX\0"
    char pairingCode[10]; // "XXXX-XXXX\0"
    bool ntpReady = false;
    bool wifiProvisioned = false;
    uint32_t seqCounter = 0;

    float lastAmbT = NAN, lastAmbH = NAN;
    float lastDissT = NAN;

    unsigned long lastPidMs = 0;
    unsigned long lastDisplayMs = 0;
    unsigned long lastTelemetryMs = 0;
    unsigned long lastBleNotifyMs = 0;

    // Pending provisioning — set by BLE callback, consumed by loop()
    bool pendingProvision = false;
    WifiCredentials pendingCreds;
    bool wifiWasConnected = false;  // track WiFi state changes for BLE notify

    // Phase 5 — meta payload tracking
    uint32_t bootCount = 0;
    uint32_t freeHeapBoot = 0;
    uint32_t freeHeapMinRuntime = UINT32_MAX;
    esp_reset_reason_t lastResetReason = ESP_RST_UNKNOWN;
    bool metaPublished = false;
}

namespace {
    const char* resetReasonToStr(esp_reset_reason_t r) {
        switch (r) {
            case ESP_RST_POWERON:   return "ESP_RST_POWERON";
            case ESP_RST_EXT:       return "ESP_RST_EXT";
            case ESP_RST_SW:        return "ESP_RST_SW";
            case ESP_RST_PANIC:     return "ESP_RST_PANIC";
            case ESP_RST_INT_WDT:   return "ESP_RST_INT_WDT";
            case ESP_RST_TASK_WDT:  return "ESP_RST_TASK_WDT";
            case ESP_RST_WDT:       return "ESP_RST_WDT";
            case ESP_RST_DEEPSLEEP: return "ESP_RST_DEEPSLEEP";
            case ESP_RST_BROWNOUT:  return "ESP_RST_BROWNOUT";
            case ESP_RST_SDIO:      return "ESP_RST_SDIO";
            default:                return "ESP_RST_UNKNOWN";
        }
    }

    uint32_t bumpBootCount() {
        Preferences p;
        if (!p.begin("vena_meta", /*readOnly=*/false)) return 0;
        uint32_t v = p.getUInt("boot_count", 0) + 1;
        p.putUInt("boot_count", v);
        p.end();
        return v;
    }

    String buildMetaJson() {
        JsonDocument doc;
        doc["fw_version"] = FW_VERSION;
        doc["ble_max_conn"] = CONFIG_BT_NIMBLE_MAX_CONNECTIONS;
        doc["free_heap_boot"] = freeHeapBoot;
        doc["free_heap_min_runtime"] =
            (freeHeapMinRuntime == UINT32_MAX) ? freeHeapBoot : freeHeapMinRuntime;
        doc["wifi_rssi"] = WiFi.isConnected() ? WiFi.RSSI() : 0;
        doc["ntp_synced"] = ntpReady;
        doc["boot_count"] = bootCount;
        doc["last_reset_reason"] = resetReasonToStr(lastResetReason);
        String out;
        serializeJson(doc, out);
        return out;
    }
}  // namespace (Phase 5 meta helpers)

static void buildDeviceId() {
    uint8_t mac[6];
    esp_efuse_mac_get_default(mac);
    snprintf(deviceId, sizeof(deviceId), "vena-%02x%02x%02x%02x%02x%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    // BLE advertised name: "Vena-" + last 4 hex of MAC
    snprintf(bleName, sizeof(bleName), "%s%02X%02X", BLE_DEVICE_PREFIX, mac[4], mac[5]);
    // Pairing code: deterministic from MAC (first 8 hex chars, formatted XXXX-XXXX)
    snprintf(pairingCode, sizeof(pairingCode), "%02X%02X-%02X%02X",
             mac[0] ^ 0x5A, mac[1] ^ 0xA5, mac[2] ^ 0x3C, mac[3] ^ 0xC3);
}

static bool waitForNtp() {
    configTime(0, 0, NTP_SERVER);
    unsigned long start = millis();
    while (time(nullptr) < 1000000000UL) {  // before ~2001 = not synced
        if (millis() - start > NTP_TIMEOUT_MS) return false;
        delay(100);
    }
    return true;
}

static String buildTelemetryJson() {
    JsonDocument doc;
    doc["ts"] = (int64_t)time(nullptr) * 1000LL;
    doc["seq"] = seqCounter++;
    doc["ambient_t"] = lastAmbT;
    doc["ambient_h"] = lastAmbH;
    doc["diss_t"] = lastDissT;
    doc["setpoint"] = peltier.currentSetpoint();
    doc["pid_out"] = peltier.lastOutput();
    doc["uptime_ms"] = (uint32_t)millis();
    String out;
    serializeJson(doc, out);
    return out;
}

static void handleCommand(const JsonDocument& doc) {
    if (doc.containsKey("setpoint")) {
        float sp = doc["setpoint"].as<float>();
        peltier.setSetpoint(sp);
        Serial.print("[CMD] novo setpoint=");
        Serial.println(sp);
    }
}

static String buildBleTelemetryJson() {
    JsonDocument doc;
    doc["ts"] = (int64_t)time(nullptr) * 1000LL;
    doc["at"] = lastAmbT;
    doc["ah"] = lastAmbH;
    doc["dt"] = lastDissT;
    doc["sp"] = peltier.currentSetpoint();
    doc["po"] = peltier.lastOutput();
    String out;
    serializeJson(doc, out);
    return out;
}

// Called from the NimBLE host task — must return immediately.
// All WiFi operations are deferred to loop() via pendingProvision flag.
static void onProvisionReceived(const WifiCredentials& creds) {
    Serial.println("[PROV] credentials received via BLE, deferring to main loop");
    provisioner.saveCredentials(creds.ssid, creds.psk, creds.jwt);
    if (creds.jwt.length() > 0) nvs_store_jwt(creds.jwt);
    pendingCreds = creds;
    pendingProvision = true;
    // Return immediately so NimBLE can send the BLE Write Response.
}

void setup() {
    Serial.begin(115200);
    delay(100);

    // Phase 5 — capture boot diagnostics BEFORE allocating BLE/Wi-Fi.
    lastResetReason = esp_reset_reason();
    freeHeapBoot = ESP.getFreeHeap();
    bootCount = bumpBootCount();
    Serial.printf("[META] boot_count=%u, reset=%s, heap_boot=%u\n",
                  bootCount, resetReasonToStr(lastResetReason), freeHeapBoot);

    buildDeviceId();
    Serial.print("[BOOT] device_id=");
    Serial.println(deviceId);
    Serial.print("[BOOT] ble_name=");
    Serial.println(bleName);

    Wire.begin(PIN_LCD_SDA, PIN_LCD_SCL);
    sensors.begin();
    peltier.begin();
    display.begin();

    // Initialize Wi-Fi provisioner (check NVS for stored credentials)
    provisioner.begin();

    // Initialize BLE — always active for local monitoring + provisioning
    ble.setProvisionCallback(onProvisionReceived);
    ble.init(bleName, deviceId, pairingCode, FW_VERSION);

    // Determine Wi-Fi mode: use provisioned creds or compile-time defaults
    if (provisioner.hasCredentials()) {
        StoredCredentials creds = provisioner.loadCredentials();
        Serial.printf("[BOOT] using provisioned WiFi: %s\n", creds.ssid.c_str());
        WiFi.begin(creds.ssid.c_str(), creds.psk.c_str());
        mqtt.setJwt(creds.jwt);
        mqtt.begin(deviceId);
        mqtt.onCommand(handleCommand);
        wifiProvisioned = true;
    } else {
        // Fallback to compile-time credentials (dev/testing)
        Serial.println("[BOOT] no provisioned WiFi — using compile-time defaults");
        mqtt.begin(deviceId);
        mqtt.onCommand(handleCommand);

#if MQTT_USE_AUTH
        {
            String jwt = nvs_load_jwt();
            if (jwt.length() > 0) {
                mqtt.setJwt(jwt);
                Serial.println("[AUTH] device JWT carregado do NVS");
            } else {
                Serial.println("[AUTH] MQTT_USE_AUTH=1 mas nenhum JWT no NVS");
            }
        }
#endif
    }

    // Wait for Wi-Fi + NTP
    Serial.println("[NTP] aguardando sincronizacao...");
    unsigned long wifiWait = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - wifiWait < 15000) {
        delay(200);
    }

    if (WiFi.status() == WL_CONNECTED) {
        ntpReady = waitForNtp();
        if (ntpReady) {
            Serial.println("[NTP] sincronizado");
        } else {
            Serial.println("[NTP] timeout - usando uptime como fallback");
        }
        // Update BLE wifi_status characteristic
        ble.updateWifiStatus(true, WiFi.SSID().c_str(),
                             WiFi.localIP().toString().c_str(), WiFi.RSSI());
    } else {
        Serial.println("[WIFI] nao conectou - modo BLE-only ativo");
        ble.updateWifiStatus(false);
    }

    // Initialise wifiWasConnected so loop() doesn't re-fire on first tick.
    wifiWasConnected = (WiFi.status() == WL_CONNECTED);

    Serial.printf("[BOOT] Vena pronta (heap=%u bytes)\n", ESP.getFreeHeap());
}

void loop() {
    const unsigned long now = millis();

    // ── Handle pending WiFi provisioning (deferred from BLE callback) ───────
    if (pendingProvision) {
        pendingProvision = false;
        Serial.printf("[PROV] starting WiFi connect: ssid='%s' psk_len=%u jwt=%s\n",
                      pendingCreds.ssid.c_str(),
                      pendingCreds.psk.length(),
                      pendingCreds.jwt.isEmpty() ? "none" : "present");
        WiFi.disconnect(true);
        delay(50);
        WiFi.begin(pendingCreds.ssid.c_str(), pendingCreds.psk.c_str());
        if (pendingCreds.jwt.length() > 0) {
            mqtt.setJwt(pendingCreds.jwt);
        }
        wifiProvisioned = true;
        Serial.printf("[PROV] WiFi.begin() called, status=%d\n", WiFi.status());
    }

    // ── Track WiFi connection state and update BLE wifi_status ──────────────
    bool currentWifiConnected = (WiFi.status() == WL_CONNECTED);
    if (currentWifiConnected && !wifiWasConnected) {
        wifiWasConnected = true;
        Serial.printf("[WIFI] connected: ssid='%s' ip=%s rssi=%d\n",
                      WiFi.SSID().c_str(),
                      WiFi.localIP().toString().c_str(),
                      WiFi.RSSI());
        ble.updateWifiStatus(true, WiFi.SSID().c_str(),
                             WiFi.localIP().toString().c_str(), WiFi.RSSI());
        // Start MQTT now that we have WiFi (covers both cold boot and post-provision)
        if (wifiProvisioned) {
            mqtt.begin(deviceId);
            mqtt.onCommand(handleCommand);
            Serial.println("[PROV] mqtt.begin() called after WiFi connect");
        }
        if (!ntpReady) {
            ntpReady = waitForNtp();
            if (ntpReady) Serial.println("[NTP] sincronizado");
            else Serial.println("[NTP] timeout apos provisioning");
        }
    } else if (!currentWifiConnected && wifiWasConnected) {
        wifiWasConnected = false;
        Serial.printf("[WIFI] disconnected, status=%d\n", WiFi.status());
        ble.updateWifiStatus(false);
    }

    mqtt.loop();

    // Phase 5 — track min free heap continuously to detect leaks.
    uint32_t curHeap = ESP.getFreeHeap();
    if (curHeap < freeHeapMinRuntime) freeHeapMinRuntime = curHeap;

    // Publish meta once per boot, after MQTT is up. Retain=true so the broker
    // keeps it for late subscribers and backend restarts.
    if (!metaPublished && mqtt.isConnected()) {
        String metaPayload = buildMetaJson();
        if (mqtt.publishMeta(metaPayload)) {
            metaPublished = true;
            Serial.printf("[META] published (%u bytes)\n", metaPayload.length());
        }
    }

    if (now - lastPidMs >= PID_SAMPLE_MS) {
        lastPidMs = now;
        float ds18Temp;
        if (sensors.readDS18B20(ds18Temp)) {
            lastDissT = ds18Temp;
        } else {
            Serial.println("[DS18B20] leitura invalida (mantendo ultimo)");
        }
        if (!isnan(lastDissT)) {
            peltier.update(lastDissT);
        }
    }

    if (now - lastDisplayMs >= DISPLAY_REFRESH_MS) {
        lastDisplayMs = now;
        float t, h;
        if (sensors.readAmbient(t, h)) {
            lastAmbT = t;
            lastAmbH = h;
        } else {
            Serial.println("[DHT] ambiente leitura invalida (mantendo ultimo)");
        }
        display.showStatus(lastAmbT, lastAmbH, lastDissT,
                           peltier.lastOutput(), mqtt.isConnected());
    }

    // BLE telemetry notify (every 2s, independent of MQTT 5s)
    if (now - lastBleNotifyMs >= BLE_NOTIFY_INTERVAL_MS) {
        lastBleNotifyMs = now;
        if (ble.isConnected()) {
            String blePayload = buildBleTelemetryJson();
            ble.notifyTelemetry(blePayload.c_str());
        }
    }

    if (now - lastTelemetryMs >= TELEMETRY_PERIOD_MS) {
        lastTelemetryMs = now;
        const String payload = buildTelemetryJson();
        if (mqtt.isConnected() && buffer.empty()) {
            if (!mqtt.publishTelemetry(payload)) buffer.push(payload);
        } else {
            buffer.push(payload);
        }
    }

    if (mqtt.isConnected() && !buffer.empty()) {
        // Rate limit pra não atropelar broker quando volta de uma queda longa.
        for (int i = 0; i < 4 && !buffer.empty(); ++i) {
            String pending;
            if (!buffer.peek(pending)) break;
            if (!mqtt.publishTelemetry(pending)) break;
            buffer.pop();
        }
    }
}
