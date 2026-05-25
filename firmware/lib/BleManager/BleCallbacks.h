#pragma once

#include <NimBLEDevice.h>
#include "config.h"
#include "BleManager.h"

class VenaServerCallbacks : public NimBLEServerCallbacks {
public:
    explicit VenaServerCallbacks(BleManager& mgr) : _mgr(mgr) {}

    void onConnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo) override {
        _mgr._clientConnected = true;
        Serial.print("[BLE] client connected, addr=");
        Serial.println(connInfo.getAddress().toString().c_str());
        // Request higher MTU for JSON payloads
        pServer->setDataLen(connInfo.getConnHandle(), BLE_MTU);
    }

    void onDisconnect(NimBLEServer* pServer, NimBLEConnInfo& connInfo, int reason) override {
        _mgr._clientConnected = false;
        Serial.printf("[BLE] client disconnected, reason=%d\n", reason);
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

        // Parse JSON: {"ssid":"...","psk":"...","jwt":"..."}
        // Minimal parsing without ArduinoJson to save stack in callback context
        String raw = String(value.c_str());
        WifiCredentials creds;

        int ssidStart = raw.indexOf("\"ssid\":\"") + 8;
        int ssidEnd = raw.indexOf("\"", ssidStart);
        if (ssidStart < 8 || ssidEnd < 0) {
            Serial.println("[BLE] provision parse error: missing ssid");
            return;
        }
        creds.ssid = raw.substring(ssidStart, ssidEnd);

        int pskStart = raw.indexOf("\"psk\":\"") + 7;
        int pskEnd = raw.indexOf("\"", pskStart);
        if (pskStart < 7 || pskEnd < 0) {
            Serial.println("[BLE] provision parse error: missing psk");
            return;
        }
        creds.psk = raw.substring(pskStart, pskEnd);

        int jwtStart = raw.indexOf("\"jwt\":\"") + 7;
        int jwtEnd = raw.indexOf("\"", jwtStart);
        if (jwtStart < 7 || jwtEnd < 0) {
            Serial.println("[BLE] provision parse error: missing jwt");
            return;
        }
        creds.jwt = raw.substring(jwtStart, jwtEnd);

        Serial.printf("[BLE] parsed provision: ssid=%s\n", creds.ssid.c_str());

        if (_mgr._provisionCb) {
            _mgr._provisionCb(creds);
        }
    }

private:
    BleManager& _mgr;
};
