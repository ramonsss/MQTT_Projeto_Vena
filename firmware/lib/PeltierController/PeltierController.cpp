#include "PeltierController.h"
#include "config.h"

PeltierController::PeltierController(uint8_t peltierPin,
                                     double kp, double ki, double kd,
                                     unsigned long sampleMs,
                                     double outputMin, double outputMax)
    : _peltierPin(peltierPin),
      _setpoint(SETPOINT_C),
      _kp(kp), _ki(ki), _kd(kd),
      _sampleMs(sampleMs),
      _outputMin(outputMin),
      _outputMax(outputMax) {}

void PeltierController::begin() {
    // PWM 20 kHz, 8-bit resolution (matches test code)
    ledcSetup(LEDC_CH_PELTIER, LEDC_FREQ_HZ, LEDC_RESOLUTION_BITS);
    ledcAttachPin(_peltierPin, LEDC_CH_PELTIER);
    // Start OFF (inverted: 255 = Peltier desligada)
    ledcWrite(LEDC_CH_PELTIER, 255);
    _tempoAnterior = millis();
}

void PeltierController::setSetpoint(double c) {
    _setpoint = c;
}

void PeltierController::update(double pvTemperature) {
    unsigned long agora = millis();
    if (agora - _tempoAnterior < _sampleMs) return;

    double dt = (double)(agora - _tempoAnterior) / 1000.0;
    _tempoAnterior = agora;

    // Erro positivo = precisa resfriar (temp acima do setpoint)
    _erro = pvTemperature - _setpoint;

    // Integral com anti-windup
    _integral += _erro * dt;
    _integral = constrain(_integral, -50.0, 50.0);

    // Derivativo
    double derivativo = (_erro - _erroAnterior) / dt;
    _erroAnterior = _erro;

    // Saída PID (0 = desligado, 255 = resfriamento máximo)
    _saidaPID = (_kp * _erro) + (_ki * _integral) + (_kd * derivativo);
    _saidaPID = constrain(_saidaPID, _outputMin, _outputMax);

    // Lógica invertida do driver 2N2222A:
    // saidaPID=255 (max frio) → PWM=0 (MOSFET totalmente ligado)
    // saidaPID=0   (desligado) → PWM=255 (MOSFET cortado)
    int valorPWMFinal = 255 - (int)_saidaPID;
    ledcWrite(LEDC_CH_PELTIER, valorPWMFinal);
}
