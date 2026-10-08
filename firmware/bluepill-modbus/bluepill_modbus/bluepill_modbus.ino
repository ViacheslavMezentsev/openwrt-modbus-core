/*
 * USB CDC Modbus RTU server for WeAct BluePill Plus v1.1 STM32F103C8T6.
 *
 * Serial is reserved exclusively for Modbus frames. Do not add Serial.print()
 * calls: they would corrupt the RTU byte stream exposed to the router.
 */

#include <ModbusRTU.h>
#include "button_state.h"

namespace {

constexpr uint8_t kSlaveId = 1;
constexpr uint32_t kModbusBaudrate = 115200;
constexpr uint32_t kSampleIntervalMs = 20;

constexpr uint16_t kCoilDo0 = 0;
constexpr uint16_t kCoilDo1 = 1;
constexpr uint16_t kIstsDi0 = 0;
constexpr uint16_t kIstsDi1 = 1;
constexpr uint16_t kIregAi0Raw = 0;
constexpr uint16_t kIregAi1Raw = 1;
constexpr uint16_t kIregAi0Millivolts = 2;
constexpr uint16_t kIregAi1Millivolts = 3;
constexpr uint16_t kIregUptimeSeconds = 4;
constexpr uint16_t kHregAo0Pwm = 0;
constexpr uint16_t kSystemBase = 0x0100;
constexpr uint32_t kButtonPin = PA0;
constexpr uint32_t kLedPin = PB2;

constexpr uint32_t kDi0Pin = PB12;
constexpr uint32_t kDi1Pin = PB13;
constexpr uint32_t kDo0Pin = PC13;  // Legacy map; not the WeAct PB2 LED.
constexpr uint32_t kDo1Pin = PB0;
constexpr uint32_t kAi0Pin = PA2;
constexpr uint32_t kAi1Pin = PA1;
constexpr uint32_t kAo0PwmPin = PA8;

ModbusRTU mb;
ButtonState button;
uint32_t last_sample_at = 0;

uint16_t to_millivolts(uint16_t raw) {
  return static_cast<uint32_t>(raw) * 3300U / 4095U;
}

void apply_outputs() {
  digitalWrite(kDo0Pin, mb.Coil(kCoilDo0) ? LOW : HIGH);
  digitalWrite(kDo1Pin, mb.Coil(kCoilDo1) ? HIGH : LOW);
  const uint16_t pwm = mb.Hreg(kHregAo0Pwm);
  analogWrite(kAo0PwmPin, pwm > 4095 ? 4095 : pwm);
  digitalWrite(kLedPin, mb.Coil(kSystemBase) ? HIGH : LOW);
}

void sample_inputs() {
  const uint16_t ai0_raw = analogRead(kAi0Pin);
  const uint16_t ai1_raw = analogRead(kAi1Pin);

  mb.Ists(kIstsDi0, digitalRead(kDi0Pin) == LOW);
  mb.Ists(kIstsDi1, digitalRead(kDi1Pin) == LOW);
  mb.Ireg(kIregAi0Raw, ai0_raw);
  mb.Ireg(kIregAi1Raw, ai1_raw);
  mb.Ireg(kIregAi0Millivolts, to_millivolts(ai0_raw));
  mb.Ireg(kIregAi1Millivolts, to_millivolts(ai1_raw));
  mb.Ireg(kIregUptimeSeconds, millis() / 1000U);
  const uint32_t uptime = millis();
  const uint32_t presses = button.presses();
  mb.Ists(kSystemBase, button.pressed());
  mb.Ireg(kSystemBase + 3, button.pressed());
  mb.Ireg(kSystemBase + 4, presses >> 16);
  mb.Ireg(kSystemBase + 5, presses & 0xffff);
  mb.Ireg(kSystemBase + 6, uptime >> 16);
  mb.Ireg(kSystemBase + 7, uptime & 0xffff);
}

}  // namespace

void setup() {
  pinMode(kButtonPin, INPUT_PULLDOWN);
  digitalWrite(kLedPin, LOW);
  pinMode(kLedPin, OUTPUT);
  // A held bootloader key is the initial state, not a new press.
  button.begin(digitalRead(kButtonPin) == HIGH, millis());
  pinMode(kDi0Pin, INPUT_PULLUP);
  pinMode(kDi1Pin, INPUT_PULLUP);
  pinMode(kDo0Pin, OUTPUT);
  pinMode(kDo1Pin, OUTPUT);
  pinMode(kAo0PwmPin, OUTPUT);

  analogReadResolution(12);
  analogWriteResolution(12);

  Serial.begin(kModbusBaudrate);
  mb.begin(&Serial);
  mb.setBaudrate(kModbusBaudrate);
  mb.server(kSlaveId);

  mb.addCoil(kCoilDo0, false);
  mb.addCoil(kCoilDo1, false);
  mb.addIsts(kIstsDi0, false);
  mb.addIsts(kIstsDi1, false);
  mb.addIreg(kIregAi0Raw, 0);
  mb.addIreg(kIregAi1Raw, 0);
  mb.addIreg(kIregAi0Millivolts, 0);
  mb.addIreg(kIregAi1Millivolts, 0);
  mb.addIreg(kIregUptimeSeconds, 0);
  mb.addHreg(kHregAo0Pwm, 0);
  mb.addCoil(kSystemBase, false);
  mb.addIsts(kSystemBase, false);
  mb.addIreg(kSystemBase, 0, 8);
  mb.Ireg(kSystemBase, 0x5741);  // WeAct profile signature.
  mb.Ireg(kSystemBase + 1, 2);  // Register map version.
  mb.Ireg(kSystemBase + 2, 3);  // Button counter and system LED capabilities.

  apply_outputs();
  sample_inputs();
}

void loop() {
  mb.task();

  const uint32_t now = millis();
  button.update(digitalRead(kButtonPin) == HIGH, now);
  if (now - last_sample_at >= kSampleIntervalMs) {
    last_sample_at = now;
    sample_inputs();
    apply_outputs();
  }
}
