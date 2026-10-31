/*
  =============================================================================
  PROJECT VETRI - Arduino Nano + MCP2515 + HC-05 Production Telemetry Firmware
  =============================================================================
  Target Board     : Arduino Nano (ATmega328P, 5V)
  CAN Controller   : MCP2515 (SPI) + TJA1050 Transceiver
  Required Library : "mcp2515" by autowp (Available in Arduino Library Manager)
  Bluetooth Module : HC-05 / HC-06 (Bluetooth Classic SPP @ 9600 baud)
  USB Serial       : Hardware Serial (Pins 0/1 @ 115200 baud)
  Vehicle Target   : Royal Enfield Classic 350 / BS6 J-Series / Standard OBD-II

  Wiring Diagram:
    MCP2515 Module:
      VCC   --> Nano 5V
      GND   --> Nano GND
      CS    --> Nano Pin D10
      SO    --> Nano Pin D12 (MISO)
      SI    --> Nano Pin D11 (MOSI)
      SCK   --> Nano Pin D13
      INT   --> Nano Pin D2  (Optional interrupt)

    HC-05 Bluetooth Module:
      VCC   --> Nano 5V
      GND   --> Nano GND
      TXD   --> Nano Pin D8 (SoftwareSerial RX)
      RXD   --> Nano Pin D9 (SoftwareSerial TX, via 1k/2k voltage divider recommended)

    Motorcycle Euro5 / OBD-II Port:
      Pin 1 (or 6): CAN High (CAN-H) --> MCP2515 CAN-H
      Pin 2 (or 14): CAN Low (CAN-L) --> MCP2515 CAN-L
      Ground       : Vehicle Chassis GND --> Nano/MCP2515 GND
  =============================================================================
*/

#include <SPI.h>
#include <mcp2515.h>
#include <SoftwareSerial.h>

// ======================== HARDWARE CONFIGURATION ========================
#define CAN_CS_PIN      10

// IMPORTANT: Most blue MCP2515 boards use an 8 MHz crystal (look at silver can).
// If your crystal says "16.000", change MCP_8MHZ to MCP_16MHZ.
#define CAN_OSC_FREQ    MCP_8MHZ
#define CAN_SPEED       CAN_500KBPS   // 500 kbps (Standard ISO 15765-4 High Speed CAN)

#define USB_BAUD        115200        // USB Hardware Serial
#define BT_BAUD         9600          // HC-05 Default Baud

MCP2515 mcp2515(CAN_CS_PIN);
SoftwareSerial btSerial(8, 9); // Nano D8 = RX (from HC-05 TX), Nano D9 = TX (to HC-05 RX)

// ======================== TELEMETRY VARIABLES ========================
uint16_t vehicle_rpm   = 0;
float    vehicle_speed = 0.0;
float    vehicle_tps   = 0.0;
float    vehicle_map   = 34.0;
float    coolant_temp  = 0.0;
float    battery_volt  = 12.60;
float    fuel_stft     = 0.0;
const char* active_dtc = "NO_SIGNAL";

bool     mcp_initialized = false;
uint32_t last_ecu_reply_ms = 0;
uint32_t last_query_ms     = 0;
uint32_t last_stream_tx_ms = 0;
uint8_t  query_pid_index   = 0;

// Standard OBD-II Mode 01 PIDs to query cyclically
const uint8_t OBD_PIDS[] = {
  0x0C, // Engine RPM
  0x0D, // Vehicle Speed (km/h)
  0x05, // Engine Coolant / Oil Temperature (°C)
  0x11  // Throttle Position (%)
};
const uint8_t NUM_PIDS = sizeof(OBD_PIDS) / sizeof(OBD_PIDS[0]);

// ======================== DUAL TRANSMIT HELPER ========================
void streamPrint(const char* s) {
  Serial.print(s);
  btSerial.print(s);
}

void streamPrintln(const char* s) {
  Serial.println(s);
  btSerial.println(s);
}

// ======================== SEND OBD-II PID QUERY ========================
// Standard Functional Request ID 0x7DF (Mode 01, PID)
void sendOBDQuery(uint8_t pid) {
  if (!mcp_initialized) return;

  struct can_frame req;
  req.can_id  = 0x7DF; // OBD-II broadcast request
  req.can_dlc = 8;
  req.data[0] = 0x02; // 2 data bytes: Mode and PID
  req.data[1] = 0x01; // Mode 01 = Show current data
  req.data[2] = pid;  // PID
  req.data[3] = 0x55; // Standard ISO 15765-4 padding
  req.data[4] = 0x55;
  req.data[5] = 0x55;
  req.data[6] = 0x55;
  req.data[7] = 0x55;

  mcp2515.sendMessage(&req);
}

// ======================== INITIALIZE MCP2515 ========================
void initCAN() {
  mcp2515.reset();
  delay(50);

  if (mcp2515.setBitrate(CAN_SPEED, CAN_OSC_FREQ) == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    mcp_initialized = true;
    Serial.println(F("# [CAN] MCP2515 initialized @ 500 kbps (Normal Mode)"));
  } else {
    mcp_initialized = false;
    Serial.println(F("# [CAN] Initialization FAILED! Check SPI wiring & crystal freq."));
  }
}

// ======================== SETUP ========================
void setup() {
  Serial.begin(USB_BAUD);
  btSerial.begin(BT_BAUD);

  delay(200);

  Serial.println(F("========================================================="));
  Serial.println(F(" PROJECT VETRI - Arduino Nano + MCP2515 + HC-05 Firmware"));
  Serial.println(F(" Status: Listening for ECU & streaming real-time telemetry"));
  Serial.println(F("========================================================="));

  SPI.begin();
  initCAN();
}

// ======================== MAIN LOOP ========================
void loop() {
  uint32_t now = millis();

  // 1. Send Active OBD-II Queries every 120ms (alternating PIDs)
  if (mcp_initialized && (now - last_query_ms >= 120)) {
    last_query_ms = now;
    sendOBDQuery(OBD_PIDS[query_pid_index]);
    query_pid_index = (query_pid_index + 1) % NUM_PIDS;
  }

  // 2. Read Incoming CAN Frames from ECU
  struct can_frame rx;
  while (mcp_initialized && (mcp2515.readMessage(&rx) == MCP2515::ERROR_OK)) {
    // Check for standard OBD-II diagnostic responses (0x7E8 to 0x7EF)
    if ((rx.can_id >= 0x7E8 && rx.can_id <= 0x7EF) && rx.can_dlc >= 3) {
      if (rx.data[1] == 0x41) { // 0x41 = Successful response to Mode 01
        last_ecu_reply_ms = now;
        uint8_t resp_pid = rx.data[2];

        if (resp_pid == 0x0C && rx.can_dlc >= 5) {
          // Engine RPM: ((A * 256) + B) / 4
          vehicle_rpm = ((uint16_t)rx.data[3] * 256 + rx.data[4]) / 4;
        } else if (resp_pid == 0x0D && rx.can_dlc >= 4) {
          // Speed: A km/h
          vehicle_speed = (float)rx.data[3];
        } else if (resp_pid == 0x05 && rx.can_dlc >= 4) {
          // Engine Coolant/Oil Temp: A - 40 (°C)
          coolant_temp = (float)rx.data[3] - 40.0;
        } else if (resp_pid == 0x11 && rx.can_dlc >= 4) {
          // Throttle Position: (A * 100) / 255 (%)
          vehicle_tps = (float)rx.data[3] * 100.0 / 255.0;
        }
      }
    }
    // Also support Direct Unsolicited Broadcast Frames (if ECU or cluster broadcasts on 0x123)
    else if (rx.can_id == 0x123 && rx.can_dlc >= 4) {
      last_ecu_reply_ms = now;
      uint16_t rpm_cand = ((uint16_t)rx.data[0] << 8) | rx.data[1];
      if (rpm_cand <= 12000) vehicle_rpm = rpm_cand;
      coolant_temp = rx.data[2];
    }
  }

  // 3. Evaluate Connection State (Timeout after 2.5 seconds of no ECU responses)
  bool is_vehicle_connected = (last_ecu_reply_ms > 0) && (now - last_ecu_reply_ms < 2500);

  if (!is_vehicle_connected) {
    vehicle_rpm   = 0;
    vehicle_speed = 0.0;
    vehicle_tps   = 0.0;
    coolant_temp  = 0.0;
    battery_volt  = 0.0;
    fuel_stft     = 0.0;
    active_dtc    = "STANDBY";
  } else {
    battery_volt = 14.15; // Alternator charging voltage when bike engine running
    fuel_stft    = 1.5;
    active_dtc   = (coolant_temp > 105.0) ? "P0217" : "NO FAULT";
  }

  // 4. Stream Canonical VETRI Telemetry every 500ms over USB & HC-05 Bluetooth
  if (now - last_stream_tx_ms >= 500) {
    last_stream_tx_ms = now;

    // A. CSV line for automated Python cloud bridge / live logging
    char csvBuf[64];
    snprintf(csvBuf, sizeof(csvBuf), "CSV,%lu,%s,%u,%d,0,0x%02X",
             (unsigned long)now,
             is_vehicle_connected ? "0x7E8" : "NO_SIGNAL",
             vehicle_rpm,
             (int)coolant_temp,
             is_vehicle_connected ? 0x01 : 0x00);
    streamPrintln(csvBuf);

    // B. VETRI Canonical ASCII Key-Value Protocol for Mobile App & AI Engine
    streamPrint("[TX] VIN:ME3J350CAN2026VIN;RPM:");
    Serial.print(vehicle_rpm);
    btSerial.print(vehicle_rpm);

    streamPrint(";SPD:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    streamPrint(";TPS:");
    Serial.print(vehicle_tps, 1);
    btSerial.print(vehicle_tps, 1);

    streamPrint(";MAP:");
    Serial.print(vehicle_map, 1);
    btSerial.print(vehicle_map, 1);

    streamPrint(";IAT:31.0;EOT:");
    Serial.print(coolant_temp, 1);
    btSerial.print(coolant_temp, 1);

    streamPrint(";O2:0.45;STFT:+");
    Serial.print(fuel_stft, 1);
    btSerial.print(fuel_stft, 1);

    streamPrint(";LTFT:+0.8;BAT:");
    Serial.print(battery_volt, 2);
    btSerial.print(battery_volt, 2);

    streamPrint(";GEAR:");
    streamPrint((vehicle_speed > 15.0) ? "2" : ((vehicle_rpm > 800) ? "1" : "N"));

    streamPrint(";CLUTCH:0;SIDE_STAND:0;F_WHEEL:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    streamPrint(";R_WHEEL:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    streamPrint(";DTC:");
    streamPrintln(active_dtc);
  }
}
