#include "BleManager.h"
#include "BleCallbacks.h"
#include "ble_uuids.h"
#include "config.h"
#include <ArduinoJson.h>

void BleManager::init(const char* deviceName, const char* deviceId,
                      const char* pairingCode, const char* fwVersion) {
    NimBLEDevice::init(deviceName);
    NimBLEDevice::setMTU(BLE_MTU);
    NimBLEDevice::setSecurityAuth(true, false, true);  // bonding, no MITM, SC

    _server = NimBLEDevice::createServer();
    _server->setCallbacks(new VenaServerCallbacks(*this));

    // Create Vena Service
    NimBLEService* service = _server->createService(VENA_SERVICE_UUID);

    // device_info (Read)
    _deviceInfoChar = service->createCharacteristic(
        CHAR_DEVICE_INFO_UUID,
        NIMBLE_PROPERTY::READ
    );
    {
        JsonDocument doc;
        doc["device_id"] = deviceId;
        doc["fw_version"] = fwVersion;
        JsonArray caps = doc["capabilities"].to<JsonArray>();
        caps.add("telemetry");
        caps.add("peltier");
        String info;
        serializeJson(doc, info);
        _deviceInfoChar->setValue(info.c_str());
    }

    // live_telemetry (Notify)
    _telemetryChar = service->createCharacteristic(
        CHAR_LIVE_TELEMETRY_UUID,
        NIMBLE_PROPERTY::NOTIFY
    );

    // wifi_status (Read + Notify)
    _wifiStatusChar = service->createCharacteristic(
        CHAR_WIFI_STATUS_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );
    _wifiStatusChar->setValue("{\"connected\":false}");

    // wifi_provisioning (Write)
    _provisionChar = service->createCharacteristic(
        CHAR_WIFI_PROVISION_UUID,
        NIMBLE_PROPERTY::WRITE
    );
    _provisionChar->setCallbacks(new ProvisionWriteCallbacks(*this));

    // pairing_code (Read, encrypted — requires bonding)
    _pairingCodeChar = service->createCharacteristic(
        CHAR_PAIRING_CODE_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC
    );
    _pairingCodeChar->setValue(pairingCode);

    service->start();

    Serial.printf("[BLE] GATT service started, device=%s\n", deviceName);
    startAdvertising();
}

void BleManager::startAdvertising() {
    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->addServiceUUID(VENA_SERVICE_UUID);
    adv->setName(NimBLEDevice::getAddress().toString());
    adv->enableScanResponse(true);
    adv->start();
    Serial.println("[BLE] advertising started");
}

void BleManager::stopAdvertising() {
    NimBLEDevice::getAdvertising()->stop();
    Serial.println("[BLE] advertising stopped");
}

bool BleManager::isConnected() const {
    return _clientConnected;
}

void BleManager::notifyTelemetry(const char* jsonPayload) {
    if (!_clientConnected) return;
    _telemetryChar->setValue(jsonPayload);
    _telemetryChar->notify();
}

void BleManager::updateWifiStatus(bool connected, const char* ssid,
                                   const char* ip, int rssi) {
    JsonDocument doc;
    doc["connected"] = connected;
    if (connected && ssid) {
        doc["ssid"] = ssid;
        doc["ip"] = ip;
        doc["rssi"] = rssi;
    }
    String out;
    serializeJson(doc, out);
    _wifiStatusChar->setValue(out.c_str());
    if (_clientConnected) {
        _wifiStatusChar->notify();
    }
}

void BleManager::setProvisionCallback(ProvisionCallback cb) {
    _provisionCb = cb;
}
