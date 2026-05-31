#pragma once

#include <Arduino.h>
#include <DHT.h>
#include <OneWire.h>
#include <DallasTemperature.h>

class SensorManager {
public:
    SensorManager(uint8_t pinAmbient, uint8_t pinOneWire);

    void begin();
    bool readAmbient(float& tempC, float& humidity);
    /// DS18B20 on OneWire bus — used as primary PID input (more accurate).
    bool readDS18B20(float& tempC);

private:
    struct Cache {
        float tempC = NAN;
        float humidity = NAN;
        unsigned long lastReadMs = 0;
        bool hasValid = false;
    };

    bool readSensor(DHT& sensor, Cache& cache, float& tempC, float& humidity);

    DHT _ambient;
    OneWire _oneWire;
    DallasTemperature _ds18b20;
    Cache _ambientCache;
    float _ds18b20Last = NAN;

    static constexpr unsigned long MIN_INTERVAL_MS = 2000;  // DHT22 manda: ~0.5 Hz
};
