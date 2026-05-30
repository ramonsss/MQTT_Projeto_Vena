#include "NvsJwt.h"
#include "config.h"
#include <Preferences.h>

static const char* NVS_NAMESPACE = "vena";
static const char* NVS_KEY       = MQTT_NVS_JWT_KEY;

String nvs_load_jwt() {
    Preferences prefs;
    prefs.begin(NVS_NAMESPACE, /*readOnly=*/true);
    String token = prefs.getString(NVS_KEY, "");
    prefs.end();
    return token;
}

bool nvs_store_jwt(const String& token) {
    Preferences prefs;
    if (!prefs.begin(NVS_NAMESPACE, /*readOnly=*/false)) {
        return false;
    }
    bool ok = prefs.putString(NVS_KEY, token) > 0;
    prefs.end();
    return ok;
}
