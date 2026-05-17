#pragma once

#include <Arduino.h>
#include <PID_v1.h>

class PeltierController {
public:
    PeltierController(uint8_t peltierPin,
                      uint8_t fanIntPin,
                      uint8_t fanExtPin,
                      double kp, double ki, double kd,
                      unsigned long sampleMs,
                      double outputMin, double outputMax,
                      double slewPerSec);

    void begin();
    void setSetpoint(double c);
    void update(double pvDissipator);

    double lastOutput() const { return _appliedOutput; }
    double currentSetpoint() const { return _setpoint; }
    bool heatingClamped() const { return _heatingClamped; }

private:
    void applyOutputs(double signedOut);
    static double clampDelta(double current, double target, double maxDelta);

    uint8_t _peltierPin;
    uint8_t _fanIntPin;
    uint8_t _fanExtPin;

    double _input = 0.0;
    double _output = 0.0;
    double _setpoint;
    double _outputMin;
    double _outputMax;
    double _slewPerSec;
    unsigned long _sampleMs;

    double _appliedOutput = 0.0;
    unsigned long _lastApplyMs = 0;
    unsigned long _idleSinceMs = 0;
    bool _heatingClamped = false;

    PID _pid;
};
