#include "BleManager.h"
#include "BleCallbacks.h"
#include "ble_uuids.h"
#include "config.h"
#include <ArduinoJson.h>

void BleManager::init(const char* deviceName, const char* deviceId,
                      const char* pairingCode, const char* fwVersion) {
    strncpy(_deviceName, deviceName, sizeof(_deviceName) - 1);
    NimBLEDevice::init(deviceName);
    NimBLEDevice::deleteAllBonds();  // clear stale NVS bonds from previous firmware
    NimBLEDevice::setMTU(BLE_MTU);
    NimBLEDevice::setSecurityAuth(false, false, false);  // no bonding — security handled by backend
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);

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

    // pairing_code (Read — security enforced by backend bcrypt + PAIRING_SECRET)
    _pairingCodeChar = service->createCharacteristic(
        CHAR_PAIRING_CODE_UUID,
        NIMBLE_PROPERTY::READ
    );
    _pairingCodeChar->setValue(pairingCode);

    service->start();
    _server->start();

    Serial.printf("[BLE] GATT service started, device=%s\n", deviceName);
    startAdvertising();
}

void BleManager::startAdvertising() {
    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setName(_deviceName);
    adv->addServiceUUID(VENA_SERVICE_UUID);
    adv->enableScanResponse(true);
    adv->start();
    Serial.println("[BLE] advertising started");
}

void BleManager::stopAdvertising() {
    NimBLEDevice::getAdvertising()->stop();
    Serial.println("[BLE] advertising stopped");
}

bool BleManager::isConnected() const {
    return _clientCount > 0;
}

int BleManager::clientCount() const {
    return _clientCount;
}

void BleManager::notifyTelemetry(const char* jsonPayload) {
    if (_clientCount <= 0) return;
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
    if (_clientCount > 0) {
        _wifiStatusChar->notify();
    }
}

void BleManager::setProvisionCallback(ProvisionCallback cb) {
    _provisionCb = cb;
}
