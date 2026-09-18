/*
 * ================================================================
 *  VETRI-OBD — ESP32 BLE NUS Firmware
 *  Royal Enfield Classic 350 (J-Series) CAN Bus Reader
 *  Protocol: BLE Nordic UART Service (NUS) — works with FlutterBluePlus
 * ================================================================
 *
 *  WIRING (SN65HVD230 / VP230 transceiver board):
 *    ESP32 GPIO4  → SN65HVD230 RXD  (pin 1)
 *    ESP32 GPIO5  → SN65HVD230 TXD  (pin 4)
 *    ESP32 3.3V   → SN65HVD230 VCC  (pin 3)
 *    ESP32 GND    → SN65HVD230 GND  (pin 2)
 *    SN65HVD230 Rs (pin 8) → GND  ← CRITICAL! Must be 0V for high-speed mode
 *    SN65HVD230 CANH (pin 7) → Bike CAN-H wire (usually gray)
 *    SN65HVD230 CANL (pin 6) → Bike CAN-L wire (usually green)
 *    120Ω resistor across CANH and CANL on your board
 *
 *  REQUIRED ARDUINO LIBRARIES (Install via Library Manager):
 *    - NimBLE-Arduino (by h2zero) — version 1.4.x or later
 *      Library Manager search: "NimBLE-Arduino"
 *    - ESP32 Arduino core built-in: driver/twai.h
 *
 *  BOARD SETTING: ESP32 Dev Module, 240MHz, 4MB Flash
 * ================================================================
 */

#include <Arduino.h>
#include <NimBLEDevice.h>
#include <NimBLEServer.h>
#include <NimBLEUtils.h>
#include "driver/twai.h"

// ---- CAN Bus Pin Assignment ----
#define CAN_RX_PIN  GPIO_NUM_4   // SN65HVD230 RXD pin
#define CAN_TX_PIN  GPIO_NUM_5   // SN65HVD230 TXD pin

// ---- BLE Nordic UART Service (NUS) UUIDs ----
// These are industry-standard UUIDs — same as what FlutterBluePlus expects
#define NUS_SERVICE_UUID  "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_TX_UUID       "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"  // ESP32 → Phone
#define NUS_RX_UUID       "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"  // Phone → ESP32

// ---- BLE Globals ----
NimBLEServer*         pServer         = nullptr;
NimBLECharacteristic* pTxCharacteristic = nullptr;  // ESP32 sends on this
NimBLECharacteristic* pRxCharacteristic = nullptr;  // ESP32 receives on this
bool                  bleConnected    = false;

// ---- Live Vehicle Data (15 Parameters) ----
int    rpm           = 1050;
float  speedKmH      = 0.0f;
float  tps           = 2.1f;    // Throttle Position %
float  mapKpa        = 34.0f;   // Manifold Absolute Pressure kPa
float  iat           = 31.0f;   // Intake Air Temperature °C
float  eot           = 88.0f;   // Engine Oil/Coolant Temp °C
float  o2Voltage     = 0.35f;   // O2 sensor voltage
float  stft          = 2.4f;    // Short Term Fuel Trim %
float  ltft          = 1.8f;    // Long Term Fuel Trim %
float  battVoltage   = 14.10f;
String gear          = "N";
int    clutch        = 0;       // 0 = engaged, 1 = pulled
int    sideStand     = 0;       // 0 = up, 1 = down
float  fWheel        = 0.0f;
float  rWheel        = 0.0f;

// ---- CAN State ----
bool   canReady          = false;
bool   ecuResponding     = false;    // true once we see real ECU frames
unsigned long lastQuery  = 0;
unsigned long lastTx     = 0;

// ---- O2 Switching Simulation (for bench testing without CAN) ----
bool   o2Rich            = false;
unsigned long o2Timer    = 0;

// ================================================================
//  BLE Callbacks — connection/disconnection events
// ================================================================
class VetriServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* pSvr, ble_gap_conn_desc* desc) override {
    bleConnected = true;
    Serial.println("[BLE] Phone connected: " + String(NimBLEAddress(desc->peer_ota_addr).toString().c_str()));
    // Reduce connection interval for faster throughput (7.5ms min)
    pSvr->updateConnParams(desc->conn_handle, 6, 12, 0, 400);
  }

  void onDisconnect(NimBLEServer* pSvr) override {
    bleConnected = false;
    Serial.println("[BLE] Phone disconnected. Advertising again...");
    NimBLEDevice::startAdvertising();
  }
};

// Callback for data received FROM phone (commands)
class VetriRxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pChar) override {
    std::string rxVal = pChar->getValue();
    if (!rxVal.empty()) {
      String cmd = String(rxVal.c_str());
      cmd.trim();
      Serial.println("[BLE CMD] Received: " + cmd);
    }
  }
};

// ================================================================
//  CAN Bus Setup
// ================================================================
bool initCan() {
  twai_general_config_t g_cfg = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  twai_timing_config_t t_cfg  = TWAI_TIMING_CONFIG_500KBITS();  // RE Classic 350 = 500 kbps
  twai_filter_config_t f_cfg  = TWAI_FILTER_CONFIG_ACCEPT_ALL();

  if (twai_driver_install(&g_cfg, &t_cfg, &f_cfg) != ESP_OK) {
    Serial.println("[CAN] ❌ Driver install FAILED");
    return false;
  }
  if (twai_start() != ESP_OK) {
    Serial.println("[CAN] ❌ Bus start FAILED — check wiring (Rs pin = GND?)");
    twai_driver_uninstall();
    return false;
  }
  Serial.println("[CAN] ✅ 500kbps bus active");
  return true;
}

// ================================================================
//  OBD-II PID Query Sender
// ================================================================
void sendObdQuery(uint32_t arbId, uint8_t pid) {
  twai_message_t q;
  q.identifier       = arbId;
  q.extd             = 0;
  q.rtr              = 0;
  q.data_length_code = 8;
  q.data[0] = 0x02; q.data[1] = 0x01; q.data[2] = pid;
  for (int i = 3; i < 8; i++) q.data[i] = 0xAA;
  twai_transmit(&q, pdMS_TO_TICKS(20));
}

// ================================================================
//  CAN Frame Decoder — Royal Enfield J-Series
// ================================================================
void decodeCanFrame(const twai_message_t& msg) {
  uint32_t id = msg.identifier;

  // --- OBD-II Diagnostic Response (ECU replies to our queries) ---
  if (id >= 0x7E8 && id <= 0x7EF) {
    if (msg.data_length_code >= 4 && msg.data[1] == 0x41) {
      ecuResponding = true;
      uint8_t pid = msg.data[2];
      switch (pid) {
        case 0x0C:  // RPM = (A*256 + B) / 4
          rpm = ((msg.data[3] * 256) + msg.data[4]) / 4;
          break;
        case 0x0D:  // Vehicle speed km/h
          speedKmH = (float)msg.data[3];
          break;
        case 0x05:  // Engine coolant temp = A - 40
          eot = (float)msg.data[3] - 40.0f;
          break;
        case 0x11:  // Throttle position = A * 100 / 255
          tps = ((float)msg.data[3] * 100.0f) / 255.0f;
          break;
        case 0x0B:  // MAP sensor kPa
          mapKpa = (float)msg.data[3];
          break;
        case 0x0F:  // Intake air temp = A - 40
          iat = (float)msg.data[3] - 40.0f;
          break;
        case 0x06:  // Short term fuel trim = (A - 128) * 100 / 128
          stft = ((float)msg.data[3] - 128.0f) * 100.0f / 128.0f;
          break;
        case 0x07:  // Long term fuel trim
          ltft = ((float)msg.data[3] - 128.0f) * 100.0f / 128.0f;
          break;
        case 0x42:  // Control module voltage (V = (A*256+B) / 1000)
          battVoltage = ((msg.data[3] * 256) + msg.data[4]) / 1000.0f;
          break;
        case 0x14:  // O2 sensor voltage (Bank1, Sensor1) = A * 0.005
        case 0x15:
          o2Voltage = (float)msg.data[3] * 0.005f;
          break;
      }
    }
  }

  // --- Royal Enfield Native Broadcast Frames (No query needed) ---
  else if (id == 0x201 || id == 0x280) {
    ecuResponding = true;
    int rawRpm = ((msg.data[0] * 256) + msg.data[1]);
    if (rawRpm > 0 && rawRpm < 44000) {
      rpm = rawRpm / 4;
    }
    tps = ((float)msg.data[2] * 100.0f) / 255.0f;
  }
  else if (id == 0x380) {
    float rawSpd = ((msg.data[0] * 256) + msg.data[1]) / 10.0f;
    if (rawSpd >= 0 && rawSpd < 250) speedKmH = rawSpd;
  }
  else if (id == 0x480) {
    float rawV = ((msg.data[0] * 256) + msg.data[1]) / 100.0f;
    if (rawV > 8.0f && rawV < 18.0f) battVoltage = rawV;
  }
  else if (!ecuResponding) {
    Serial.printf("[CAN RAW] ID=0x%03X DLC=%d | %02X %02X %02X %02X %02X %02X %02X %02X\n",
      id, msg.data_length_code,
      msg.data[0], msg.data[1], msg.data[2], msg.data[3],
      msg.data[4], msg.data[5], msg.data[6], msg.data[7]);
  }
}

// ================================================================
//  BLE Transmit Helper — sends text to phone in chunks
// ================================================================
void bleSend(const String& text) {
  if (!bleConnected || !pTxCharacteristic) return;
  const int CHUNK = 128;
  for (int i = 0; i < (int)text.length(); i += CHUNK) {
    String chunk = text.substring(i, min(i + CHUNK, (int)text.length()));
    pTxCharacteristic->setValue((uint8_t*)chunk.c_str(), chunk.length());
    pTxCharacteristic->notify();
    delay(10);
  }
}

// ================================================================
//  Build 15-Parameter VETRI Packet String
// ================================================================
String buildVetriPacket() {
  String dtc = "NO FAULT";
  if (eot > 110.0f)    dtc = "P0217";
  if (stft > 18.0f)    dtc = "P0171";
  if (battVoltage < 11.5f) dtc = "P0562";

  String pkt = "";
  pkt += "VIN:ME3J350CAN2026VIN;";
  pkt += "RPM:" + String(rpm) + ";";
  pkt += "SPD:" + String(speedKmH, 1) + ";";
  pkt += "TPS:" + String(tps, 1) + ";";
  pkt += "MAP:" + String(mapKpa, 1) + ";";
  pkt += "IAT:" + String(iat, 1) + ";";
  pkt += "EOT:" + String(eot, 1) + ";";
  pkt += "O2:" + String(o2Voltage, 2) + ";";
  pkt += "STFT:" + (stft >= 0 ? String("+") : String("")) + String(stft, 1) + ";";
  pkt += "LTFT:" + (ltft >= 0 ? String("+") : String("")) + String(ltft, 1) + ";";
  pkt += "BAT:" + String(battVoltage, 2) + ";";
  pkt += "GEAR:" + gear + ";";
  pkt += "CLUTCH:" + String(clutch) + ";";
  pkt += "SIDE_STAND:" + String(sideStand) + ";";
  pkt += "F_WHEEL:" + String(fWheel, 1) + ";";
  pkt += "R_WHEEL:" + String(rWheel, 1) + ";";
  pkt += "DTC:" + dtc;
  return pkt;
}

// ================================================================
//  Idle Simulation (fallback for bench testing when CAN unplugged)
// ================================================================
void runIdleSimulation() {
  rpm        = 1050 + (rand() % 15);
  speedKmH   = 0.0f;
  tps        = 2.1f;
  mapKpa     = 34.0f;
  iat        = 31.0f;
  eot        = 87.8f + ((rand() % 4) / 10.0f);
  stft       = 2.1f + ((rand() % 6 - 3) / 10.0f);
  ltft       = 1.8f;
  battVoltage = 14.07f + ((rand() % 6) / 100.0f);
  gear       = "N";
  fWheel     = 0.0f;
  rWheel     = 0.0f;

  if (millis() - o2Timer >= 1200) {
    o2Timer = millis();
    o2Rich = !o2Rich;
  }
  o2Voltage = o2Rich ? (0.72f + (rand() % 13) / 100.0f) : (0.22f + (rand() % 15) / 100.0f);
}

// ================================================================
//  SETUP
// ================================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n========================================");
  Serial.println(" VETRI-OBD BLE NUS Firmware v2.0");
  Serial.println(" Royal Enfield Classic 350");
  Serial.println("========================================\n");

  canReady = initCan();
  if (!canReady) {
    Serial.println("[CAN] Running in simulation fallback mode.");
  }

  NimBLEDevice::init("VETRI-OBD");
  NimBLEDevice::setMTU(512);

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new VetriServerCallbacks());

  NimBLEService* pService = pServer->createService(NUS_SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    NUS_TX_UUID,
    NIMBLE_PROPERTY::NOTIFY
  );

  pRxCharacteristic = pService->createCharacteristic(
    NUS_RX_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
  );
  pRxCharacteristic->setCallbacks(new VetriRxCallbacks());

  pService->start();

  NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
  pAdv->addServiceUUID(NUS_SERVICE_UUID);
  pAdv->setScanResponse(true);
  pAdv->start();

  Serial.println("[BLE] ✅ Advertising as 'VETRI-OBD'");
  Serial.println("[BLE] Service UUID: " NUS_SERVICE_UUID);
  Serial.println("[BLE] Waiting for phone connection...\n");
}

// ================================================================
//  LOOP
// ================================================================
void loop() {
  unsigned long now = millis();

  // 1. Drain incoming CAN frames
  if (canReady) {
    twai_message_t rxMsg;
    int rxCount = 0;
    while (twai_receive(&rxMsg, pdMS_TO_TICKS(2)) == ESP_OK && rxCount < 20) {
      decodeCanFrame(rxMsg);
      rxCount++;
    }
  }

  // 2. Query OBD-II PIDs every 250ms if active
  static int queryRound = 0;
  if (canReady && !ecuResponding && now - lastQuery >= 250) {
    lastQuery = now;
    switch (queryRound % 6) {
      case 0: sendObdQuery(0x7DF, 0x0C); break;
      case 1: sendObdQuery(0x7DF, 0x0D); break;
      case 2: sendObdQuery(0x7DF, 0x11); break;
      case 3: sendObdQuery(0x7DF, 0x05); break;
      case 4: sendObdQuery(0x7DF, 0x0B); break;
      case 5: sendObdQuery(0x7DF, 0x42); break;
    }
    queryRound++;
  }

  // 3. Bench testing simulation if ECU not connected
  if (!ecuResponding) {
    runIdleSimulation();
  }

  // 4. Emit packet every 500ms
  if (now - lastTx >= 500) {
    lastTx = now;
    String packet = buildVetriPacket();

    Serial.println("[TX] " + packet);

    if (bleConnected) {
      bleSend(packet + "\n");
    }
  }
}
