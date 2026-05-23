#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClient.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <functional>

class MqttPublisher {
public:
    using CommandHandler = std::function<void(const JsonDocument&)>;

    MqttPublisher(const char* wifiSsid, const char* wifiPass,
                  const char* mqttHost, uint16_t mqttPort);

    void begin(const char* deviceId);
    void loop();
    bool publishTelemetry(const String& json);
    void onCommand(CommandHandler cb);
    bool isConnected() const;

    // Set the device JWT used as MQTT username when MQTT_USE_AUTH == 1.
    // Call before begin() or any time before the next reconnect attempt.
    void setJwt(const String& jwt);

private:
    void ensureWifi();
    void ensureMqtt();
    void handleMessage(char* topic, uint8_t* payload, unsigned int length);

    const char* _wifiSsid;
    const char* _wifiPass;
    const char* _mqttHost;
    uint16_t _mqttPort;

    String _deviceId;
    String _topicTelemetry;
    String _topicStatus;
    String _topicCmd;

    String _jwtCredential;

    WiFiClient _wifiClient;
    PubSubClient _mqtt;
    CommandHandler _cmdHandler;

    unsigned long _wifiNextAttemptMs = 0;
    unsigned long _wifiBackoffMs = 1000;

    unsigned long _mqttNextAttemptMs = 0;
    unsigned long _mqttBackoffMs = 1000;

    static constexpr unsigned long BACKOFF_MAX_MS = 30000;
};
