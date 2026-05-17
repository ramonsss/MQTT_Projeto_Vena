#include <Arduino.h>
#include <Wire.h>
#include <ArduinoJson.h>

#include "config.h"
#include "SensorManager.h"
#include "PeltierController.h"
#include "DisplayManager.h"
#include "OfflineBuffer.h"
#include "MqttPublisher.h"

namespace {
    SensorManager sensors(PIN_DHT_AMBIENT, PIN_DHT_DISSIPATOR);
    PeltierController peltier(PIN_PELTIER_PWM, PIN_FAN_INT_PWM, PIN_FAN_EXT_PWM,
                              PID_KP, PID_KI, PID_KD,
                              PID_SAMPLE_MS,
                              PID_OUTPUT_MIN, PID_OUTPUT_MAX,
                              PID_SLEW_PER_SEC);
    DisplayManager display(LCD_I2C_ADDR, 20, 4);
    OfflineBuffer buffer(OFFLINE_BUFFER_SIZE);
    MqttPublisher mqtt(WIFI_SSID, WIFI_PASS,
                       MQTT_HOST, MQTT_PORT,
                       MQTT_CLIENT_ID,
                       MQTT_TOPIC_TELEMETRY, MQTT_TOPIC_CMD);

    float lastAmbT = NAN, lastAmbH = NAN;
    float lastDissT = NAN, lastDissH = NAN;

    unsigned long lastPidMs = 0;
    unsigned long lastDisplayMs = 0;
    unsigned long lastTelemetryMs = 0;
}

static String buildTelemetryJson() {
    JsonDocument doc;
    doc["ambient_t"] = lastAmbT;
    doc["ambient_h"] = lastAmbH;
    doc["diss_t"] = lastDissT;
    doc["diss_h"] = lastDissH;
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

void setup() {
    Serial.begin(115200);
    delay(100);

    Wire.begin(PIN_LCD_SDA, PIN_LCD_SCL);
    sensors.begin();
    peltier.begin();
    display.begin();
    mqtt.begin();
    mqtt.onCommand(handleCommand);

    Serial.println("[BOOT] cocoa-box pronto");
}

void loop() {
    const unsigned long now = millis();
    mqtt.loop();

    if (now - lastPidMs >= PID_SAMPLE_MS) {
        lastPidMs = now;
        float t, h;
        if (sensors.readDissipator(t, h)) {
            lastDissT = t;
            lastDissH = h;
        } else {
            Serial.println("[DHT] dissipador leitura invalida (mantendo ultimo)");
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
                           peltier.currentSetpoint(), mqtt.isConnected());
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
