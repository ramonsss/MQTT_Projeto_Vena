#include "MqttPublisher.h"
#include "config.h"

MqttPublisher::MqttPublisher(const char* wifiSsid, const char* wifiPass,
                             const char* mqttHost, uint16_t mqttPort,
                             const char* clientId,
                             const char* topicTelemetry, const char* topicCmd)
    : _wifiSsid(wifiSsid), _wifiPass(wifiPass),
      _mqttHost(mqttHost), _mqttPort(mqttPort),
      _clientId(clientId),
      _topicTelemetry(topicTelemetry), _topicCmd(topicCmd),
      _mqtt(_wifiClient) {}

void MqttPublisher::begin() {
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(_wifiSsid, _wifiPass);
    _wifiNextAttemptMs = millis() + _wifiBackoffMs;

    _mqtt.setServer(_mqttHost, _mqttPort);
    // 128 B default não cabe payload de telemetria com folga.
    _mqtt.setBufferSize(MQTT_BUFFER_SIZE);
    _mqtt.setCallback([this](char* t, uint8_t* p, unsigned int l) {
        this->handleMessage(t, p, l);
    });
}

void MqttPublisher::loop() {
    ensureWifi();
    if (WiFi.status() == WL_CONNECTED) {
        ensureMqtt();
        _mqtt.loop();
    }
}

bool MqttPublisher::publishTelemetry(const String& json) {
    if (!isConnected()) return false;
    return _mqtt.publish(_topicTelemetry, json.c_str());
}

void MqttPublisher::onCommand(CommandHandler cb) {
    _cmdHandler = cb;
}

bool MqttPublisher::isConnected() const {
    return WiFi.status() == WL_CONNECTED && const_cast<PubSubClient&>(_mqtt).connected();
}

void MqttPublisher::ensureWifi() {
    if (WiFi.status() == WL_CONNECTED) {
        _wifiBackoffMs = 1000;
        return;
    }
    const unsigned long now = millis();
    if ((long)(now - _wifiNextAttemptMs) < 0) return;

    WiFi.disconnect();
    WiFi.begin(_wifiSsid, _wifiPass);
    _wifiBackoffMs = min(_wifiBackoffMs * 2, BACKOFF_MAX_MS);
    _wifiNextAttemptMs = now + _wifiBackoffMs;
}

void MqttPublisher::ensureMqtt() {
    if (_mqtt.connected()) {
        _mqttBackoffMs = 1000;
        return;
    }
    const unsigned long now = millis();
    if ((long)(now - _mqttNextAttemptMs) < 0) return;

    if (_mqtt.connect(_clientId)) {
        _mqtt.subscribe(_topicCmd);
        _mqttBackoffMs = 1000;
    } else {
        _mqttBackoffMs = min(_mqttBackoffMs * 2, BACKOFF_MAX_MS);
        _mqttNextAttemptMs = now + _mqttBackoffMs;
    }
}

void MqttPublisher::handleMessage(char* topic, uint8_t* payload, unsigned int length) {
    if (!_cmdHandler) return;
    if (strcmp(topic, _topicCmd) != 0) return;

    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, payload, length);
    if (err) {
        Serial.print("[MQTT] payload invalido: ");
        Serial.println(err.c_str());
        return;
    }
    _cmdHandler(doc);
}
