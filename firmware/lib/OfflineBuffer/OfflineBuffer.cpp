#include "OfflineBuffer.h"

OfflineBuffer::OfflineBuffer(size_t capacity)
    : _items(new String[capacity]), _capacity(capacity) {}

OfflineBuffer::~OfflineBuffer() {
    delete[] _items;
}

bool OfflineBuffer::push(const String& payload) {
    if (_count == _capacity) {
        // Descarta o mais antigo: leituras recentes têm mais valor para diagnóstico remoto.
        _head = (_head + 1) % _capacity;
        _count--;
    }
    _items[_tail] = payload;
    _tail = (_tail + 1) % _capacity;
    _count++;
    return true;
}

bool OfflineBuffer::peek(String& out) const {
    if (_count == 0) return false;
    out = _items[_head];
    return true;
}

void OfflineBuffer::pop() {
    if (_count == 0) return;
    _items[_head] = String();
    _head = (_head + 1) % _capacity;
    _count--;
}
