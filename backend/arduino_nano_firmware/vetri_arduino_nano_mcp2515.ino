/*
  =============================================================================
  PROJECT VETRI - Arduino Nano + MCP2515 CAN Diagnostics & Bluetooth Telemetry
  =============================================================================
  Target Board     : Arduino Nano (ATmega328P, 5V)
  CAN Controller   : MCP2515 (SPI) + TJA1050 / SN65HVD230 Transceiver
  Required Library : "mcp2515" by autowp (Install via Arduino Library Manager)
  Bluetooth Support: Hardware Serial (Pins 0/1) AND SoftwareSerial (Pins 8/9)
                     Works with HC-05, HC-06, HM-10 (BLE), JDY-31, or USB Cable
  Vehicle Target   : Royal Enfield Classic 350 (J-Series, 349cc) / Any BS6 OBD-II
  Baud Rates       : CAN 500 kbps (8 MHz crystal)
                     Hardware Serial (USB/Pins 0&1): 115200 baud
                     Bluetooth SoftwareSerial (Pins 8&9): 9600 baud (standard BT)

  Wiring to Arduino Nano:
    MCP2515 VCC   --> Nano 5V
    MCP2515 GND   --> Nano GND (Common ground with bike/transceiver)
    MCP2515 CS    --> Nano Pin D10
    MCP2515 SO    --> Nano Pin D12 (MISO)
    MCP2515 SI    --> Nano Pin D11 (MOSI)
    MCP2515 SCK   --> Nano Pin D13
    MCP2515 INT   --> Nano Pin D2  (Optional interrupt)

  Bluetooth Module Wiring (Optional if not using USB):
    BT Module VCC --> Nano 5V
    BT Module GND --> Nano GND
    BT Module TX  --> Nano Pin D8 (SoftwareSerial RX)
    BT Module RX  --> Nano Pin D9 (SoftwareSerial TX, via 1k/2k resistor divider)
    (Or wire BT directly to Nano Pins 0 & 1 for Hardware UART)

  Author: Team VETRI / Laavanya M, Atria Institute of Technology
  =============================================================================
*/

#include <SPI.h>
#include <mcp2515.h>
#include <SoftwareSerial.h>

// ======================== PIN & HARDWARE CONFIG ========================
#define CAN_CS_PIN      10
#define CAN_INT_PIN     2

// Select oscillator frequency: MCP_8MHZ for standard 8MHz blue MCP2515 module
// Change to MCP_16MHZ if your crystal has '16.000' printed on it.
#define CAN_OSC_FREQ    MCP_8MHZ
#define CAN_SPEED       CAN_500KBPS   // 500 kbps (Standard ISO 15765-4)

#define SERIAL_BAUD     115200        // USB & Hardware Serial
#define BT_BAUD         9600          // Standard HC-05 / HC-06 / HM-10 baud

MCP2515 mcp2515(CAN_CS_PIN);

// SoftwareSerial for external Bluetooth module on Pins 8 and 9
SoftwareSerial btSerial(8, 9); // RX on D8, TX on D9

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

// Simulated fault injection flags (controllable via Serial/Bluetooth commands)
bool inject_overheat = false;
bool inject_misfire  = false;
bool inject_low_bat  = false;

// ======================== TRANSMIT TO BOTH USB & BT ========================
void sendRaw(const char* str) {
  Serial.print(str);
  btSerial.print(str);
}

void sendLine(const char* str) {
  Serial.println(str);
  btSerial.println(str);
}

// ======================== MCP2515 INITIALIZATION ========================
void resetCAN() {
  mcp2515.reset();
  delay(50); // 50ms stabilization delay
  
  MCP2515::ERROR err = mcp2515.setBitrate(CAN_SPEED, CAN_OSC_FREQ);
  if (err == MCP2515::ERROR_OK) {
    mcp2515.setNormalMode();
    mcp_initialized = true;
    Serial.println(F("# [MCP2515] Initialized @ 500 kbps (Normal Mode)"));
  } else {
    Serial.println(F("# [MCP2515] Config FAILED. Check SPI wiring & crystal freq!"));
    mcp_initialized = false;
  }
}

uint8_t readTEC() { return mcp2515.errorCountTX(); }
uint8_t readREC() { return mcp2515.errorCountRX(); }

// ======================== INCOMING COMMAND HANDLER ========================
void processCommand(String cmd) {
  cmd.trim();
  cmd.toUpperCase();
  if (cmd.length() == 0) return;

  if (cmd == "FAULT:OVERHEAT" || cmd == "OVERHEAT") {
    inject_overheat = true;
    sendLine("# [CMD] Injected FAULT: Overheating (P0217)");
  } else if (cmd == "FAULT:MISFIRE" || cmd == "MISFIRE" || cmd == "LEAN") {
    inject_misfire = true;
    sendLine("# [CMD] Injected FAULT: Lean Misfire (P0171)");
  } else if (cmd == "FAULT:BATTERY" || cmd == "BATTERY") {
    inject_low_bat = true;
    sendLine("# [CMD] Injected FAULT: Low Battery (P0562)");
  } else if (cmd == "NORMAL" || cmd == "CLEAR" || cmd == "RESET") {
    inject_overheat = false;
    inject_misfire = false;
    inject_low_bat = false;
    sendLine("# [CMD] Faults cleared - Returned to NORMAL baseline");
  }
}

void checkIncomingCommands() {
  if (Serial.available()) {
    processCommand(Serial.readStringUntil('\n'));
  }
  if (btSerial.available()) {
    processCommand(btSerial.readStringUntil('\n'));
  }
}

// ======================== ARDUINO SETUP ========================
void setup() {
  // Start Hardware Serial (USB & Pin 0/1)
  Serial.begin(SERIAL_BAUD);
  // Start Software Serial (Pin 8/9 for Bluetooth)
  btSerial.begin(BT_BAUD);

  delay(200);

  Serial.println(F("========================================================="));
  Serial.println(F(" PROJECT VETRI - Arduino Nano + MCP2515 CAN Diagnostics"));
  Serial.println(F(" Hardware: Arduino Nano (ATmega328P) | CAN 500 kbps"));
  Serial.println(F(" Bluetooth: Dual Serial (Hardware 115200 & BT Pin 8/9 9600)"));
  Serial.println(F("========================================================="));

  SPI.begin();
  resetCAN();

  Serial.println(F("# Ready. Listening for CAN packets & streaming telemetry..."));
}

// ======================== ARDUINO LOOP ========================
void loop() {
  uint32_t now = millis();
  checkIncomingCommands();

  // 1. Read incoming CAN frames from MCP2515
  struct can_frame rxFrame;
  if (mcp_initialized && mcp2515.readMessage(&rxFrame) == MCP2515::ERROR_OK) {
    last_can_rx_ms = now;

    // A. Direct Broadcast Frame (CAN ID 0x123, 4 bytes: RPM_H, RPM_L, Temp, Status)
    if (rxFrame.can_id == 0x123 && rxFrame.can_dlc >= 4) {
      uint16_t rpm_be = ((uint16_t)rxFrame.data[0] << 8) | rxFrame.data[1];
      uint16_t rpm_le = ((uint16_t)rxFrame.data[1] << 8) | rxFrame.data[0];

      // Auto Byte-Order Correction (motorcycle RPM is between 400 and 12,000)
      if (rpm_be <= 12000) {
        vehicle_rpm = rpm_be;
      } else if (rpm_le <= 12000) {
        vehicle_rpm = rpm_le; // Transmitter used Little-Endian
      } else {
        vehicle_rpm = rpm_be;
      }

      vehicle_temp = rxFrame.data[2];
      status_byte  = rxFrame.data[3];
    }
    // B. Standard Vehicle OBD-II Mode 01 Replies (IDs 0x7E8 to 0x7EF)
    else if ((rxFrame.can_id >= 0x7E8 && rxFrame.can_id <= 0x7EF) && rxFrame.can_dlc >= 4) {
      if (rxFrame.data[1] == 0x41) {
        uint8_t pid = rxFrame.data[2];
        if (pid == 0x0C) { // Engine RPM
          vehicle_rpm = ((uint16_t)rxFrame.data[3] * 256 + rxFrame.data[4]) / 4;
        } else if (pid == 0x05) { // Coolant / Oil Temp
          vehicle_temp = rxFrame.data[3] - 40;
        } else if (pid == 0x0D) { // Speed (km/h)
          vehicle_speed = (float)rxFrame.data[3];
        } else if (pid == 0x11) { // Throttle Position (%)
          vehicle_tps = (float)rxFrame.data[3] * 100.0 / 255.0;
        }
      }
    }
  }

  // 2. Periodic Telemetry Transmission (every 500 ms)
  if (now - last_tx_ms >= 500) {
    last_tx_ms = now;

    bool live_can_active = (last_can_rx_ms > 0) && (now - last_can_rx_ms < 3000);

    // Bench mode auto-simulation when not connected to active motorcycle CAN bus
    if (!live_can_active) {
      static int16_t sim_delta = 18;
      vehicle_rpm += sim_delta;
      if (vehicle_rpm > 3400) sim_delta = -25;
      if (vehicle_rpm < 1050) { vehicle_rpm = 1050; sim_delta = 20; }

      vehicle_temp = inject_overheat ? 114 : 88;
      status_byte = 0x01; // Bit 0: Engine Running

      if (inject_overheat) status_byte |= 0x02; // Bit 1: Overheat
      if (inject_misfire)  status_byte |= 0x04; // Bit 2: Lean misfire
      if (inject_low_bat)  status_byte |= 0x08; // Bit 3: Low battery

      // Optional: Transmit frame onto CAN bus for MCP2515 transmitter testing
      if (mcp_initialized) {
        uint8_t tec = readTEC();
        if (tec >= 96) {
          resetCAN(); // Pre-emptively reset before bus-off threshold (128)
        } else {
          struct can_frame tx = {};
          tx.can_id  = 0x123;
          tx.can_dlc = 4;
          tx.data[0] = (vehicle_rpm >> 8) & 0xFF; // High byte
          tx.data[1] = vehicle_rpm & 0xFF;        // Low byte
          tx.data[2] = vehicle_temp;
          tx.data[3] = status_byte;
          mcp2515.sendMessage(&tx);
        }
      }
    }

    // 3. Status Bitfield & Physics Evaluation
    if ((status_byte & 0x02) != 0 || vehicle_temp > 105) {
      active_dtc = "P0217"; // Engine Coolant Over Temperature
    } else if ((status_byte & 0x04) != 0 || inject_misfire) {
      active_dtc = "P0171"; // System Too Lean (Intake Leak)
      fuel_stft = 22.5;
    } else if ((status_byte & 0x08) != 0 || inject_low_bat) {
      active_dtc = "P0562"; // Low Battery Voltage Condition
      battery_volt = 11.20;
    } else {
      active_dtc = "NO FAULT";
      fuel_stft = 2.2;
      battery_volt = 14.10;
    }

    // Calculate Speed and Gear estimation for Royal Enfield J-Series 349cc
    if (vehicle_rpm > 1800) {
      current_gear = 2;
      vehicle_speed = (float)vehicle_rpm / 75.0; // 2nd gear ratio: ~75 rpm per km/h
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

    // =========================================================================
    // 4. Output Format 1: CSV Telemetry Line (for Python AI Bridge / Logger)
    //    Format: CSV,<millis>,<CAN_ID>,<DLC>,<RPM>,<Temp>,<Status_Hex>
    // =========================================================================
    char csvBuf[64];
    snprintf(csvBuf, sizeof(csvBuf), "CSV,%lu,0x123,4,%u,%u,0x%02X",
             (unsigned long)now, vehicle_rpm, (unsigned int)vehicle_temp, status_byte);
    sendLine(csvBuf);

    // =========================================================================
    // 5. Output Format 2: Canonical VETRI Semicolon Protocol (for Mobile App)
    //    [TX] VIN:ME3J350...;RPM:...;SPD:...;DTC:...
    // =========================================================================
    sendRaw("[TX] VIN:ME3J350CAN2026VIN;RPM:");
    Serial.print(vehicle_rpm);
    btSerial.print(vehicle_rpm);

    sendRaw(";SPD:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    sendRaw(";TPS:");
    Serial.print(vehicle_tps, 1);
    btSerial.print(vehicle_tps, 1);

    sendRaw(";MAP:");
    Serial.print(vehicle_map, 1);
    btSerial.print(vehicle_map, 1);

    sendRaw(";IAT:31.0;EOT:");
    Serial.print((float)vehicle_temp, 1);
    btSerial.print((float)vehicle_temp, 1);

    sendRaw(";O2:0.45;STFT:+");
    Serial.print(fuel_stft, 1);
    btSerial.print(fuel_stft, 1);

    sendRaw(";LTFT:+1.8;BAT:");
    Serial.print(battery_volt, 2);
    btSerial.print(battery_volt, 2);

    sendRaw(";GEAR:");
    sendRaw(gearStr);

    sendRaw(";CLUTCH:0;SIDE_STAND:0;F_WHEEL:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    sendRaw(";R_WHEEL:");
    Serial.print(vehicle_speed, 1);
    btSerial.print(vehicle_speed, 1);

    sendRaw(";DTC:");
    sendLine(active_dtc);
  }
}
