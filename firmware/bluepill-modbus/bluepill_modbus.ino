/*
 * USB CDC Modbus RTU server for a WeAct BluePill STM32F103CB.
 *
 * Serial is reserved exclusively for Modbus frames. Do not add Serial.print()
 * calls: they would corrupt the RTU byte stream exposed to the router.
 */

#include <ModbusRTU.h>

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

constexpr PinName kDi0Pin = PB12;
constexpr PinName kDi1Pin = PB13;
constexpr PinName kDo0Pin = PC13;  // Built-in BluePill LED, active low.
constexpr PinName kDo1Pin = PB0;
constexpr PinName kAi0Pin = PA0;
constexpr PinName kAi1Pin = PA1;
constexpr PinName kAo0PwmPin = PA8;

ModbusRTU mb;
uint32_t last_sample_at = 0;

uint16_t to_millivolts(uint16_t raw) {
  return static_cast<uint32_t>(raw) * 3300U / 4095U;
}

void apply_outputs() {
  digitalWrite(kDo0Pin, mb.Coil(kCoilDo0) ? LOW : HIGH);
  digitalWrite(kDo1Pin, mb.Coil(kCoilDo1) ? HIGH : LOW);
  analogWrite(kAo0PwmPin, mb.Hreg(kHregAo0Pwm));
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
}

}  // namespace

void setup() {
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

  apply_outputs();
  sample_inputs();
}

void loop() {
  mb.task();

  const uint32_t now = millis();
  if (now - last_sample_at >= kSampleIntervalMs) {
    last_sample_at = now;
    sample_inputs();
    apply_outputs();
  }
}
