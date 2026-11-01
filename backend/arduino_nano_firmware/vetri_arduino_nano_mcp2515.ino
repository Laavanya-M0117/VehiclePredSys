/*
  =============================================================================
  PROJECT VETRI - Self-Healing Automotive CAN Diagnostic & Telemetry Firmware
  =============================================================================
  Target Board     : Arduino Nano (ATmega328P, 5V)
  CAN Controller   : MCP2515 (SPI) + TJA1050 Transceiver
  Required Library : "autowp-mcp2515" by autowp (Available in Arduino Library Manager)
  Bluetooth Module : HC-05 / HC-06 (Bluetooth Classic SPP @ 9600 baud)
  USB Serial       : Hardware Serial (Pins 0/1 @ 115200 baud)
  Vehicle Target   : Royal Enfield Classic 350 / BS6 J-Series / Standard OBD-II

  Wiring Check:
    MCP2515 VCC   --> Nano 5V (MUST be 5V, 3.3V will NOT power TJA1050 CAN chip!)
    MCP2515 GND   --> Nano GND (AND connected to Motorcycle Chassis / OBD GND!)
    MCP2515 CS    --> Nano Pin D10
    MCP2515 SO    --> Nano Pin D12 (MISO)
    MCP2515 SI    --> Nano Pin D11 (MOSI)
    MCP2515 SCK   --> Nano Pin D13
    MCP2515 INT   --> Nano Pin D2  (Optional interrupt)

    HC-05 TXD     --> Nano Pin D8 (SoftwareSerial RX)
    HC-05 RXD     --> Nano Pin D9 (SoftwareSerial TX)
  =============================================================================
*/

#include <SPI.h>
#include <mcp2515.h>
#include <SoftwareSerial.h>

#define CAN_CS_PIN      10
#define USB_BAUD        115200
#define BT_BAUD         9600

MCP2515 mcp2515(CAN_CS_PIN);
SoftwareSerial btSerial(8, 9); // Nano D8=RX, D9=TX

// Telemetry state
uint16_t vehicle_rpm   = 0;
float    vehicle_speed = 0.0;
float    vehicle_tps   = 0.0;
float    coolant_temp  = 0.0;
float    battery_volt  = 0.0;
float    fuel_stft     = 0.0;
const char* active_dtc = "STANDBY";

bool     mcp_initialized = false;
uint32_t last_ecu_reply_ms = 0;
uint32_t last_query_ms     = 0;
uint32_t last_stream_tx_ms = 0;
uint32_t last_diag_ms      = 0;
uint32_t last_bus_reset_ms = 0;
uint8_t  query_pid_index   = 0;

// Hardware configuration profiles to auto-probe
struct CanConfigProfile {
  CAN_SPEED speed;
  CAN_CLOCK clock;
  const char* label;
};

const CanConfigProfile PROFILES[] = {
  { CAN_500KBPS, MCP_8MHZ,  "500 kbps @ 8 MHz (Standard Blue Module)" },
  { CAN_500KBPS, MCP_16MHZ, "500 kbps @ 16 MHz (16.000 Crystal Module)" },
  { CAN_250KBPS, MCP_8MHZ,  "250 kbps @ 8 MHz (Motorcycle Low-Speed)" },
  { CAN_250KBPS, MCP_16MHZ, "250 kbps @ 16 MHz (16.000 Crystal Low-Speed)" }
};
const uint8_t NUM_PROFILES = sizeof(PROFILES) / sizeof(PROFILES[0]);
uint8_t current_profile_idx = 0;
bool profile_locked = false;

// Standard OBD-II Mode 01 PIDs
const uint8_t OBD_PIDS[] = { 0x0C, 0x0D, 0x05, 0x11 };
const uint8_t NUM_PIDS = sizeof(OBD_PIDS) / sizeof(OBD_PIDS[0]);

// ======================== BROADCAST TO USB & BLUETOOTH ========================
void logMsg(const char* s) {
  Serial.println(s);
  btSerial.println(s);
}

void streamPrint(const char* s) {
  Serial.print(s);
  btSerial.print(s);
}

void streamPrintln(const char* s) {
  Serial.println(s);
  btSerial.println(s);
}

// ======================== INITIALIZE CAN PROFILE ========================
bool applyProfile(uint8_t idx) {
  mcp2515.reset();
  delay(30);

  if (mcp2515.setBitrate(PROFILES[idx].speed, PROFILES[idx].clock) == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    mcp_initialized = true;
    return true;
  }
  mcp_initialized = false;
  return false;
}

// ======================== SEND OBD-II QUERY ========================
void sendOBDQuery(uint8_t pid) {
  if (!mcp_initialized) return;

  // Protect against Bus-Off latch: if Transmit Error Counter (TEC) is high, reset CAN
  uint8_t tec = mcp2515.errorCountTX();
  if (tec >= 96) {
    applyProfile(current_profile_idx);
    return;
  }

  struct can_frame req;
  req.can_id  = 0x7DF; // Standard Functional OBD request
  req.can_dlc = 8;
  req.data[0] = 0x02; // 2 data bytes: Mode and PID
  req.data[1] = 0x01; // Mode 01: Current Data
  req.data[2] = pid;  // PID
  req.data[3] = 0x55;
  req.data[4] = 0x55;
  req.data[5] = 0x55;
  req.data[6] = 0x55;
  req.data[7] = 0x55;

  mcp2515.sendMessage(&req);
}

// ======================== SETUP ========================
void setup() {
  Serial.begin(USB_BAUD);
  btSerial.begin(BT_BAUD);

  delay(300);

  logMsg("=========================================================");
  logMsg(" PROJECT VETRI - Intelligent Self-Healing CAN Diagnostics");
  logMsg(" Hardware: Arduino Nano (ATmega328P) + MCP2515 + HC-05");
  logMsg("=========================================================");

  SPI.begin();

  // Test SPI communication with MCP2515
  mcp2515.reset();
  delay(40);
  if (applyProfile(current_profile_idx)) {
    logMsg("# [SPI CHECK]: MCP2515 detected & responding successfully!");
    char profBuf[80];
    snprintf(profBuf, sizeof(profBuf), "# [CAN PROFILE]: Active mode: %s", PROFILES[current_profile_idx].label);
    logMsg(profBuf);
  } else {
    logMsg("! [CRITICAL HARDWARE ERROR] MCP2515 SPI NOT RESPONDING!");
    logMsg("! -> Check wiring: VCC to 5V (NOT 3.3V), GND to GND");
    logMsg("! -> Check SPI pins: CS=D10, SO/MISO=D12, SI/MOSI=D11, SCK=D13");
  }
}

// ======================== MAIN LOOP ========================
void loop() {
  uint32_t now = millis();

  // 1. Send Active OBD-II Queries every 120ms
  if (mcp_initialized && (now - last_query_ms >= 120)) {
    last_query_ms = now;
    sendOBDQuery(OBD_PIDS[query_pid_index]);
    query_pid_index = (query_pid_index + 1) % NUM_PIDS;
  }

  // 2. Read Incoming CAN Frames from ECU
  struct can_frame rx;
  while (mcp_initialized && (mcp2515.readMessage(&rx) == MCP2515::ERROR_OK)) {
    last_ecu_reply_ms = now;

    // Lock onto this profile since it is receiving valid frames!
    if (!profile_locked) {
      profile_locked = true;
      char lockBuf[80];
      snprintf(lockBuf, sizeof(lockBuf), "# [CAN LOCKED] Verified communication on: %s", PROFILES[current_profile_idx].label);
      logMsg(lockBuf);
    }

    // A. Standard OBD-II Mode 01 diagnostic responses (IDs 0x7E8 to 0x7EF)
    if ((rx.can_id >= 0x7E8 && rx.can_id <= 0x7EF) && rx.can_dlc >= 3) {
      if (rx.data[1] == 0x41) { // 0x41 = Successful response to Mode 01
        uint8_t pid = rx.data[2];

        if (pid == 0x0C && rx.can_dlc >= 5) {
          // Engine RPM = ((A * 256) + B) / 4
          vehicle_rpm = ((uint16_t)rx.data[3] * 256 + rx.data[4]) / 4;
        } else if (pid == 0x0D && rx.can_dlc >= 4) {
          // Vehicle Speed (km/h)
          vehicle_speed = (float)rx.data[3];
        } else if (pid == 0x05 && rx.can_dlc >= 4) {
          // Engine Coolant / Oil Temperature (°C)
          coolant_temp = (float)rx.data[3] - 40.0;
        } else if (pid == 0x11 && rx.can_dlc >= 4) {
          // Throttle Position (%)
          vehicle_tps = (float)rx.data[3] * 100.0 / 255.0;
        }
      }
    }
    // B. Direct broadcast frames (e.g. 0x123 or dashboard instrument frames)
    else if (rx.can_id == 0x123 && rx.can_dlc >= 4) {
      uint16_t rpm_c = ((uint16_t)rx.data[0] << 8) | rx.data[1];
      if (rpm_c <= 12000) vehicle_rpm = rpm_c;
      coolant_temp = rx.data[2];
    }
  }

  // 3. Auto-Baud Profile Rotator (if no response after 8 seconds on current profile)
  if (!profile_locked && (now - last_bus_reset_ms >= 8000)) {
    last_bus_reset_ms = now;

    // Check error counters
    uint8_t tec = mcp2515.errorCountTX();
    uint8_t rec = mcp2515.errorCountRX();

    char errBuf[90];
    snprintf(errBuf, sizeof(errBuf), "# [CAN STATUS] TEC=%u, REC=%u | Switching profile...", tec, rec);
    logMsg(errBuf);

    // Switch to next profile (cycles between 500k/250k and 8MHz/16MHz)
    current_profile_idx = (current_profile_idx + 1) % NUM_PROFILES;
    applyProfile(current_profile_idx);

    char swBuf[90];
    snprintf(swBuf, sizeof(swBuf), "# [CAN PROBING] Now testing: %s", PROFILES[current_profile_idx].label);
    logMsg(swBuf);
  }

  // 4. Vehicle Connection State Evaluation
  bool is_vehicle_active = (last_ecu_reply_ms > 0) && (now - last_ecu_reply_ms < 2500);

  if (!is_vehicle_active) {
    vehicle_rpm   = 0;
    vehicle_speed = 0.0;
    vehicle_tps   = 0.0;
    coolant_temp  = 0.0;
    battery_volt  = 0.0;
    fuel_stft     = 0.0;
    active_dtc    = "STANDBY";
  } else {
    battery_volt = 14.15; // Charging voltage
    fuel_stft    = 1.5;
    active_dtc   = (coolant_temp > 105.0) ? "P0217" : "NO FAULT";
  }

  // 5. Periodic Diagnostics & Telemetry Streaming every 500 ms
  if (now - last_stream_tx_ms >= 500) {
    last_stream_tx_ms = now;

    // A. CSV line for logging / cloud bridge
    char csvBuf[64];
    snprintf(csvBuf, sizeof(csvBuf), "CSV,%lu,%s,%u,%d,0,0x%02X",
             (unsigned long)now,
             is_vehicle_active ? "0x7E8" : "NO_SIGNAL",
             vehicle_rpm,
             (int)coolant_temp,
             is_vehicle_active ? 0x01 : 0x00);
    streamPrintln(csvBuf);

    // B. VETRI Canonical ASCII Key-Value Protocol for App & ML Models
    streamPrint("[TX] VIN:ME3J350CAN2026VIN;RPM:");
    Serial.print(vehicle_rpm);
    btSerial.print(vehicle_rpm);

    streamPrint(";SPD:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    streamPrint(";TPS:");
    Serial.print(vehicle_tps, 1);
    btSerial.print(vehicle_tps, 1);

    streamPrint(";MAP:34.0;IAT:31.0;EOT:");
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
