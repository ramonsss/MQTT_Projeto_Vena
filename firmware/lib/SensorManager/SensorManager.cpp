#include "SensorManager.h"

SensorManager::SensorManager(uint8_t pinAmbient, uint8_t pinOneWire)
    : _ambient(pinAmbient, DHT22),
      _oneWire(pinOneWire),
      _ds18b20(&_oneWire) {}

void SensorManager::begin() {
    _ambient.begin();
    _ds18b20.begin();
}

bool SensorManager::readAmbient(float& tempC, float& humidity) {
    return readSensor(_ambient, _ambientCache, tempC, humidity);
}

bool SensorManager::readDS18B20(float& tempC) {
    _ds18b20.requestTemperatures();
    float t = _ds18b20.getTempCByIndex(0);
    if (t == DEVICE_DISCONNECTED_C) {
        if (!isnan(_ds18b20Last)) {
            tempC = _ds18b20Last;
        }
        return false;
    }
    _ds18b20Last = t;
    tempC = t;
    return true;
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
