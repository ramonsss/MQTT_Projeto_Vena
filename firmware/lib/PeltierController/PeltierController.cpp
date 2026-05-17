#include "PeltierController.h"
#include "config.h"

namespace {
    constexpr double DEADBAND = 10.0;          // |out| abaixo disso = idle
    constexpr uint32_t FAN_EXT_PURGE_MS = 30000; // purga calor residual ao parar
    constexpr uint8_t FAN_EXT_IDLE_DUTY = 76;    // ~30 %
    constexpr uint8_t FAN_INT_IDLE_DUTY = 76;    // ~30 % para homogeneizar
    constexpr uint8_t FAN_INT_MIN_DUTY = 153;    // 60 %
    constexpr uint8_t FAN_INT_MAX_DUTY = 255;    // 100 %
    constexpr uint8_t FAN_EXT_RUN_DUTY = 255;    // lado quente sempre 100 %
}

PeltierController::PeltierController(uint8_t peltierPin,
                                     uint8_t fanIntPin,
                                     uint8_t fanExtPin,
                                     double kp, double ki, double kd,
                                     unsigned long sampleMs,
                                     double outputMin, double outputMax,
                                     double slewPerSec)
    : _peltierPin(peltierPin),
      _fanIntPin(fanIntPin),
      _fanExtPin(fanExtPin),
      _setpoint(SETPOINT_C),
      _outputMin(outputMin),
      _outputMax(outputMax),
      _slewPerSec(slewPerSec),
      _sampleMs(sampleMs),
      // REVERSE: PV (dissipador) acima do setpoint deve aumentar saída positiva (refrigerar).
      _pid(&_input, &_output, &_setpoint, kp, ki, kd, REVERSE) {}

void PeltierController::begin() {
    ledcSetup(LEDC_CH_PELTIER, LEDC_FREQ_HZ, LEDC_RESOLUTION_BITS);
    ledcSetup(LEDC_CH_FAN_INT, LEDC_FREQ_HZ, LEDC_RESOLUTION_BITS);
    ledcSetup(LEDC_CH_FAN_EXT, LEDC_FREQ_HZ, LEDC_RESOLUTION_BITS);
    ledcAttachPin(_peltierPin, LEDC_CH_PELTIER);
    ledcAttachPin(_fanIntPin, LEDC_CH_FAN_INT);
    ledcAttachPin(_fanExtPin, LEDC_CH_FAN_EXT);

    ledcWrite(LEDC_CH_PELTIER, 0);
    ledcWrite(LEDC_CH_FAN_INT, 0);
    ledcWrite(LEDC_CH_FAN_EXT, 0);

    _pid.SetOutputLimits(_outputMin, _outputMax);
    _pid.SetSampleTime((int)_sampleMs);
    _pid.SetMode(AUTOMATIC);

    _lastApplyMs = millis();
}

void PeltierController::setSetpoint(double c) {
    _setpoint = c;
}

void PeltierController::update(double pvDissipator) {
    _input = pvDissipator;
    _pid.Compute();
    applyOutputs(_output);
}

double PeltierController::clampDelta(double current, double target, double maxDelta) {
    const double diff = target - current;
    if (diff > maxDelta) return current + maxDelta;
    if (diff < -maxDelta) return current - maxDelta;
    return target;
}

void PeltierController::applyOutputs(double signedOut) {
    const unsigned long now = millis();
    const double dt = (_lastApplyMs == 0) ? 0.0 : (now - _lastApplyMs) / 1000.0;
    _lastApplyMs = now;

    const double maxDelta = _slewPerSec * dt;
    const double rateLimited = (dt > 0.0) ? clampDelta(_appliedOutput, signedOut, maxDelta) : signedOut;
    _appliedOutput = rateLimited;

    // Aquecimento exigiria ponte H; sem isso, clampamos e sinalizamos.
    if (_appliedOutput < 0.0) {
        _heatingClamped = true;
    }

    if (_appliedOutput > DEADBAND) {
        const uint8_t peltierDuty = (uint8_t)constrain(_appliedOutput, 0.0, 255.0);
        const double norm = constrain(_appliedOutput / 255.0, 0.0, 1.0);
        const uint8_t fanIntDuty = (uint8_t)(FAN_INT_MIN_DUTY + norm * (FAN_INT_MAX_DUTY - FAN_INT_MIN_DUTY));
        ledcWrite(LEDC_CH_PELTIER, peltierDuty);
        ledcWrite(LEDC_CH_FAN_INT, fanIntDuty);
        ledcWrite(LEDC_CH_FAN_EXT, FAN_EXT_RUN_DUTY);
        _idleSinceMs = 0;
    } else {
        if (_idleSinceMs == 0) _idleSinceMs = now;
        ledcWrite(LEDC_CH_PELTIER, 0);
        ledcWrite(LEDC_CH_FAN_INT, FAN_INT_IDLE_DUTY);
        const bool stillPurging = (now - _idleSinceMs) < FAN_EXT_PURGE_MS;
        ledcWrite(LEDC_CH_FAN_EXT, stillPurging ? FAN_EXT_IDLE_DUTY : 0);
    }
}
