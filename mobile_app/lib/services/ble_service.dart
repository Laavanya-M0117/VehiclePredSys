import 'dart:async';
import 'dart:math';
import '../models/telemetry_reading.dart';

enum BleState { disconnected, scanning, connecting, connected }

class BleObdService {
  BleState state = BleState.disconnected;
  String? connectedDeviceName;
  String? connectedDeviceId;
  bool isSimulated = true;

  final StreamController<TelemetryReading> _readingController = StreamController<TelemetryReading>.broadcast();
  Stream<TelemetryReading> get readingStream => _readingController.stream;

  Timer? _simulationTimer;
  final Random _rnd = Random();

  final double _baseRpm = 3200;
  double _baseCoolant = 88.0;
  final double _baseSpeed = 55.0;
  double _baseVoltage = 13.8;
  double _baseFuelTrim = 0.5;
  int _faultScenario = 0; // 0: Normal, 1: Overheat, 2: Misfire/Lean, 3: Low Volt

  Future<List<Map<String, String>>> scanForDevices() async {
    state = BleState.scanning;
    await Future.delayed(const Duration(seconds: 1));
    
    return [
      {
        'id': 'BLE-ESP32-DIY-OBD',
        'name': 'Custom ESP32 OBD-II Circuit',
        'rssi': '-48 dBm',
        'protocol': 'CAN 2.0B / K-Line',
        'chip': 'ESP32 BLE + MCP2515',
        'baud': '500K'
      },
      {
        'id': 'BLE-ELM327-8F92',
        'name': 'ELM327 OBD-II',
        'rssi': '-59 dBm',
        'protocol': 'ISO 15765 (CAN Bus)',
        'chip': 'ELM327 v2.2',
        'baud': '500K'
      },
      {
        'id': 'BLE-VGATE-iCAR-PRO',
        'name': 'Vgate iCar Pro BLE',
        'rssi': '-54 dBm',
        'protocol': 'ISO 15765-4 (CAN 29bit)',
        'chip': 'STN1110',
        'baud': '500K'
      },
      {
        'id': 'BLE-OBDLINK-CX',
        'name': 'OBDLink CX BLE',
        'rssi': '-62 dBm',
        'protocol': 'ISO 15765 CAN',
        'chip': 'STN2255',
        'baud': '500K'
      },
      {
        'id': 'BLE-HC08-SERIAL',
        'name': 'HC-08 Bluetooth Serial',
        'rssi': '-70 dBm',
        'protocol': 'UART Serial BLE',
        'chip': 'CC2541 BLE',
        'baud': '9600'
      }
    ];
  }

  Future<bool> connectToDevice(String deviceId, String deviceName) async {
    state = BleState.connecting;
    await Future.delayed(const Duration(milliseconds: 1200));
    connectedDeviceId = deviceId;
    connectedDeviceName = deviceName;
    state = BleState.connected;
    startTelemetryStream();
    return true;
  }

  void startTelemetryStream() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state != BleState.connected) return;

      double rpm = _baseRpm + (_rnd.nextDouble() * 300 - 150);
      double coolant = _baseCoolant + (_rnd.nextDouble() * 0.8 - 0.4);
      double speed = max(0, _baseSpeed + (_rnd.nextDouble() * 4 - 2));
      double voltage = _baseVoltage + (_rnd.nextDouble() * 0.2 - 0.1);
      double fuelTrim = _baseFuelTrim + (_rnd.nextDouble() * 1.0 - 0.5);
      double engineLoad = min(100, max(10, (rpm / 8000.0) * 100 + (_rnd.nextDouble() * 10 - 5)));
      double throttlePos = min(100, max(0, (speed / 140.0) * 100 + (_rnd.nextDouble() * 5 - 2.5)));
      double o2Voltage = min(1.0, max(0.1, 0.45 + (_rnd.nextDouble() * 0.4 - 0.2)));

      if (_faultScenario == 1) { // Overheat
        _baseCoolant = min(120.0, _baseCoolant + 0.5);
      } else if (_faultScenario == 2) { // Lean / Misfire
        _baseFuelTrim = min(22.0, _baseFuelTrim + 1.2);
        o2Voltage = 0.08;
      } else if (_faultScenario == 3) { // Low voltage
        _baseVoltage = max(10.2, _baseVoltage - 0.2);
      }

      final reading = TelemetryReading(
        rpm: double.parse(rpm.toStringAsFixed(1)),
        coolantTemp: double.parse(coolant.toStringAsFixed(1)),
        engineLoad: double.parse(engineLoad.toStringAsFixed(1)),
        throttlePos: double.parse(throttlePos.toStringAsFixed(1)),
        fuelTrim: double.parse(fuelTrim.toStringAsFixed(1)),
        o2Voltage: double.parse(o2Voltage.toStringAsFixed(2)),
        speed: double.parse(speed.toStringAsFixed(1)),
        voltage: double.parse(voltage.toStringAsFixed(2)),
      );

      _readingController.add(reading);
    });
  }

  void setSimulationScenario(int scenarioId) {
    _faultScenario = scenarioId;
    if (scenarioId == 0) {
      _baseCoolant = 88.0;
      _baseFuelTrim = 0.5;
      _baseVoltage = 13.8;
    }
  }

  void disconnect() {
    _simulationTimer?.cancel();
    state = BleState.disconnected;
    connectedDeviceId = null;
    connectedDeviceName = null;
  }

  void dispose() {
    _simulationTimer?.cancel();
    _readingController.close();
  }
}
