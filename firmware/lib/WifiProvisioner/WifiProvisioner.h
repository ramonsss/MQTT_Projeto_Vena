#pragma once

#include <Arduino.h>

struct StoredCredentials {
    String ssid;
    String psk;
    String jwt;
};

class WifiProvisioner {
public:
    void begin();
    bool hasCredentials() const;
    StoredCredentials loadCredentials() const;
    void saveCredentials(const String& ssid, const String& psk, const String& jwt);
    void clearCredentials();

private:
    bool _hasCredentials = false;
};
