#pragma once

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>

class DisplayManager {
public:
    DisplayManager(uint8_t i2cAddr, uint8_t cols, uint8_t rows);

    void begin();
    void showStatus(float ambT, float ambH, float dissT, float setpoint, bool mqttUp);

private:
    void writeLineIfChanged(uint8_t row, const String& text);

    LiquidCrystal_I2C _lcd;
    uint8_t _cols;
    uint8_t _rows;
    String _lastLines[4];
};
