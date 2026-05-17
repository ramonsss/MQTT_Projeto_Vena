#include "DisplayManager.h"

DisplayManager::DisplayManager(uint8_t i2cAddr, uint8_t cols, uint8_t rows)
    : _lcd(i2cAddr, cols, rows), _cols(cols), _rows(rows) {}

void DisplayManager::begin() {
    _lcd.init();
    _lcd.backlight();
    _lcd.clear();
    for (uint8_t r = 0; r < 4; ++r) _lastLines[r] = "";
}

void DisplayManager::showStatus(float ambT, float ambH, float dissT, float setpoint, bool mqttUp) {
    char buf[21];

    snprintf(buf, sizeof(buf), "Ambiente T:%5.1fC", ambT);
    writeLineIfChanged(0, buf);

    snprintf(buf, sizeof(buf), "Ambiente U:%4.0f%%", ambH);
    writeLineIfChanged(1, buf);

    snprintf(buf, sizeof(buf), "Peltier  T:%5.1fC", dissT);
    writeLineIfChanged(2, buf);

    snprintf(buf, sizeof(buf), "SP:%4.1f MQTT:%s", setpoint, mqttUp ? "OK " : "OFF");
    writeLineIfChanged(3, buf);
}

void DisplayManager::writeLineIfChanged(uint8_t row, const String& text) {
    if (row >= _rows || row >= 4) return;
    if (_lastLines[row] == text) return;

    String padded = text;
    while ((uint8_t)padded.length() < _cols) padded += ' ';
    if ((uint8_t)padded.length() > _cols) padded = padded.substring(0, _cols);

    _lcd.setCursor(0, row);
    _lcd.print(padded);
    _lastLines[row] = text;
}
