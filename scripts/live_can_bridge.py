#!/usr/bin/env python3
"""
VETRI - Real-Time CAN Bus to AI Bridge & Diagnostic Analyzer
============================================================
Decodes raw CAN frames (bits & bytes) from ESP32 / Arduino MCP2515 hardware,
converts them into physics-calibrated vehicle parameters, runs real-time
machine learning failure prediction (Triage, Failure Probability, RUL),
and logs telemetry to CSV.

Hardware Specifications (Royal Enfield Classic 350 J-Series):
  - Transmitter: Arduino Nano + MCP2515 CAN Bus Controller (SPI)
  - Receiver: ESP32 + SN65HVD230 / MCP2515
  - Baud Rate: 500 kbps (CAN Bus), 115200 (UART Serial)
  - Broadcast Frame: CAN ID 0x123 (4 bytes)
      Byte 0: (RPM >> 8) & 0xFF  [RPM High Byte]
      Byte 1: RPM & 0xFF         [RPM Low Byte]
      Byte 2: Temperature (°C)   [Engine / Oil Temp]
      Byte 3: Status Bitfield:
              Bit 0 (0x01): Engine Running (1=Running, 0=Stopped)
              Bit 1 (0x02): Overheat Alert (>105°C) -> DTC P0217
              Bit 2 (0x04): Lean Misfire / Intake Leak -> DTC P0171
              Bit 3 (0x08): Low Battery / Charging Fault -> DTC P0562

Author: VETRI Diagnostics / Team VETRI
"""

import sys
import os
import time
import argparse
import csv
from datetime import datetime
from collections import deque
import numpy as np

# Add project root to sys.path so backend imports work seamlessly
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

try:
    import serial
    import serial.tools.list_ports
    HAS_SERIAL = True
except ImportError:
    HAS_SERIAL = False

# Import local VETRI ML Inference Engine
try:
    from backend.inference import get_inference_engine
    HAS_ML = True
except Exception:
    try:
        from inference import get_inference_engine
        HAS_ML = True
    except Exception as e:
        print(f"[Warning] Local ML engine import failed ({e}). Running in rule-based triage mode.")
        HAS_ML = False


class CANBitByteDecoder:
    """Decodes raw binary bytes from CAN bus into calibrated physics metrics."""

    @staticmethod
    def decode_0x123_bytes(data: bytes):
        """
        Unpacks 4 raw bytes from CAN ID 0x123:
          data[0:2]: 16-bit unsigned integer (RPM)
          data[2]:   8-bit unsigned integer (Temp °C)
          data[3]:   8-bit bitfield (Status)
        """
        if len(data) < 4:
            return None

        rpm = (data[0] << 8) | data[1]
        temp = float(data[2])
        status = data[3]

        # Bitfield unpacking
        engine_running = bool(status & 0x01)
        overheat_alert = bool(status & 0x02)
        lean_misfire_alert = bool(status & 0x04)
        battery_alert = bool(status & 0x08)

        active_dtcs = []
        if overheat_alert or temp > 105.0:
            active_dtcs.append("P0217")
        if lean_misfire_alert:
            active_dtcs.append("P0171")
        if battery_alert:
            active_dtcs.append("P0562")

        return {
            "can_id": 0x123,
            "raw_hex": " ".join(f"{b:02X}" for b in data[:4]),
            "raw_bits": f"{status:08b}",
            "rpm": float(rpm),
            "temp": temp,
            "status_byte": status,
            "engine_running": engine_running,
            "overheat": overheat_alert,
            "lean_misfire": lean_misfire_alert,
            "battery_anomaly": battery_alert,
            "active_dtcs": active_dtcs
        }

    @staticmethod
    def parse_serial_line(line: str):
        """
        Parses different line formats emitted by the ESP32:
          1. CSV: CSV,45123,0x123,4,3200,87,0x01
          2. CAN Sniff: CAN 123 [4] 0C 80 57 01
          3. Semicolon: [TX] VIN:ME3J350...;RPM:3200;EOT:87;DTC:...
        """
        line = line.strip()
        if not line or line.startswith('#'):
            return None

        # Format 1: CSV,<millis>,<CAN_ID>,<DLC>,<RPM>,<Temp>,<Status>
        if line.startswith("CSV,") or ("," in line and "0x123" in line.lower()):
            parts = [p.strip() for p in line.split(",")]
            id_idx = 2 if parts[0].upper() == "CSV" else 1
            if len(parts) >= id_idx + 5:
                try:
                    can_id = int(parts[id_idx], 16) if parts[id_idx].startswith("0x") else int(parts[id_idx])
                    rpm = float(parts[id_idx + 2])
                    temp = float(parts[id_idx + 3])
                    status_raw = parts[id_idx + 4]
                    status = int(status_raw, 16) if status_raw.lower().startswith("0x") else int(status_raw)

                    # Reconstruct bytes for consistency
                    b0 = (int(rpm) >> 8) & 0xFF
                    b1 = int(rpm) & 0xFF
                    b2 = int(temp) & 0xFF
                    b3 = status & 0xFF
                    return CANBitByteDecoder.decode_0x123_bytes(bytes([b0, b1, b2, b3]))
                except (ValueError, IndexError):
                    pass

        # Format 2: Raw Sniff "CAN 123 [4] 0C 80 57 01"
        if line.startswith("CAN ") and "[" in line:
            parts = line.split()
            if len(parts) >= 7 and "123" in parts[1]:
                try:
                    byte_values = [int(p, 16) for p in parts[3:7]]
                    return CANBitByteDecoder.decode_0x123_bytes(bytes(byte_values))
                except (ValueError, IndexError):
                    pass

        # Format 3: Semicolon Key-Value Protocol
        if ";" in line and "RPM:" in line:
            kv = {}
            for token in line.replace("[TX]", "").strip().split(";"):
                if ":" in token:
                    k, v = token.split(":", 1)
                    kv[k.strip().upper()] = v.strip()
            if "RPM" in kv:
                try:
                    rpm = float(kv.get("RPM", 0))
                    temp = float(kv.get("EOT", kv.get("COOLANT", 88.0)))
                    dtc = kv.get("DTC", "NO FAULT")
                    active_dtcs = [dtc] if dtc not in ["NO FAULT", "NONE", ""] else []
                    status = 0x01
                    if "P0217" in dtc: status |= 0x02
                    if "P0171" in dtc: status |= 0x04
                    if "P0562" in dtc: status |= 0x08
                    return {
                        "can_id": 0x123,
                        "raw_hex": "N/A (KV)",
                        "raw_bits": f"{status:08b}",
                        "rpm": rpm,
                        "temp": temp,
                        "status_byte": status,
                        "engine_running": rpm > 400.0,
                        "overheat": "P0217" in active_dtcs,
                        "lean_misfire": "P0171" in active_dtcs,
                        "battery_anomaly": "P0562" in active_dtcs,
                        "active_dtcs": active_dtcs
                    }
                except ValueError:
                    pass

        return None


class RealTimeAITriageBridge:
    def __init__(self, port=None, baud=115200, log_file="can_log.csv"):
        self.port = port
        self.baud = baud
        self.log_file = log_file
        self.decoder = CANBitByteDecoder()
        self.inference_engine = get_inference_engine() if HAS_ML else None

        # Rolling statistics buffers
        self.rpm_window = deque(maxlen=20)
        self.temp_window = deque(maxlen=20)
        self.last_temp = None
        self.last_time = time.time()

        self._init_csv_log()

    def _init_csv_log(self):
        """Initializes CSV header for complete telemetry and AI prediction logging."""
        headers = [
            "Timestamp", "CAN_ID", "Raw_Hex", "Status_Bits", "RPM", "Engine_Temp_C",
            "Speed_Kmh", "Throttle_Pos_Pct", "Battery_Voltage_V", "STFT_Pct",
            "Active_DTCs", "Triage_Level", "Failure_Probability_Pct", "RUL_Hours", "Predicted_Fault"
        ]
        if not os.path.exists(self.log_file):
            with open(self.log_file, mode="w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(headers)

    def synthesize_physics_features(self, decoded: dict) -> dict:
        """
        Fills the correlated 19-parameter feature set for Royal Enfield J-Series 349cc.
        """
        rpm = decoded["rpm"]
        temp = decoded["temp"]
        self.rpm_window.append(rpm)
        self.temp_window.append(temp)

        # Estimate Speed from RPM & Gear
        gear = 0
        speed = 0.0
        if rpm > 400.0:
            if rpm < 1800.0:
                gear = 1
                speed = rpm / 120.0  # Gear 1 ratio: ~120 rpm per km/h
            else:
                gear = 2
                speed = rpm / 75.0   # Gear 2 ratio: ~75 rpm per km/h

        # Throttle position correlated with RPM
        tps = float(np.clip(((rpm - 1050.0) / 4500.0 * 50.0 + 2.1), 2.1, 95.0))
        # MAP (Manifold Absolute Pressure)
        map_kpa = float(np.clip(34.0 + (tps * 0.55), 30.0, 95.0))

        # Battery Voltage & Fuel Trim based on bitfield flags
        if decoded["battery_anomaly"]:
            voltage = 11.2
        else:
            voltage = 14.10 if rpm > 400.0 else 12.60

        if decoded["lean_misfire"]:
            stft = 22.5
        else:
            stft = 2.2

        ltft = 1.8

        return {
            "rpm": rpm,
            "speed": speed,
            "coolant_temp": temp,
            "eot": temp,
            "throttle_pos": tps,
            "tps": tps,
            "engine_load": tps * 1.1,
            "map": map_kpa,
            "map_kpa": map_kpa,
            "iat": 31.0,
            "fuel_trim": stft,
            "stft": stft,
            "ltft": ltft,
            "voltage": voltage,
            "battery_voltage": voltage,
            "o2_voltage": 0.35 if decoded["lean_misfire"] else 0.45,
            "gear": gear,
            "dtc_count": len(decoded["active_dtcs"]),
            "active_dtcs": decoded["active_dtcs"]
        }

    def evaluate_ai_triage(self, features: dict):
        """Passes vehicle telemetry to VETRI ML inference pipeline."""
        if self.inference_engine:
            result = self.inference_engine.predict(features)
            triage = result.get("triage_level", result.get("triage_label", "LOW"))
            prob = result.get("failure_probability", 0.04) * 100.0
            rul = result.get("remaining_useful_life_hours", result.get("rul_hours", 950.0))
            fault = result.get("predicted_fault_class", "NORMAL")
            return triage, prob, rul, fault
        else:
            # Physics-based calibrated fallback
            if features["coolant_temp"] > 115.0 or features["voltage"] < 11.0 or features["dtc_count"] >= 2:
                return "CRITICAL", 92.0, 8.0, "OVERHEATING_OR_ELECTRICAL"
            elif features["coolant_temp"] > 105.0 or features["stft"] > 18.0 or features["voltage"] < 11.8:
                return "HIGH" if features["coolant_temp"] > 105.0 else "MEDIUM", 68.0, 48.0, "SYSTEM_DEGRADATION"
            else:
                return "LOW", 4.0, 950.0, "NORMAL"

    def process_packet(self, decoded: dict):
        features = self.synthesize_physics_features(decoded)
        triage, prob, rul, fault = self.evaluate_ai_triage(features)

        # Log to CSV
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        dtc_str = ";".join(decoded["active_dtcs"]) if decoded["active_dtcs"] else "NO FAULT"
        row = [
            ts, f"0x{decoded['can_id']:03X}", decoded["raw_hex"], decoded["raw_bits"],
            f"{features['rpm']:.0f}", f"{features['coolant_temp']:.1f}",
            f"{features['speed']:.1f}", f"{features['throttle_pos']:.1f}",
            f"{features['voltage']:.2f}", f"{features['fuel_trim']:+.1f}",
            dtc_str, triage, f"{prob:.1f}", f"{rul:.1f}", fault
        ]
        with open(self.log_file, mode="a", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(row)

        # Terminal Dashboard display
        badge_color = {
            "LOW": "\033[92m",      # Green
            "MEDIUM": "\033[93m",   # Yellow
            "HIGH": "\033[91m",     # Red
            "CRITICAL": "\033[95m"  # Magenta
        }.get(triage, "\033[0m")
        reset = "\033[0m"

        print(
            f"[{ts}] CAN ID:0x{decoded['can_id']:03X} | RAW: {decoded['raw_hex']} (BITS: {decoded['raw_bits']}) | "
            f"RPM:{features['rpm']:>4.0f} | TEMP:{features['coolant_temp']:>5.1f}°C | VOLT:{features['voltage']:>4.1f}V | "
            f"DTC:{dtc_str} ==> "
            f"TRIAGE: {badge_color}{triage:<8}{reset} | FAIL PROB: {prob:>4.1f}% | RUL: {rul:>5.0f} hrs | FAULT: {fault}"
        )

    def run_serial(self):
        """Connects to live serial port and continuously decodes incoming CAN frames."""
        if not HAS_SERIAL:
            print("[Error] pyserial is not installed. Install via `pip install pyserial`.")
            return

        port = self.port
        if not port:
            # Auto-detect COM port
            ports = list(serial.tools.list_ports.comports())
            if not ports:
                print("[Error] No active COM ports detected. Please plug in the ESP32 / Arduino.")
                return
            port = ports[0].device
            print(f"[Auto-Detect] Using Serial Port: {port}")

        print(f"=================================================================")
        print(f" VETRI LIVE CAN BUS -> AI PREDICTIVE BRIDGE (Port: {port})")
        print(f" Baud: {self.baud} | Output Log: {self.log_file}")
        print(f" Listening for CAN ID 0x123 frames & CSV telemetry stream...")
        print(f"=================================================================\n")

        try:
            with serial.Serial(port, self.baud, timeout=1.0) as ser:
                while True:
                    line = ser.readline().decode("utf-8", errors="ignore").strip()
                    if line:
                        decoded = self.decoder.parse_serial_line(line)
                        if decoded:
                            self.process_packet(decoded)
                        elif line.startswith("#"):
                            print(f"\033[90m{line}\033[0m")
        except KeyboardInterrupt:
            print("\n[VETRI Bridge] Stopped by user.")
        except Exception as e:
            print(f"[Serial Error] {e}")

    def run_demo_simulation(self):
        """Simulates incoming raw CAN frames with varying engine speed, temperature, and injected faults."""
        print(f"=================================================================")
        print(f" VETRI CAN BUS SIMULATION MODE (Testing Decoder & AI Models)")
        print(f" Simulating 4-Byte CAN ID 0x123 Packets: [RPM_H, RPM_L, Temp, Status]")
        print(f" Logging to: {self.log_file}")
        print(f"=================================================================\n")

        sim_scenarios = [
            # Scenario 1: Normal idle
            {"rpm": 1050, "temp": 87, "status": 0x01, "desc": "Normal Idle (Bit 0 ON)"},
            {"rpm": 1055, "temp": 88, "status": 0x01, "desc": "Normal Idle"},
            # Scenario 2: Acceleration
            {"rpm": 2400, "temp": 89, "status": 0x01, "desc": "Cruising in 2nd Gear"},
            {"rpm": 3200, "temp": 91, "status": 0x01, "desc": "Highway Acceleration"},
            # Scenario 3: High Temperature Warning (Bit 1 ON)
            {"rpm": 3400, "temp": 106, "status": 0x03, "desc": "High Temp Warning (Bit 1: P0217)"},
            {"rpm": 3500, "temp": 116, "status": 0x03, "desc": "Critical Overheat Condition"},
            # Scenario 4: Lean Misfire / Intake Leak (Bit 2 ON)
            {"rpm": 2800, "temp": 93, "status": 0x05, "desc": "Lean Misfire Injected (Bit 2: P0171)"},
            # Scenario 5: Low Battery / Voltage drop (Bit 3 ON)
            {"rpm": 1100, "temp": 90, "status": 0x09, "desc": "Low Battery Injected (Bit 3: P0562)"},
            # Scenario 6: Recovery to Normal
            {"rpm": 1048, "temp": 88, "status": 0x01, "desc": "System Recovered to Normal"},
        ]

        for s in sim_scenarios:
            rpm = s["rpm"]
            temp = s["temp"]
            status = s["status"]

            # Pack into 4 raw bytes
            b0 = (rpm >> 8) & 0xFF
            b1 = rpm & 0xFF
            b2 = temp & 0xFF
            b3 = status & 0xFF
            raw_bytes = bytes([b0, b1, b2, b3])

            decoded = self.decoder.decode_0x123_bytes(raw_bytes)
            self.process_packet(decoded)
            time.sleep(0.1)


def main():
    parser = argparse.ArgumentParser(description="VETRI CAN Bus Bit/Byte Decoder & AI Bridge")
    parser.add_argument("--port", type=str, default=None, help="Serial port (e.g. COM5 or /dev/ttyUSB0)")
    parser.add_argument("--baud", type=int, default=115200, help="Serial baud rate (default: 115200)")
    parser.add_argument("--demo", action="store_true", help="Run in bench simulation mode without physical hardware")
    parser.add_argument("--log", type=str, default="can_log.csv", help="Path to CSV telemetry log file")

    args = parser.parse_args()
    bridge = RealTimeAITriageBridge(port=args.port, baud=args.baud, log_file=args.log)

    if args.demo:
        bridge.run_demo_simulation()
    else:
        bridge.run_serial()


if __name__ == "__main__":
    main()
