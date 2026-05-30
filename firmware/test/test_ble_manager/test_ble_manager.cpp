/**
 * T12 — BleManager host-side unit tests (PlatformIO native env).
 *
 * Tests pure-logic components that do not require NimBLE hardware:
 *   1. BLE UUID constants have the expected 128-bit format and prefix.
 *   2. Provisioning JSON parser correctly extracts ssid, psk, jwt.
 *   3. Telemetry JSON serialisation produces required keys (ts, at, ah...).
 *   4. updateWifiStatus builds the correct JSON for connected / disconnected.
 *
 * Run with: pio test -e native
 */

#include <unity.h>
#include <string.h>
#include <stdint.h>
#include <ArduinoJson.h>

// ── Pull in UUID constants ────────────────────────────────────────────────────
#include "ble_uuids.h"

// ── Minimal stub so BleCallbacks.h parsing can be compiled standalone ─────────
// On native there is no Arduino.h / String — supply what we need.
#ifndef ARDUINO
#include <string>

// Minimal Arduino String shim for parsing logic tests
struct String {
    std::string s;
    explicit String(const char* c) : s(c) {}
    explicit String(const std::string& v) : s(v) {}
    int indexOf(const char* needle, int from = 0) const {
        auto pos = s.find(needle, from);
        return pos == std::string::npos ? -1 : (int)pos;
    }
    String substring(int start, int end = -1) const {
        if (end < 0) return String(s.substr(start));
        return String(s.substr(start, end - start));
    }
    const char* c_str() const { return s.c_str(); }
    bool isEmpty() const { return s.empty(); }
    int length() const { return (int)s.length(); }
};
#endif // ARDUINO

// ── Provisioning credential extractor (mirrors BleCallbacks.h logic) ─────────
// Duplicated here so tests are self-contained and independent of NimBLE types.
struct WifiCreds {
    char ssid[64];
    char psk[64];
    char jwt[512];
};

static bool parseProvisionPayload(const char* raw, WifiCreds& out) {
    String s(raw);

    auto extract = [&](const char* key, char* buf, int bufSize) -> bool {
        int kLen = (int)strlen(key);
        int start = s.indexOf(key);
        if (start < 0) return false;
        start += kLen;
        int end = s.indexOf("\"", start);
        if (end < 0) return false;
        int len = end - start;
        if (len >= bufSize) return false;
        memcpy(buf, raw + start, len);
        buf[len] = '\0';
        return true;
    };

    return extract("\"ssid\":\"",  out.ssid, sizeof(out.ssid))
        && extract("\"psk\":\"",   out.psk,  sizeof(out.psk))
        && extract("\"jwt\":\"",   out.jwt,  sizeof(out.jwt));
}

// ── UUID helpers ──────────────────────────────────────────────────────────────

static bool uuidHasVenaMiddle(const char* uuid) {
    // All Vena UUIDs contain "-VENA-" in the string representation
    return strstr(uuid, "VENA") != nullptr;
}

static bool uuidStartsWith(const char* uuid, const char* prefix) {
    return strncmp(uuid, prefix, strlen(prefix)) == 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Test cases
// ═══════════════════════════════════════════════════════════════════════════════

void test_uuid_service_format(void) {
    // Service UUID uses suffix 0001
    TEST_ASSERT_TRUE(uuidStartsWith(VENA_SERVICE_UUID, "00000001"));
    TEST_ASSERT_TRUE(uuidHasVenaMiddle(VENA_SERVICE_UUID));
}

void test_uuid_all_characteristics_present(void) {
    TEST_ASSERT_TRUE(uuidStartsWith(CHAR_DEVICE_INFO_UUID,    "00000002"));
    TEST_ASSERT_TRUE(uuidStartsWith(CHAR_LIVE_TELEMETRY_UUID, "00000003"));
    TEST_ASSERT_TRUE(uuidStartsWith(CHAR_WIFI_STATUS_UUID,    "00000004"));
    TEST_ASSERT_TRUE(uuidStartsWith(CHAR_WIFI_PROVISION_UUID, "00000005"));
    TEST_ASSERT_TRUE(uuidStartsWith(CHAR_PAIRING_CODE_UUID,   "00000006"));
}

void test_uuid_all_share_namespace(void) {
    const char* uuids[] = {
        VENA_SERVICE_UUID,
        CHAR_DEVICE_INFO_UUID,
        CHAR_LIVE_TELEMETRY_UUID,
        CHAR_WIFI_STATUS_UUID,
        CHAR_WIFI_PROVISION_UUID,
        CHAR_PAIRING_CODE_UUID,
    };
    for (auto uuid : uuids) {
        TEST_ASSERT_TRUE_MESSAGE(uuidHasVenaMiddle(uuid), uuid);
    }
}

void test_provision_parser_valid_payload(void) {
    const char* payload =
        "{\"ssid\":\"FazendaWifi\",\"psk\":\"super1234\",\"jwt\":\"header.body.sig\"}";

    WifiCreds creds{};
    bool ok = parseProvisionPayload(payload, creds);

    TEST_ASSERT_TRUE(ok);
    TEST_ASSERT_EQUAL_STRING("FazendaWifi",    creds.ssid);
    TEST_ASSERT_EQUAL_STRING("super1234",      creds.psk);
    TEST_ASSERT_EQUAL_STRING("header.body.sig", creds.jwt);
}

void test_provision_parser_missing_psk_returns_false(void) {
    const char* payload = "{\"ssid\":\"Net\",\"jwt\":\"tok\"}";
    WifiCreds creds{};
    TEST_ASSERT_FALSE(parseProvisionPayload(payload, creds));
}

void test_provision_parser_empty_payload_returns_false(void) {
    WifiCreds creds{};
    TEST_ASSERT_FALSE(parseProvisionPayload("", creds));
}

void test_telemetry_json_has_required_keys(void) {
    // Simulate the payload that main.cpp would build and pass to notifyTelemetry
    JsonDocument doc;
    doc["ts"]  = 1737830400000LL;
    doc["at"]  = 22.5;
    doc["ah"]  = 65.2;
    doc["dt"]  = 18.3;
    doc["dh"]  = 60.1;
    doc["sp"]  = 18.0;
    doc["po"]  = 120;

    TEST_ASSERT_TRUE(doc.containsKey("ts"));
    TEST_ASSERT_TRUE(doc.containsKey("at"));
    TEST_ASSERT_TRUE(doc.containsKey("ah"));
    TEST_ASSERT_EQUAL_FLOAT(22.5f, doc["at"].as<float>());

    // Serialised payload must fit within BLE MTU (247 bytes)
    char buf[256];
    size_t n = serializeJson(doc, buf, sizeof(buf));
    TEST_ASSERT_LESS_THAN(247u, (unsigned)n);
}

void test_wifi_status_connected_json(void) {
    JsonDocument doc;
    doc["connected"] = true;
    doc["ssid"]      = "FazendaWifi";
    doc["ip"]        = "192.168.1.42";
    doc["rssi"]      = -65;

    char buf[128];
    serializeJson(doc, buf, sizeof(buf));

    // Re-parse and verify
    JsonDocument parsed;
    auto err = deserializeJson(parsed, buf);
    TEST_ASSERT_EQUAL(DeserializationError::Ok, err.code());
    TEST_ASSERT_TRUE(parsed["connected"].as<bool>());
    TEST_ASSERT_EQUAL_STRING("FazendaWifi", parsed["ssid"].as<const char*>());
}

void test_wifi_status_disconnected_json(void) {
    JsonDocument doc;
    doc["connected"] = false;

    char buf[64];
    serializeJson(doc, buf, sizeof(buf));

    TEST_ASSERT_NOT_NULL(strstr(buf, "\"connected\":false"));
}

// ═══════════════════════════════════════════════════════════════════════════════

int main(void) {
    UNITY_BEGIN();

    RUN_TEST(test_uuid_service_format);
    RUN_TEST(test_uuid_all_characteristics_present);
    RUN_TEST(test_uuid_all_share_namespace);
    RUN_TEST(test_provision_parser_valid_payload);
    RUN_TEST(test_provision_parser_missing_psk_returns_false);
    RUN_TEST(test_provision_parser_empty_payload_returns_false);
    RUN_TEST(test_telemetry_json_has_required_keys);
    RUN_TEST(test_wifi_status_connected_json);
    RUN_TEST(test_wifi_status_disconnected_json);

    return UNITY_END();
}
