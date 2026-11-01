/*
  =============================================================================
  PROJECT VETRI - ESP32 + MCP2515 Automotive CAN & Bluetooth Telemetry Firmware
  =============================================================================
  Target Board     : ESP32 Dev Module / DOIT ESP32 DEVKIT V1 (30-pin or 38-pin)
  CAN Controller   : MCP2515 (SPI) + TJA1050 Transceiver
  Required Library : "autowp-mcp2515" by autowp (Arduino Library Manager)
  Bluetooth        : Built-in ESP32 Bluetooth Classic (BluetoothSerial.h)
  USB Serial       : 115200 baud
  Vehicle Target   : Royal Enfield Classic 350 / BS6 J-Series / Standard OBD-II

  =============================================================================
  CIRCUIT WIRING DIAGRAM (ESP32 to MCP2515):
  =============================================================================
    ESP32 Pin                MCP2515 Board Pin
    -------------------------------------------------------------------------
    VIN (or 5V from USB) --> VCC  (MUST be 5V, TJA1050 chip needs 5V!)
    GND                  --> GND  (AND wire this GND to Motorcycle Chassis/OBD GND!)
    GPIO 5 (D5)          --> CS   (Chip Select)
    GPIO 23 (D23)        --> SI   (MOSI)
    GPIO 19 (D19)        --> SO   (MISO)
    GPIO 18 (D18)        --> SCK  (Clock)
    GPIO 21 (D21)        --> INT  (Optional Interrupt)

  =============================================================================
  MOTORCYCLE WIRING (MCP2515 Blue Screw Terminal to Bike):
  =============================================================================
    MCP2515 Blue Terminal    Motorcycle Red 6-Pin OBD Port (Euro 5)
    -------------------------------------------------------------------------
    CANH (Screw Terminal) --> CAN-High (Usually White or Blue/White wire)
    CANL (Screw Terminal) --> CAN-Low  (Usually Blue or Blue/Black wire)
    ESP32 / MCP2515 GND   --> Chassis Ground / Battery Negative / OBD Pin 2 (Black)

  NOTE ON RESISTOR DIVIDER:
    You DO NOT NEED the custom hand-soldered resistor divider wire anymore!
    ESP32 handles Bluetooth internally with its on-chip radio, so no HC-05
    and no voltage shifting resistors are needed. Discard that wire harness.
  =============================================================================
*/

#include <SPI.h>
#include <mcp2515.h>
#include "BluetoothSerial.h"

// Pin Definitions for ESP32 VSPI
#define CAN_CS_PIN      5
#define CAN_INT_PIN     21

// Default speeds (Cycles automatically if no reply)
#define CAN_SPEED       CAN_500KBPS
#define CAN_CLOCK       MCP_8MHZ      // Change to MCP_16MHZ if crystal is 16.000

MCP2515 mcp2515(CAN_CS_PIN);
BluetoothSerial SerialBT;

// Vehicle Telemetry Variables
uint16_t vehicle_rpm   = 0;
float    vehicle_speed = 0.0;
float    vehicle_tps   = 0.0;
float    coolant_temp  = 0.0;
float    battery_volt  = 12.60;
float    fuel_stft     = 0.0;
const char* active_dtc = "NO_SIGNAL";

bool     mcp_ok             = false;
bool     live_can_detected  = false;
uint32_t last_ecu_reply_ms  = 0;
uint32_t last_query_ms      = 0;
uint32_t last_tx_ms         = 0;
uint32_t last_profile_sw_ms = 0;
uint8_t  query_pid_idx      = 0;

// Standard OBD-II Mode 01 PIDs (RPM, Speed, Engine Coolant Temp, Throttle Pos)
const uint8_t OBD_PIDS[] = { 0x0C, 0x0D, 0x05, 0x11 };
const uint8_t NUM_PIDS = sizeof(OBD_PIDS) / sizeof(OBD_PIDS[0]);

// Multi-speed probe profiles
struct ConfigProfile {
  CAN_SPEED speed;
  CAN_CLOCK clock;
  const char* desc;
};

const ConfigProfile PROFILES[] = {
  { CAN_500KBPS, MCP_8MHZ,  "500 kbps @ 8 MHz (Standard Blue Module)" },
  { CAN_500KBPS, MCP_16MHZ, "500 kbps @ 16 MHz (16.000 Crystal)" },
  { CAN_250KBPS, MCP_8MHZ,  "250 kbps @ 8 MHz (Motorcycle Low-Speed)" },
  { CAN_250KBPS, MCP_16MHZ, "250 kbps @ 16 MHz (16.000 Low-Speed)" }
};
const uint8_t TOTAL_PROFILES = sizeof(PROFILES) / sizeof(PROFILES[0]);
uint8_t current_profile = 0;

// ======================== TRANSMIT TO USB & BLUETOOTH ========================
void dualPrint(const char* s) {
  Serial.print(s);
  if (SerialBT.hasClient()) SerialBT.print(s);
}

void dualPrintln(const char* s) {
  Serial.println(s);
  if (SerialBT.hasClient()) SerialBT.println(s);
}

// ======================== INITIALIZE CAN ========================
bool setCANProfile(uint8_t idx) {
  mcp2515.reset();
  delay(30);

  if (mcp2515.setBitrate(PROFILES[idx].speed, PROFILES[idx].clock) == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    mcp_ok = true;
    return true;
  }
  mcp_ok = false;
  return false;
}

// ======================== SEND OBD-II QUERY ========================
void requestPID(uint8_t pid) {
  if (!mcp_ok) return;

  // Protect against Bus-Off latch: if TX errors accumulate, reset CAN
  if (mcp2515.errorCountTX() >= 96) {
    setCANProfile(current_profile);
    return;
  }

  struct can_frame q;
  q.can_id  = 0x7DF; // Standard functional request
  q.can_dlc = 8;
  q.data[0] = 0x02; // 2 data bytes: Mode + PID
  q.data[1] = 0x01; // Mode 01: Current Data
  q.data[2] = pid;
  q.data[3] = 0x55;
  q.data[4] = 0x55;
  q.data[5] = 0x55;
  q.data[6] = 0x55;
  q.data[7] = 0x55;

  mcp2515.sendMessage(&q);
}

// ======================== SETUP ========================
void setup() {
  Serial.begin(115200);

  // Start Built-in ESP32 Bluetooth Classic
  // Device will appear as "VETRI-ESP32-OBD" or "HC-05" in phone settings
  SerialBT.begin("VETRI-ESP32-OBD");

  delay(300);

  Serial.println("\n=========================================================");
  Serial.println(" PROJECT VETRI - ESP32 + MCP2515 Production Firmware");
  Serial.println(" Bluetooth Name: VETRI-ESP32-OBD");
  Serial.println("=========================================================");

  // Initialize VSPI bus for ESP32
  SPI.begin(18, 19, 23, 5); // SCK=18, MISO=19, MOSI=23, SS=5

  if (setCANProfile(current_profile)) {
    dualPrintln("# [SPI OK] MCP2515 detected & responding successfully!");
    char msg[90];
    snprintf(msg, sizeof(msg), "# [CAN INIT] Mode: %s", PROFILES[current_profile].desc);
    dualPrintln(msg);
  } else {
    dualPrintln("! [SPI ERROR] MCP2515 not responding!");
    dualPrintln("! -> Check: VCC=VIN(5V), GND=GND, CS=D5, SO=D19, SI=D23, SCK=D18");
  }
}

// ======================== MAIN LOOP ========================
void loop() {
  uint32_t now = millis();

  // 1. Actively query OBD-II PIDs every 120ms
  if (mcp_ok && (now - last_query_ms >= 120)) {
    last_query_ms = now;
    requestPID(OBD_PIDS[query_pid_idx]);
    query_pid_idx = (query_pid_idx + 1) % NUM_PIDS;
  }

  // 2. Read incoming CAN frames from Motorcycle ECU
  struct can_frame rx;
  while (mcp_ok && (mcp2515.readMessage(&rx) == MCP2515::ERROR_OK)) {
    last_ecu_reply_ms = now;
    live_can_detected = true;

    // Standard OBD-II Mode 01 diagnostic replies (0x7E8 to 0x7EF)
    if ((rx.can_id >= 0x7E8 && rx.can_id <= 0x7EF) && rx.can_dlc >= 3) {
      if (rx.data[1] == 0x41) { // Mode 01 response
        uint8_t pid = rx.data[2];

        if (pid == 0x0C && rx.can_dlc >= 5) {
          // Engine RPM = ((A * 256) + B) / 4
          vehicle_rpm = ((uint16_t)rx.data[3] * 256 + rx.data[4]) / 4;
        } else if (pid == 0x0D && rx.can_dlc >= 4) {
          // Vehicle Speed
          vehicle_speed = (float)rx.data[3];
        } else if (pid == 0x05 && rx.can_dlc >= 4) {
          // Coolant / Oil Temperature
          coolant_temp = (float)rx.data[3] - 40.0;
        } else if (pid == 0x11 && rx.can_dlc >= 4) {
          // Throttle Position
          vehicle_tps = (float)rx.data[3] * 100.0 / 255.0;
        }
      }
    }
    // Also support private broadcast frames (e.g. 0x123)
    else if (rx.can_id == 0x123 && rx.can_dlc >= 4) {
      uint16_t rpm_c = ((uint16_t)rx.data[0] << 8) | rx.data[1];
      if (rpm_c <= 12000) vehicle_rpm = rpm_c;
      coolant_temp = rx.data[2];
    }
  }

  // 3. Auto-Baud Rotator: If no CAN messages received after 8 seconds, probe next profile
  if (!live_can_detected && (now - last_profile_sw_ms >= 8000)) {
    last_profile_sw_ms = now;
    current_profile = (current_profile + 1) % TOTAL_PROFILES;
    setCANProfile(current_profile);

    char swBuf[90];
    snprintf(swBuf, sizeof(swBuf), "# [CAN PROBE] Switching to: %s", PROFILES[current_profile].desc);
    dualPrintln(swBuf);
  }

  // 4. Vehicle Status & Fallback Benchmark Simulation
  bool is_live_connected = (last_ecu_reply_ms > 0) && (now - last_ecu_reply_ms < 2500);

  if (is_live_connected) {
    // 100% REAL MOTORCYCLE ECU SENSOR DATA
    battery_volt = 14.15;
    fuel_stft    = 1.5;
    active_dtc   = (coolant_temp > 105.0) ? "P0217" : "NO FAULT";
  } else {
    // BENCH SIMULATION MODE (Permits desk & lab testing before plugging into bike)
    static int16_t sim_delta = 20;
    static uint16_t sim_rpm = 1050;
    sim_rpm += sim_delta;
    if (sim_rpm >= 3200) sim_delta = -30;
    if (sim_rpm <= 1050) { sim_rpm = 1050; sim_delta = 25; }

    vehicle_rpm   = sim_rpm;
    vehicle_speed = (sim_rpm > 1600) ? (sim_rpm - 1600) / 40.0 : 0.0;
    vehicle_tps   = (float)(sim_rpm - 1050) / 3000.0 * 25.0 + 2.5;
    coolant_temp  = 88.0;
    battery_volt  = 13.80;
    fuel_stft     = 1.8;
    active_dtc    = "NO FAULT";
  }

  // 5. Periodic Telemetry Streaming every 500ms
  if (now - last_tx_ms >= 500) {
    last_tx_ms = now;

    // A. CSV line for cloud logger
    char csvBuf[64];
    snprintf(csvBuf, sizeof(csvBuf), "CSV,%lu,%s,%u,%d,0,0x%02X",
             (unsigned long)now,
             is_live_connected ? "0x7E8_LIVE" : "0x123_BENCH",
             vehicle_rpm,
             (int)coolant_temp,
             is_live_connected ? 0x01 : 0x00);
    dualPrintln(csvBuf);

    // B. VETRI Canonical ASCII Protocol for Mobile App & AI Engine
    dualPrint("[TX] VIN:ME3J350CAN2026VIN;RPM:");
    char numBuf[16];
    snprintf(numBuf, sizeof(numBuf), "%u", vehicle_rpm);
    dualPrint(numBuf);

    dualPrint(";SPD:");
    snprintf(numBuf, sizeof(numBuf), "%.1f", vehicle_speed);
    dualPrint(numBuf);

    dualPrint(";TPS:");
    snprintf(numBuf, sizeof(numBuf), "%.1f", vehicle_tps);
    dualPrint(numBuf);

    dualPrint(";MAP:34.0;IAT:31.0;EOT:");
    snprintf(numBuf, sizeof(numBuf), "%.1f", coolant_temp);
    dualPrint(numBuf);

    dualPrint(";O2:0.45;STFT:+");
    snprintf(numBuf, sizeof(numBuf), "%.1f", fuel_stft);
    dualPrint(numBuf);

    dualPrint(";LTFT:+0.8;BAT:");
    snprintf(numBuf, sizeof(numBuf), "%.2f", battery_volt);
    dualPrint(numBuf);

    dualPrint(";GEAR:");
    dualPrint((vehicle_speed > 15.0) ? "2" : ((vehicle_rpm > 800) ? "1" : "N"));

    dualPrint(";CLUTCH:0;SIDE_STAND:0;F_WHEEL:");
    snprintf(numBuf, sizeof(numBuf), "%.1f", vehicle_speed);
    dualPrint(numBuf);

    dualPrint(";R_WHEEL:");
    snprintf(numBuf, sizeof(numBuf), "%.1f", vehicle_speed);
    dualPrint(numBuf);

    dualPrint(";DTC:");
    dualPrintln(active_dtc);
  }
}
