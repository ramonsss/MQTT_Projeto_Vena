#pragma once

#include <Arduino.h>

class OfflineBuffer {
public:
    explicit OfflineBuffer(size_t capacity);
    ~OfflineBuffer();

    bool push(const String& payload);
    bool peek(String& out) const;
    void pop();
    size_t size() const { return _count; }
    size_t capacity() const { return _capacity; }
    bool empty() const { return _count == 0; }

private:
    String* _items;
    size_t _capacity;
    size_t _head = 0;   // próximo a sair (peek)
    size_t _tail = 0;   // próximo slot livre
    size_t _count = 0;
};
