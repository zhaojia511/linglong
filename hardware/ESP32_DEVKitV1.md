# ESP32 DEVKitV1 Heart Rate Sensor Emulator

Use an ESP32 DEVKitV1 to emulate a BLE Heart Rate Service (UUID 0x180D) for local testing with the Linglong mobile app and web/backend stack.

## Goal
- Advertise a BLE peripheral exposing the Heart Rate Service and Heart Rate Measurement characteristic (UUID 0x2A37).
- Stream synthetic heart rate values (60–180 bpm) at 1 Hz for end-to-end testing.

## Bill of materials
- 1x ESP32 DEVKitV1 board
- USB cable and a macOS host with Arduino IDE 2.x or PlatformIO

## Firmware approach (Arduino IDE + NimBLE)
1. Install ESP32 boards in Arduino IDE: `Preferences -> Additional Boards Manager URLs`, add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`, then install "esp32" via Boards Manager.
2. Install the `NimBLE-Arduino` library (Library Manager). It is lighter than the default BLE stack and supports multiple connections if needed.
3. Create a new sketch `hr_emulator.ino` with:
   - Heart Rate Service UUID 0x180D
   - Heart Rate Measurement characteristic UUID 0x2A37 (notify enabled)
   - Optional Battery Service 0x180F with Battery Level 0x2A19 (static 95%)
4. Flash settings: Board `ESP32 Dev Module`, Upload Speed `115200`, Partition Scheme `Default 4MB with spiffs`.
5. Flash and open Serial Monitor at 115200 baud to view logs.

## Minimal sketch
```cpp
#include <NimBLEDevice.h>

static NimBLECharacteristic *hrChar;
static uint8_t bpm = 72; // start value

// Packs a simple Heart Rate Measurement with 8-bit HR value
void notifyHeartRate() {
  uint8_t payload[2] = {0x00, bpm}; // 0x00 flags: uint8 bpm, no contact/energy
  hrChar->setValue(payload, sizeof(payload));
  hrChar->notify();
  bpm = bpm >= 165 ? 70 : bpm + 3; // sweep range for testing
}

void setup() {
  NimBLEDevice::init("Linglong HR Emulator");
  NimBLEServer *server = NimBLEDevice::createServer();

  NimBLEService *hrService = server->createService(NimBLEUUID((uint16_t)0x180D));
  hrChar = hrService->createCharacteristic(
      NimBLEUUID((uint16_t)0x2A37),
      NIMBLE_PROPERTY::NOTIFY);

  hrService->start();
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(hrService->getUUID());
  adv->setScanResponse(true);
  adv->start();
}

void loop() {
  notifyHeartRate();
  delay(1000);
}
```

## Test procedure
1. Power the board and flash the sketch.
2. On macOS, confirm advertising:
   - `bluetoothctl` -> `scan on` and look for `Linglong HR Emulator`.
3. In the Linglong mobile app, scan for sensors and connect. You should see live bpm values changing every second.
4. For backend/web E2E, let the mobile app record a short session using the emulator and sync; verify data appears via the API or web dashboard.

## Future enhancements
- Add GATT Battery Service and Device Information Service to mimic commercial sensors.
- Make bpm pattern configurable via serial commands (rest, tempo run, intervals).
- Provide a PlatformIO project with CI-ready firmware and tagged releases.
