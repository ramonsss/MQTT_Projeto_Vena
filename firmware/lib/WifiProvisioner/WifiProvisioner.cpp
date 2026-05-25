#include "WifiProvisioner.h"
#include "config.h"
#include <Preferences.h>

static Preferences prefs;

void WifiProvisioner::begin() {
    prefs.begin(PROV_NVS_NAMESPACE, true);  // read-only to check
    _hasCredentials = prefs.isKey(NVS_KEY_SSID);
    prefs.end();
}

bool WifiProvisioner::hasCredentials() const {
    return _hasCredentials;
}

StoredCredentials WifiProvisioner::loadCredentials() const {
    StoredCredentials creds;
    prefs.begin(PROV_NVS_NAMESPACE, true);
    creds.ssid = prefs.getString(NVS_KEY_SSID, "");
    creds.psk = prefs.getString(NVS_KEY_PSK, "");
    creds.jwt = prefs.getString(NVS_KEY_JWT, "");
    prefs.end();
    return creds;
}

void WifiProvisioner::saveCredentials(const String& ssid, const String& psk, const String& jwt) {
    prefs.begin(PROV_NVS_NAMESPACE, false);  // read-write
    prefs.putString(NVS_KEY_SSID, ssid);
    prefs.putString(NVS_KEY_PSK, psk);
    prefs.putString(NVS_KEY_JWT, jwt);
    prefs.end();
    _hasCredentials = true;
    Serial.printf("[PROV] credentials saved: ssid=%s\n", ssid.c_str());
}

void WifiProvisioner::clearCredentials() {
    prefs.begin(PROV_NVS_NAMESPACE, false);
    prefs.remove(NVS_KEY_SSID);
    prefs.remove(NVS_KEY_PSK);
    prefs.remove(NVS_KEY_JWT);
    prefs.end();
    _hasCredentials = false;
    Serial.println("[PROV] credentials cleared");
}
