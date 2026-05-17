#pragma once

#include <Arduino.h>
#include <DHT.h>

class SensorManager {
public:
    SensorManager(uint8_t pinAmbient, uint8_t pinDissipator);

    void begin();
    bool readAmbient(float& tempC, float& humidity);
    bool readDissipator(float& tempC, float& humidity);

private:
    struct Cache {
        float tempC = NAN;
        float humidity = NAN;
        unsigned long lastReadMs = 0;
        bool hasValid = false;
    };

    bool readSensor(DHT& sensor, Cache& cache, float& tempC, float& humidity);

    DHT _ambient;
    DHT _dissipator;
    Cache _ambientCache;
    Cache _dissipatorCache;

    static constexpr unsigned long MIN_INTERVAL_MS = 2000;  // DHT22 manda: ~0.5 Hz
};
