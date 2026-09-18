/**
 * ============================================================
 *  VETRI ESP32 OBD-II Bluetooth Firmware  v1.0.0
 *  Board  : ESP32-WROOM-32
 *  CAN    : MCP2515 (SPI) + SN65HVD230 transceiver
 *  BLE    : Internal ESP32 BLE (GATT Server, NOTIFY)
 *  Buzzer : Active buzzer on IO2 via 2N2222 NPN transistor
 *
 *  Arduino IDE Libraries Required:
 *    - ESP32 Arduino board package by Espressif Systems
 *    - mcp2515 by autowp (v1.0.3+)
 *    - BLEDevice (built-in with ESP32 core)
 *
 *  HOW THIS CONNECTS TO THE VETRI APP:
 *    1. This ESP32 acts as a BLE GATT Server
 *    2. Service UUID  : 0000FFE0-0000-1000-8000-00805F9B34FB
 *    3. Char UUID     : 0000FFE1-0000-1000-8000-00805F9B34FB (NOTIFY)
 *    4. App scans and connects to device named "VETRI-OBD"
 *    5. Every 200ms ESP32 sends a semicolon-delimited telemetry string:
 *         "VIN:MD2A00MD1;RPM:1423;SPD:42.3;CLT:89.4;BAT:12.85;STFT:+1.2;LTFT:-0.8"
 *    6. App parser splits on ';', then on ':', and maps keys to gauges.
 *
 *  AUTO FALLBACK: If no CAN data received in 2 seconds (bike OFF or bench test),
 *  the firmware automatically switches to realistic simulation so the app always
 *  shows dynamic data.
 * ============================================================
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <mcp2515.h>
#include <SPI.h>

// ─── Pin Definitions (matches your schematic) ─────────────────────────────────
#define MCP2515_CS_PIN    5    // SPI Chip Select for MCP2515
#define MCP2515_INT_PIN   4    // MCP2515 interrupt signal
#define BUZZER_PIN        2    // Active buzzer via 2N2222 NPN

// ─── BLE UUIDs ───────────────────────────────────────────────────────────────
#define SERVICE_UUID        "0000FFE0-0000-1000-8000-00805F9B34FB"
#define CHARACTERISTIC_UUID "0000FFE1-0000-1000-8000-00805F9B34FB"

// ─── Vehicle VIN ──────────────────────────────────────────────────────────────
// EDIT THIS to your actual VIN. The app reads the prefix to auto-detect vehicle type:
//   MD2 = Hero/Bajaj 2-Wheeler   |  ME4 = Honda 2-Wheeler  |  MB1 = TVS
//   MA3 = Maruti Suzuki Car      |  MAL = Hyundai India    |  WVW = Volkswagen
const char* VEHICLE_VIN = "MD2A00MD1JX123456";

// ─── Globals ──────────────────────────────────────────────────────────────────
MCP2515            mcp2515(MCP2515_CS_PIN);
struct can_frame   canFrame;
BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool               deviceConnected = false;

// Telemetry state
float engineRpm       = 0.0f;
float vehicleSpeedKmh = 0.0f;
float coolantTempC    = 70.0f;
float batteryVoltage  = 12.6f;
float shortFuelTrim   = 0.0f;
float longFuelTrim    = 0.0f;
unsigned long packetCount = 0;

// ─── BLE Server Callbacks ─────────────────────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* srv) override {
    deviceConnected = true;
    Serial.println("[BLE] VETRI App connected!");
  }
  void onDisconnect(BLEServer* srv) override {
    deviceConnected = false;
    Serial.println("[BLE] App disconnected. Restarting advertising...");
    srv->startAdvertising();
  }
};

// ─── OBD-II CAN PID Decoder ───────────────────────────────────────────────────
/*
 * Standard OBD-II Mode 01 responses:
 *   CAN ID: 0x7E8 (ECU response frame)
 *   Byte 0: extra bytes count
 *   Byte 1: 0x41 (Mode 01 positive response)
 *   Byte 2: PID code
 *   Byte 3: Value A   |  Byte 4: Value B
 *
 *   PID 0x0C = Engine RPM     -> ((A*256)+B) / 4
 *   PID 0x0D = Vehicle Speed  -> A  (km/h)
 *   PID 0x05 = Coolant Temp   -> A - 40  (Celsius)
 *   PID 0x06 = STFT Bank 1    -> (A/1.28) - 100  (%)
 *   PID 0x07 = LTFT Bank 1    -> (A/1.28) - 100  (%)
 */
void decodeCAN() {
  if (mcp2515.readMessage(&canFrame) == MCP2515::ERROR_OK) {
    uint16_t id = canFrame.can_id;

    if (id == 0x7E8 && canFrame.can_dlc >= 4) {
      uint8_t pid = canFrame.data[2];
      uint8_t A   = canFrame.data[3];
      uint8_t B   = (canFrame.can_dlc >= 5) ? canFrame.data[4] : 0;

      switch (pid) {
        case 0x0C: engineRpm       = ((A * 256.0f) + B) / 4.0f;  break;
        case 0x0D: vehicleSpeedKmh = (float)A;                    break;
        case 0x05: coolantTempC    = (float)A - 40.0f;            break;
        case 0x06: shortFuelTrim   = (A / 1.28f) - 100.0f;        break;
        case 0x07: longFuelTrim    = (A / 1.28f) - 100.0f;        break;
      }
    }

    // Battery voltage - adjust CAN ID 0x620 to match your ECU's proprietary frame
    if (id == 0x620 && canFrame.can_dlc >= 2) {
      batteryVoltage = ((canFrame.data[0] * 256.0f) + canFrame.data[1]) / 1000.0f;
    }
  }
}

// ─── Demo / Bench Simulation ──────────────────────────────────────────────────
// Generates realistic data when no CAN bus is connected (bench testing / bike OFF)
void simulateTelemetry() {
  packetCount++;
  float t = packetCount * 0.2f;

  if (t < 20.0f) {
    // Cold start sequence
    engineRpm       = 1800.0f + 200.0f * sin(t * 0.5f) + random(-50, 50);
    coolantTempC    = 40.0f + t * 2.0f;
    vehicleSpeedKmh = 0.0f;
  } else if (t < 60.0f) {
    // Pulling away
    engineRpm       = 2500.0f + 800.0f * sin(t * 0.3f) + random(-80, 80);
    vehicleSpeedKmh = (t - 20.0f) * 1.5f;
    coolantTempC    = 80.0f + 8.0f * sin(t * 0.1f);
  } else {
    // Highway cruise
    engineRpm       = 3200.0f + 600.0f * sin(t * 0.15f) + random(-100, 100);
    vehicleSpeedKmh = 55.0f + 20.0f * sin(t * 0.05f);
    coolantTempC    = 88.0f + 5.0f * sin(t * 0.07f);
  }

  batteryVoltage = constrain(12.85f - packetCount * 0.000005f, 11.5f, 14.8f);
  shortFuelTrim  = 1.2f + 0.5f * sin(t * 0.2f);
  longFuelTrim   = -0.8f + 0.2f * sin(t * 0.1f);
  engineRpm      = constrain(engineRpm, 0, 12000);
  vehicleSpeedKmh = constrain(vehicleSpeedKmh, 0, 160);
  coolantTempC   = constrain(coolantTempC, 20, 115);
}

// ─── Build VETRI Telemetry Frame ──────────────────────────────────────────────
// Format: "VIN:<vin>;RPM:<val>;SPD:<val>;CLT:<val>;BAT:<val>;STFT:<val>;LTFT:<val>"
// The VETRI app splits on ';' then ':' to map each key to its gauge/sensor.
String buildFrame() {
  char buf[220];
  snprintf(buf, sizeof(buf),
    "VIN:%s;RPM:%.0f;SPD:%.1f;CLT:%.1f;BAT:%.2f;STFT:%+.1f;LTFT:%+.1f",
    VEHICLE_VIN, engineRpm, vehicleSpeedKmh,
    coolantTempC, batteryVoltage, shortFuelTrim, longFuelTrim
  );
  return String(buf);
}

// ─── Buzzer Helper ────────────────────────────────────────────────────────────
void buzzAlert(int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(150);
    digitalWrite(BUZZER_PIN, LOW);
    delay(100);
  }
}

// ─── Setup ───────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("[VETRI] Firmware v1.0.0 booting...");

  // Buzzer setup
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);
  buzzAlert(1);  // Single beep = power on

  // MCP2515 CAN Bus setup (500kbps for standard OBD-II)
  SPI.begin();
  mcp2515.reset();
  if (mcp2515.setBitrate(CAN_500KBPS, MCP_8MHZ) == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    Serial.println("[CAN] MCP2515 ready at 500kbps");
  } else {
    Serial.println("[CAN] MCP2515 unavailable - demo simulation mode active");
    // App will still receive data - simulation kicks in automatically
  }

  // BLE GATT Server setup
  BLEDevice::init("VETRI-OBD");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* svc = pServer->createService(SERVICE_UUID);
  pCharacteristic = svc->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising as 'VETRI-OBD' - open VETRI app and scan!");
  buzzAlert(2);  // Double beep = BLE ready
}

// ─── Main Loop ───────────────────────────────────────────────────────────────
void loop() {
  static unsigned long lastSend = 0;
  static unsigned long lastCAN  = 0;

  // Read real CAN data if available
  if (digitalRead(MCP2515_INT_PIN) == LOW) {
    decodeCAN();
    lastCAN = millis();
  }

  // Auto-switch to simulation if CAN silent for 2 seconds
  if (millis() - lastCAN > 2000) {
    simulateTelemetry();
  }

  // Broadcast BLE GATT notify at 5Hz (200ms interval)
  if (deviceConnected && (millis() - lastSend >= 200)) {
    lastSend = millis();
    String frame = buildFrame();
    pCharacteristic->setValue(frame.c_str());
    pCharacteristic->notify();
    Serial.println("[TX] " + frame);
  }

  // Overheat alert: 3 rapid buzzer beeps when coolant > 105C
  if (coolantTempC > 105.0f) {
    buzzAlert(3);
    delay(800);
  }
}

/*
 * ─────────────────────────────────────────────────────────────────────────────
 *  WIRING (based on your ESP32 schematic):
 *
 *    MCP2515 CS   ─── ESP32 IO5   (SPI Chip Select)
 *    MCP2515 INT  ─── ESP32 IO4   (Interrupt)
 *    MCP2515 SCK  ─── ESP32 IO18  (SPI Clock)
 *    MCP2515 MOSI ─── ESP32 IO23  (SPI Master Out)
 *    MCP2515 MISO ─── ESP32 IO19  (SPI Master In)
 *    SN65HVD230 CANH ─── OBD-II Pin 6  (CAN High)
 *    SN65HVD230 CANL ─── OBD-II Pin 14 (CAN Low)
 *    Buzzer (+)   ─── IO2 ─── 1kΩ ─── 2N2222 Base ─── GND
 *    12V OBD ─── LM2596S-5.0 ─── 5V ─── AMS1117-3.3 ─── 3.3V (ESP32 + MCP2515)
 *
 *  UPLOAD STEPS IN ARDUINO IDE:
 *    1. Tools > Board > "ESP32 Dev Module"
 *    2. Tools > Upload Speed > 921600
 *    3. Select COM port (check Device Manager)
 *    4. Click Upload
 *    5. Open Serial Monitor at 115200 baud
 *    6. You should see "[BLE] Advertising as 'VETRI-OBD'"
 *    7. Open VETRI app > BLE Pairing > Scan > Tap "VETRI-OBD" > Connect
 *    8. Dashboard will show live readings immediately
 *
 *  CAN SPEED REFERENCE:
 *    Most modern bikes/cars (post-2008) : CAN_500KBPS
 *    Older vehicles / some 2-wheelers   : CAN_125KBPS  (change line above)
 * ─────────────────────────────────────────────────────────────────────────────
 */
