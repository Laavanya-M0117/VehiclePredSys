/*
  =============================================================================
  PROJECT VETRI - Arduino Nano + MCP2515 CAN Bus Diagnostics Firmware
  =============================================================================
  Target Board     : Arduino Nano (ATmega328P, 5V)
  CAN Controller   : MCP2515 + TJA1050 Transceiver (SPI Interface)
  Required Library : "mcp2515" by autowp (Install via Arduino Library Manager)
  Baud Rate (UART) : 115200 baud (to PC / Python AI Bridge / VETRI)
  Baud Rate (CAN)  : 500 kbps (Standard ISO 11898 / Royal Enfield J-Series)
  Crystal Freq     : 8 MHz (MCP_8MHZ) - Change to MCP_16MHZ if 16MHz crystal

  SPI Wiring:
    Arduino Nano Pin D10  -->  MCP2515 CS
    Arduino Nano Pin D11  -->  MCP2515 MOSI (SI)
    Arduino Nano Pin D12  -->  MCP2515 MISO (SO)
    Arduino Nano Pin D13  -->  MCP2515 SCK
    Arduino Nano 5V       -->  MCP2515 VCC
    Arduino Nano GND      -->  MCP2515 GND
    (Optional) Pin D2     -->  MCP2515 INT

  Output Protocols on Serial (115200 baud):
    1. CSV Telemetry Format (for Python AI Bridge / Logger):
       CSV,<millis>,0x123,4,<RPM>,<Temp>,<Status_Hex>
       Example: CSV,45123,0x123,4,3200,87,0x01

    2. Canonical VETRI Protocol (for Web Dashboard / Mobile App):
       [TX] VIN:ME3J350CAN2026VIN;RPM:3200;SPD:42.7;TPS:26.0;MAP:48.3;IAT:31.0;
            EOT:87.0;O2:0.45;STFT:+2.2;LTFT:+1.8;BAT:14.10;GEAR:2;CLUTCH:0;
            SIDE_STAND:0;F_WHEEL:42.7;R_WHEEL:42.7;DTC:NO FAULT

  Author: VETRI Diagnostics / Team VETRI
  =============================================================================
*/

#include <SPI.h>
#include <mcp2515.h>

// ======================== HARDWARE PIN DEFINITIONS ========================
#define CAN_CS_PIN      10
#define CAN_INT_PIN     2     // Optional hardware interrupt

// Set to MCP_8MHZ for standard 8MHz blue MCP2515 modules; MCP_16MHZ for 16MHz
#define CAN_OSC_FREQ    MCP_8MHZ
#define CAN_SPEED       CAN_500KBPS   // 500 kbps for Classic 350 J-series

MCP2515 mcp2515(CAN_CS_PIN);

// ======================== VEHICLE STATE VARIABLES ========================
uint16_t vehicle_rpm   = 1050;
uint8_t  vehicle_temp  = 88;
uint8_t  status_byte   = 0x01; // Bit 0: Engine Running (1=ON, 0=OFF)
float    vehicle_speed = 0.0;
float    vehicle_tps   = 2.1;
float    vehicle_map   = 34.0;
float    battery_volt  = 14.10;
float    fuel_stft     = 2.2;
const char* active_dtc = "NO FAULT";
uint8_t  current_gear  = 0;    // 0=N, 1..5

uint32_t last_can_rx_ms = 0;
uint32_t last_tx_ms     = 0;
bool     mcp_initialized = false;

// Simulated fault injection flags (controllable via Serial commands)
bool inject_overheat = false;
bool inject_misfire  = false;
bool inject_low_bat  = false;

// ======================== MCP2515 HELPER FUNCTIONS ========================
void resetCAN() {
  mcp2515.reset();
  delay(50); // Allow crystal oscillator to stabilize (50ms per guide)
  
  MCP2515::ERROR err = mcp2515.setBitrate(CAN_SPEED, CAN_OSC_FREQ);
  if (err == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    mcp_initialized = true;
    Serial.println(F("# [MCP2515] Initialized @ 500 kbps (Normal Mode)"));
  } else {
    Serial.println(F("# [MCP2515] Bitrate config FAILED. Check SPI wiring!"));
    mcp_initialized = false;
  }
}

uint8_t readTEC() { return mcp2515.readRegister(MCP_TEC); }  // Transmit Error Counter
uint8_t readREC() { return mcp2515.readRegister(MCP_REC); }  // Receive Error Counter

// ======================== SERIAL COMMAND HANDLER ========================
void checkSerialCommands() {
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if (cmd == "FAULT:OVERHEAT" || cmd == "OVERHEAT") {
      inject_overheat = true;
      Serial.println(F("# [CMD] Injected FAULT: Overheating (P0217)"));
    } else if (cmd == "FAULT:MISFIRE" || cmd == "MISFIRE" || cmd == "LEAN") {
      inject_misfire = true;
      Serial.println(F("# [CMD] Injected FAULT: Lean Misfire (P0171)"));
    } else if (cmd == "FAULT:BATTERY" || cmd == "BATTERY") {
      inject_low_bat = true;
      Serial.println(F("# [CMD] Injected FAULT: Low Battery (P0562)"));
    } else if (cmd == "NORMAL" || cmd == "CLEAR" || cmd == "RESET") {
      inject_overheat = false;
      inject_misfire = false;
      inject_low_bat = false;
      Serial.println(F("# [CMD] Faults cleared - Returned to NORMAL baseline"));
    }
  }
}

// ======================== SETUP ========================
void setup() {
  Serial.begin(115200);
  while (!Serial && millis() < 2000); // Wait for USB Serial

  Serial.println(F("========================================================="));
  Serial.println(F(" PROJECT VETRI - Arduino Nano + MCP2515 CAN Diagnostics"));
  Serial.println(F(" Machine Learning Failure Triage & Live Telemetry Stream"));
  Serial.println(F("========================================================="));

  SPI.begin();
  resetCAN();

  Serial.println(F("# Ready. Streaming live telemetry to VETRI..."));
}

// ======================== MAIN LOOP ========================
void loop() {
  uint32_t now = millis();
  checkSerialCommands();

  // 1. Check for incoming CAN frames (from bike ECU or external node)
  struct can_frame rxFrame;
  if (mcp_initialized && mcp2515.readMessage(&rxFrame) == MCP2515::ERROR_OK) {
    last_can_rx_ms = now;

    // Check CAN ID 0x123 (4-byte frame: RPM_H, RPM_L, Temp, Status)
    if (rxFrame.can_id == 0x123 && rxFrame.can_dlc >= 4) {
      vehicle_rpm  = ((uint16_t)rxFrame.data[0] << 8) | rxFrame.data[1];
      vehicle_temp = rxFrame.data[2];
      status_byte  = rxFrame.data[3];
    }
    // Check standard OBD-II Mode 01 PID replies (0x7E8)
    else if ((rxFrame.can_id >= 0x7E8 && rxFrame.can_id <= 0x7EF) && rxFrame.can_dlc >= 4) {
      if (rxFrame.data[1] == 0x41 && rxFrame.data[2] == 0x0C) { // PID 0x0C: Engine RPM
        vehicle_rpm = ((uint16_t)rxFrame.data[3] * 256 + rxFrame.data[4]) / 4;
      } else if (rxFrame.data[1] == 0x41 && rxFrame.data[2] == 0x05) { // PID 0x05: Coolant/EOT
        vehicle_temp = rxFrame.data[3] - 40;
      }
    }
  }

  // 2. Periodic Output & Bench Simulation (every 500 ms)
  if (now - last_tx_ms >= 500) {
    last_tx_ms = now;

    bool live_can_active = (last_can_rx_ms > 0) && (now - last_can_rx_ms < 3000);

    // Bench mode simulation if not plugged into a live bus
    if (!live_can_active) {
      static int16_t sim_direction = 15;
      vehicle_rpm += sim_direction;
      if (vehicle_rpm > 3400) sim_direction = -25;
      if (vehicle_rpm < 1050) { vehicle_rpm = 1050; sim_direction = 20; }

      vehicle_temp = inject_overheat ? 112 : 88;
      status_byte = 0x01; // Bit 0: Engine Running

      if (inject_overheat) status_byte |= 0x02; // Bit 1: Overheat
      if (inject_misfire)  status_byte |= 0x04; // Bit 2: Lean misfire
      if (inject_low_bat)  status_byte |= 0x08; // Bit 3: Battery low

      // Transmit onto CAN bus (pin to TXB0 with TEC check to prevent error 2)
      if (mcp_initialized) {
        uint8_t tec = readTEC();
        if (tec >= 96) {
          resetCAN();
        } else {
          struct can_frame txFrame = {};
          txFrame.can_id  = 0x123;
          txFrame.can_dlc = 4;
          txFrame.data[0] = (vehicle_rpm >> 8) & 0xFF;
          txFrame.data[1] = vehicle_rpm & 0xFF;
          txFrame.data[2] = vehicle_temp;
          txFrame.data[3] = status_byte;
          mcp2515.sendMessage(MCP2515::TXB0, &txFrame);
        }
      }
    }

    // 3. Derive Physics-Calibrated Parameters for VETRI 19-Feature Pipeline
    if (status_byte & 0x02 || vehicle_temp > 105) {
      active_dtc = "P0217"; // Overheat
    } else if (status_byte & 0x04 || inject_misfire) {
      active_dtc = "P0171"; // System too lean
      fuel_stft = 22.4;
    } else if (status_byte & 0x08 || inject_low_bat) {
      active_dtc = "P0562"; // Low battery voltage
      battery_volt = 11.20;
    } else {
      active_dtc = "NO FAULT";
      fuel_stft = 2.2;
      battery_volt = 14.10;
    }

    if (vehicle_rpm > 1800) {
      current_gear = 2;
      vehicle_speed = (float)vehicle_rpm / 75.0; // Royal Enfield 2nd gear ratio
    } else if (vehicle_rpm > 1200) {
      current_gear = 1;
      vehicle_speed = (float)vehicle_rpm / 120.0;
    } else {
      current_gear = 0;
      vehicle_speed = 0.0;
    }

    vehicle_tps = constrain(((float)(vehicle_rpm - 1050) / 4500.0 * 50.0 + 2.1), 2.1, 95.0);
    vehicle_map = constrain(34.0 + (vehicle_tps * 0.55), 30.0, 95.0);

    const char* gearStr = (current_gear == 0) ? "N" : (current_gear == 1 ? "1" : "2");

    // 4. Output 1: CSV Telemetry Line (for live_can_bridge.py / python ML analyzer)
    // CSV,<millis>,<CAN_ID>,<DLC>,<RPM>,<Temp>,<Status>
    Serial.print(F("CSV,"));
    Serial.print(now);
    Serial.print(F(",0x123,4,"));
    Serial.print(vehicle_rpm);
    Serial.print(F(","));
    Serial.print(vehicle_temp);
    Serial.print(F(",0x"));
    if (status_byte < 0x10) Serial.print(F("0"));
    Serial.println(status_byte, HEX);

    // 5. Output 2: Canonical VETRI Protocol Line (for Web/Mobile app)
    Serial.print(F("[TX] VIN:ME3J350CAN2026VIN;RPM:"));
    Serial.print(vehicle_rpm);
    Serial.print(F(";SPD:"));
    Serial.print(vehicle_speed, 1);
    Serial.print(F(";TPS:"));
    Serial.print(vehicle_tps, 1);
    Serial.print(F(";MAP:"));
    Serial.print(vehicle_map, 1);
    Serial.print(F(";IAT:31.0;EOT:"));
    Serial.print((float)vehicle_temp, 1);
    Serial.print(F(";O2:0.45;STFT:+"));
    Serial.print(fuel_stft, 1);
    Serial.print(F(";LTFT:+1.8;BAT:"));
    Serial.print(battery_volt, 2);
    Serial.print(F(";GEAR:"));
    Serial.print(gearStr);
    Serial.print(F(";CLUTCH:0;SIDE_STAND:0;F_WHEEL:"));
    Serial.print(vehicle_speed, 1);
    Serial.print(F(";R_WHEEL:"));
    Serial.print(vehicle_speed, 1);
    Serial.print(F(";DTC:"));
    Serial.println(active_dtc);
  }
}
