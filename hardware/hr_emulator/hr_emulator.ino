/*
 * Linglong HR Emulator with HRV Support
 * ESP32 DEVKitV1 BLE Heart Rate Service emulator
 * 
 * Emulates a standard BLE Heart Rate Service (0x180D) with RR interval data (HRV)
 * for testing the Linglong mobile app with HRV-capable sensors.
 */

#include <NimBLEDevice.h>

static NimBLECharacteristic *hrChar;
static uint8_t bpm = 72; // start value
static int bpmCounter = 0; // counter for sinusoidal variation

// Simulate RR intervals based on heart rate
// RR interval (ms) ≈ 60000 / HR
void notifyHeartRateWithRRIntervals() {
  // Calculate RR interval from current BPM
  uint16_t rrInterval = (uint16_t)(60000 / bpm);
  
  // Add some jitter to RR intervals to simulate natural variability
  uint16_t rrJitter = rrInterval + (random(-20, 20));
  
  // Flags byte: bit 0 = HR format (0=8-bit, 1=16-bit)
  //             bit 4 = RR interval data present (1=yes)
  uint8_t flags = 0x10; // RR interval data present, 8-bit HR format
  
  // Build payload: [flags, HR, RR_low, RR_high, RR_low, RR_high, ...]
  uint8_t payload[7];
  payload[0] = flags;
  payload[1] = bpm;
  
  // Add 3 RR interval samples (each 2 bytes, little-endian)
  // RR1
  payload[2] = rrJitter & 0xFF;
  payload[3] = (rrJitter >> 8) & 0xFF;
  
  // RR2 with slight variation
  uint16_t rr2 = rrJitter + (random(-10, 10));
  payload[4] = rr2 & 0xFF;
  payload[5] = (rr2 >> 8) & 0xFF;
  
  // RR3 with slight variation
  uint16_t rr3 = rrJitter + (random(-10, 10));
  payload[6] = rr3 & 0xFF;
  // We'd need more bytes for a 4th RR value, so stick with 3
  
  hrChar->setValue(payload, 7);
  hrChar->notify();
  
  Serial.print("Notified HR: ");
  Serial.print(bpm);
  Serial.print(" bpm, RR intervals (ms): ");
  Serial.print(rrJitter);
  Serial.print(", ");
  Serial.print(rr2);
  Serial.print(", ");
  Serial.println(rr3);
  
  // Update BPM with sinusoidal variation to mimic natural heartbeat fluctuations
  bpm = 72 + (int)(8 * sin(bpmCounter * 0.05)) + random(-2, 3);
  bpm = constrain(bpm, 60, 100); // keep within realistic range
  bpmCounter++;
}

void setup() {
  Serial.begin(115200);
  Serial.println("\n=== Linglong HR Emulator with HRV Starting ===");
  
  NimBLEDevice::init("Linglong HR Emulator");
  NimBLEServer *server = NimBLEDevice::createServer();

  // Create Heart Rate Service
  NimBLEService *hrService = server->createService(NimBLEUUID((uint16_t)0x180D));
  hrChar = hrService->createCharacteristic(
      NimBLEUUID((uint16_t)0x2A37),
      NIMBLE_PROPERTY::NOTIFY);

  hrService->start();
  
  // Configure advertising
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(hrService->getUUID());
  adv->setMinInterval(100);  // 100ms min interval
  adv->setMaxInterval(200);  // 200ms max interval
  
  // Create advertising data with device name
  NimBLEAdvertisementData advData;
  advData.setName("Linglong HR Emulator");
  advData.addServiceUUID(NimBLEUUID((uint16_t)0x180D));
  advData.setCompleteServices(NimBLEUUID((uint16_t)0x180D));
  adv->setAdvertisementData(advData);
  
  // Create scan response data
  NimBLEAdvertisementData scanData;
  scanData.setName("Linglong HR Emulator");
  adv->setScanResponseData(scanData);
  
  adv->start();
  
  Serial.println("BLE Heart Rate Service started with HRV support");
  Serial.println("Device name: Linglong HR Emulator");
  Serial.println("HR Service UUID: 0x180D");
  Serial.println("HR Characteristic UUID: 0x2A37");
  Serial.println("Features: HR measurement + RR intervals (HRV)");
  Serial.println("Advertising started - Device should be discoverable");
  Serial.println("Ready for connections...\n");
}

void loop() {
  notifyHeartRateWithRRIntervals();
  delay(1000);
}
