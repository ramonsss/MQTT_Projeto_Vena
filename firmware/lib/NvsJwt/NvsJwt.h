#pragma once

#include <Arduino.h>

/**
 * NvsJwt — persist the device JWT in ESP32 NVS (non-volatile storage).
 *
 * The JWT is written once at provisioning time (via scripts/provision_nvs.py
 * or the /devices/{id}/provision REST endpoint) and read on every boot so
 * that MqttPublisher can use it as the MQTT username.
 *
 * NVS namespace: "vena"
 * NVS key:       MQTT_NVS_JWT_KEY (defined in config.h, default "device_jwt")
 */

/**
 * Load the device JWT from NVS.
 * @return The stored JWT string, or an empty String if not found.
 */
String nvs_load_jwt();

/**
 * Persist a device JWT to NVS.
 * @param token  The JWT to store.
 * @return true on success, false if NVS could not be opened for writing.
 */
bool nvs_store_jwt(const String& token);
