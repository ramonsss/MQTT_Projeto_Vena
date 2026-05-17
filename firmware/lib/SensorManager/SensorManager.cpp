#include "SensorManager.h"

SensorManager::SensorManager(uint8_t pinAmbient, uint8_t pinDissipator)
    : _ambient(pinAmbient, DHT22), _dissipator(pinDissipator, DHT22) {}

void SensorManager::begin() {
    _ambient.begin();
    _dissipator.begin();
}

bool SensorManager::readAmbient(float& tempC, float& humidity) {
    return readSensor(_ambient, _ambientCache, tempC, humidity);
}

bool SensorManager::readDissipator(float& tempC, float& humidity) {
    return readSensor(_dissipator, _dissipatorCache, tempC, humidity);
}

bool SensorManager::readSensor(DHT& sensor, Cache& cache, float& tempC, float& humidity) {
    const unsigned long now = millis();
    if (cache.hasValid && (now - cache.lastReadMs) < MIN_INTERVAL_MS) {
        tempC = cache.tempC;
        humidity = cache.humidity;
        return true;
    }

    const float t = sensor.readTemperature();
    const float h = sensor.readHumidity();
    cache.lastReadMs = now;

    if (isnan(t) || isnan(h)) {
        if (cache.hasValid) {
            tempC = cache.tempC;
            humidity = cache.humidity;
        }
        return false;
    }

    cache.tempC = t;
    cache.humidity = h;
    cache.hasValid = true;
    tempC = t;
    humidity = h;
    return true;
}
