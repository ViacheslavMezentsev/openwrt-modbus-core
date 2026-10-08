#pragma once
#include <stdint.h>

class ButtonState {
 public:
  void begin(bool raw, uint32_t now) {
    raw_ = pressed_ = raw;
    changed_at_ = now;
    presses_ = 0;
  }
  void update(bool raw, uint32_t now) {
    if (raw != raw_) {
      raw_ = raw;
      changed_at_ = now;
    }
    if (raw_ != pressed_ && uint32_t(now - changed_at_) >= 30) {
      pressed_ = raw_;
      if (pressed_) ++presses_;
    }
  }
  bool pressed() const { return pressed_; }
  uint32_t presses() const { return presses_; }
 private:
  bool raw_ = false;
  bool pressed_ = false;
  uint32_t changed_at_ = 0;
  uint32_t presses_ = 0;
};
