#pragma once

#include <NimBLEDevice.h>
#include <functional>
#include <Arduino.h>

struct WifiCredentials {
    String ssid;
    String psk;
    String jwt;
};

using ProvisionCallback = std::function<void(const WifiCredentials&)>;

class BleManager {
public:
    void init(const char* deviceName, const char* deviceId,
              const char* pairingCode, const char* fwVersion);
    void startAdvertising();
    void stopAdvertising();
    bool isConnected() const;
    int clientCount() const;
    void notifyTelemetry(const char* jsonPayload);
    void updateWifiStatus(bool connected, const char* ssid = nullptr,
                          const char* ip = nullptr, int rssi = 0);
    void setProvisionCallback(ProvisionCallback cb);

private:
    NimBLEServer* _server = nullptr;
    NimBLECharacteristic* _deviceInfoChar = nullptr;
    NimBLECharacteristic* _telemetryChar = nullptr;
    NimBLECharacteristic* _wifiStatusChar = nullptr;
    NimBLECharacteristic* _provisionChar = nullptr;
    NimBLECharacteristic* _pairingCodeChar = nullptr;
    ProvisionCallback _provisionCb = nullptr;
    int _clientCount = 0;

    friend class VenaServerCallbacks;
    friend class ProvisionWriteCallbacks;
};
