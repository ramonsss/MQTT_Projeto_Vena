#include <Arduino.h>
#include <esp_mac.h>

void setup() {
    Serial.begin(115200);
    delay(500);

    uint8_t mac[6];
    esp_efuse_mac_get_default(mac);

    Serial.printf("Base MAC:  %02X:%02X:%02X:%02X:%02X:%02X\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    Serial.printf("device_id: vena-%02x%02x%02x%02x%02x%02x\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    Serial.printf("ble_name:  Vena-%02X%02X\n", mac[4], mac[5]);
    Serial.printf("WiFi MAC:  %02X:%02X:%02X:%02X:%02X:%02X\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    Serial.printf("BLE  MAC:  %02X:%02X:%02X:%02X:%02X:%02X\n",
                  mac[0], mac[1], mac[2], mac[3], mac[4] + 2, mac[5]);
}

void loop() {}
