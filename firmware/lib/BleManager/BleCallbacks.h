#pragma once

#include <NimBLEDevice.h>
#include <ArduinoJson.h>
#include "config.h"
#include "BleManager.h"

class VenaServerCallbacks : public NimBLEServerCallbacks {
public:
    explicit VenaServerCallbacks(BleManager& mgr) : _mgr(mgr) {}

    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
        _mgr._clientCount++;
        Serial.printf("[BLE] client connected (%d total), addr=%s\n",
                      _mgr._clientCount,
                      connInfo.getAddress().toString().c_str());
        // Request higher MTU for JSON payloads
        pServer->setDataLen(connInfo.getConnHandle(), BLE_MTU);
        // Re-advertise so other clients can still discover this device
        _mgr.startAdvertising();
    }

    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
        if (_mgr._clientCount > 0) _mgr._clientCount--;
        Serial.printf("[BLE] client disconnected (%d remain), reason=%d\n",
                      _mgr._clientCount, reason);
        NimBLEDevice::deleteAllBonds();  // clear stale bonds — every connection is fresh
        // Resume advertising so another client can connect
        _mgr.startAdvertising();
    }

private:
    BleManager& _mgr;
};

class ProvisionWriteCallbacks : public NimBLECharacteristicCallbacks {
public:
    explicit ProvisionWriteCallbacks(BleManager& mgr) : _mgr(mgr) {}

    void onWrite(NimBLECharacteristic* pChar, NimBLEConnInfo& connInfo) override {
        std::string value = pChar->getValue();
        if (value.empty()) return;

        Serial.println("[BLE] wifi_provisioning write received");

        // Parse JSON with ArduinoJson — order-independent, robust.
        JsonDocument doc;
        DeserializationError err = deserializeJson(doc, value.c_str(), value.size());
        if (err) {
            Serial.printf("[BLE] provision JSON parse error: %s\n", err.c_str());
            return;
        }

        // ssid and psk are mandatory
        if (!doc["ssid"].is<const char*>() || !doc["psk"].is<const char*>()) {
            Serial.println("[BLE] provision parse error: missing ssid or psk");
            return;
        }

        WifiCredentials creds;
        creds.ssid = String(doc["ssid"].as<const char*>());
        creds.psk  = String(doc["psk"].as<const char*>());

        // JWT is optional — device can operate without auth in demo mode
        if (doc["jwt"].is<const char*>()) {
            creds.jwt = String(doc["jwt"].as<const char*>());
        }

        if (creds.ssid.isEmpty() || creds.psk.length() < 8) {
            Serial.println("[BLE] provision error: ssid empty or psk < 8 chars");
            return;
        }

        Serial.printf("[BLE] parsed provision: ssid=%s, jwt=%s\n",
                      creds.ssid.c_str(),
                      creds.jwt.isEmpty() ? "(none)" : "present");

        if (_mgr._provisionCb) {
            _mgr._provisionCb(creds);
        }
    }

private:
    BleManager& _mgr;
};
