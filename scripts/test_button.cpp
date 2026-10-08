#include "../firmware/bluepill-modbus/bluepill_modbus/button_state.h"
#include <assert.h>
#include <stdio.h>

int main() {
  ButtonState b;
  b.begin(false, 0);
  b.update(true, 10);
  b.update(false, 15);
  b.update(true, 20);
  b.update(true, 49);
  assert(!b.pressed() && b.presses() == 0);
  b.update(true, 50);
  b.update(true, 500);
  assert(b.pressed() && b.presses() == 1);
  b.update(false, 510);
  b.update(false, 540);
  assert(!b.pressed() && b.presses() == 1);
  b.update(true, 600);
  b.update(true, 630);
  assert(b.presses() == 2);
  b.begin(true, 0);
  b.update(true, 100);
  assert(b.pressed() && b.presses() == 0);
  b.begin(false, 0xfffffff0U);
  b.update(true, 0xfffffff5U);
  b.update(true, 19);
  assert(b.pressed() && b.presses() == 1);
  puts("[test_button] OK");
}
