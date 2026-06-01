#pragma once

#include <Arduino.h>

/// Manual PID controller matching the original test firmware.
/// - Inverted PWM: duty 255 = Peltier OFF, duty 0 = Peltier MAX.
/// - No fan control (single-channel output).
/// - DS18B20 temperature feeds `update()`.
class PeltierController {
public:
    PeltierController(uint8_t peltierPin,
                      double kp, double ki, double kd,
                      unsigned long sampleMs,
                      double outputMin, double outputMax);

    void begin();
    void setSetpoint(double c);
    void update(double pvTemperature);

    double lastOutput() const { return _saidaPID; }
    double currentSetpoint() const { return _setpoint; }

private:
    uint8_t _peltierPin;
    double _setpoint;
    double _kp, _ki, _kd;
    unsigned long _sampleMs;
    double _outputMin, _outputMax;

    double _erro = 0;
    double _erroAnterior = 0;
    double _integral = 0;
    double _saidaPID = 0;
    unsigned long _tempoAnterior = 0;
};
