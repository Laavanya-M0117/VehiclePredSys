import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/firebase_otp_service.dart';

class AppStateProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final DatabaseService _db = DatabaseService.instance;

  // Authentication & Profile State
  bool _isAuthenticated = false;
  String _displayName = 'VETRI Driver';
  String _userEmail = '';
  String _phoneNumber = '';
  String _vehicleName = 'Royal Enfield Classic 350';
  String _vehicleVin = 'ME3J350CAN2026VIN';
  String _vehicleType = 'Royal Enfield 350cc (J-Series)';
  int _odometerKm = 4320;
  String _subscriptionTier = '1-MONTH STARTER';

  // Notification Preferences
  bool _pushNotifications = true;
  bool _criticalSmsAlerts = true;

  // Theme
  ThemeMode _themeMode = ThemeMode.dark;

  // BLE & Telemetry
  bool _isConnected = false;
  Map<String, String>? _connectedDevice;
  Timer? _telemetryTimer;

  // Live Telemetry Values (Standard Royal Enfield Classic 350 Idle Baseline)
  double _rpm = 1050.0;
  double _speed = 0.0;
  double _coolantTemp = 88.0;
  double _batteryVoltage = 14.1;
  double _fuelTrim = 2.4;
  int _dtcCount = 0;
  double _failureProbability = 0.02;
  String _triageLevel = 'LOW'; // LOW, MEDIUM, CRITICAL
  double _remainingUsefulLifeHours = 720.0;

  // Extended Royal Enfield Classic 350 Live Parameters
  double _tps = 2.1;
  double _mapKpa = 34.0;
  double _iat = 31.0;
  double _eot = 88.0;
  double _o2Voltage = 0.35;
  double _ltft = 1.8;
  String _gear = 'N';
  bool _clutchReleased = true;
  bool _sideStandUp = true;
  double _frontWheelSpeed = 0.0;
  double _rearWheelSpeed = 0.0;

  // Model Prediction Metadata & Explainability
  String _diagnosticExplanation = 'All parameters within nominal J-Series baseline.';
  String _predictedFaultClass = 'NORMAL';
  String _modelVersion = 'HistGradientBoosting v2.0';
  Map<String, dynamic> _engineeredFeatures = {};
  DateTime? _lastPredictionTime;
  bool _isPredicting = false;
  DateTime? _lastAlertDispatchTime;

  // Inter-Trip Delta Degradation Baseline
  Map<String, dynamic>? _previousTripBaseline;
  final List<String> _interTripDriftWarnings = [];

  // Cloud Storage Free Demo Status
  int _cloudSyncedPackets = 1842;
  double _cloudStorageUsedMb = 3.4;
  final String _cloudBucketId = 'vetri-free-tier-us-east1-demo';

  // Telemetry Graph History Buffers (Last 30 points)
  final List<double> _rpmHistory = [];
  final List<double> _speedHistory = [];

  // Active DTC Faults
  final List<Map<String, String>> _activeFaults = [];

  // Live Bluetooth Raw Serial Terminal Logs
  final List<String> _rawTerminalLogs = [];
  List<String> get rawTerminalLogs => List.unmodifiable(_rawTerminalLogs);

  // 14-Day Trip History Data
  final List<Map<String, dynamic>> _tripHistory = [];

  // In-Memory Device Binding Cache
  final Map<String, String> _deviceOwnerMap = {};

  AppStateProvider() {
    _initPersistence();
    _initDemoTripHistory();
  }

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String get displayName => _displayName;
  String get userEmail => _userEmail;
  String get phoneNumber => _phoneNumber;
  String get vehicleName => _vehicleName;
  String get vehicleVin => _vehicleVin;
  String get vehicleType => _vehicleType;
  bool get isMotorcycle => _vehicleType.toLowerCase().contains('motorcycle') || _vehicleName.toLowerCase().contains('ktm') || _vehicleName.toLowerCase().contains('bike');
  int get odometerKm => _odometerKm;
  String get subscriptionTier => _subscriptionTier;
  bool get pushNotifications => _pushNotifications;
  bool get criticalSmsAlerts => _criticalSmsAlerts;
  ThemeMode get themeMode => _themeMode;
  bool get isConnected => _isConnected;
  Map<String, String>? get connectedDevice => _connectedDevice;

  double get rpm => _rpm;
  double get speed => _speed;
  double get coolantTemp => _coolantTemp;
  double get batteryVoltage => _batteryVoltage;
  double get fuelTrim => _fuelTrim;
  int get dtcCount => _dtcCount;
  double get failureProbability => _failureProbability;
  String get triageLevel => _triageLevel;
  double get remainingUsefulLifeHours => _remainingUsefulLifeHours;

  double get tps => _tps;
  double get mapKpa => _mapKpa;
  double get iat => _iat;
  double get eot => _eot;
  double get o2Voltage => _o2Voltage;
  double get ltft => _ltft;
  String get gear => _gear;
  bool get clutchReleased => _clutchReleased;
  bool get sideStandUp => _sideStandUp;
  double get frontWheelSpeed => _frontWheelSpeed;
  double get rearWheelSpeed => _rearWheelSpeed;

  String get diagnosticExplanation => _diagnosticExplanation;
  String get predictedFaultClass => _predictedFaultClass;
  String get modelVersion => _modelVersion;
  Map<String, dynamic> get engineeredFeatures => Map.unmodifiable(_engineeredFeatures);
  String get currentServerUrl => ApiService.baseUrl;

  void setCustomServerUrl(String url) {
    ApiService.setBaseUrl(url);
    notifyListeners();
  }

  int get cloudSyncedPackets => _cloudSyncedPackets;
  double get cloudStorageUsedMb => _cloudStorageUsedMb;
  String get cloudBucketId => _cloudBucketId;
  List<String> get interTripDriftWarnings => List.unmodifiable(_interTripDriftWarnings);

  List<double> get rpmHistory => List.unmodifiable(_rpmHistory);
  List<double> get speedHistory => List.unmodifiable(_speedHistory);
  List<Map<String, String>> get activeFaults => List.unmodifiable(_activeFaults);
  List<Map<String, String>> get activeAlerts => List.unmodifiable(_activeFaults);
  List<Map<String, dynamic>> get tripHistory => List.unmodifiable(_tripHistory);

  bool get isProfileIncomplete => _userEmail.trim().isEmpty || _phoneNumber.trim().isEmpty;

  List<String> get missingProfileFields {
    final list = <String>[];
    if (_userEmail.trim().isEmpty) list.add('Email Address');
    if (_phoneNumber.trim().isEmpty) list.add('Phone Number');
    return list;
  }

  // ==========================================
  // Persistence & Storage Init
  // ==========================================

  Future<void> _initPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _displayName = prefs.getString('display_name') ?? 'VETRI Driver';
      _userEmail = prefs.getString('user_email') ?? '';
      _phoneNumber = prefs.getString('user_phone') ?? '';
      _vehicleName = prefs.getString('vehicle_name') ?? 'KTM Duke 390';
      _vehicleVin = prefs.getString('vehicle_vin') ?? 'MD2A1234567890VIN';
      _vehicleType = _detectVehicleType(_vehicleVin, _vehicleName);
      _odometerKm = prefs.getInt('odometer_km') ?? 14250;
      _subscriptionTier = prefs.getString('subscription_tier') ?? '1-MONTH STARTER';

      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      debugPrint('SharedPreferences init error: ' + e.toString());
    }
  }

  String _detectVehicleType(String vin, String name) {
    final upperVin = vin.toUpperCase();
    final lowerName = name.toLowerCase();
    if (upperVin.startsWith('MD2') || upperVin.startsWith('ME4') || lowerName.contains('ktm') || lowerName.contains('duke') || lowerName.contains('bike') || lowerName.contains('motorcycle')) {
      return 'Motorcycle (2-Wheeler)';
    }
    return 'Passenger Car (4-Wheeler)';
  }

  void _initDemoTripHistory() {
    _tripHistory.clear();
    final now = DateTime.now();
    
    final trips = [
      {'route': 'Hebbal Flyover to Malleshwaram 8th Cross', 'daysAgo': 0, 'dist': 8.4, 'dur': '22 min', 'avgSpd': 42, 'peakRpm': 6800, 'eff': '32.5 km/L', 'score': 95, 'triage': 'LOW'},
      {'route': 'RT Nagar Main Road to Vijaynagar Metro', 'daysAgo': 1, 'dist': 11.2, 'dur': '34 min', 'avgSpd': 36, 'peakRpm': 7200, 'eff': '29.8 km/L', 'score': 92, 'triage': 'LOW'},
      {'route': 'Malleshwaram Circle to Hebbal Kempapura', 'daysAgo': 2, 'dist': 9.8, 'dur': '28 min', 'avgSpd': 38, 'peakRpm': 6400, 'eff': '31.0 km/L', 'score': 89, 'triage': 'MEDIUM'},
      {'route': 'Vijaynagar Club to RT Nagar BDA Complex', 'daysAgo': 4, 'dist': 12.6, 'dur': '38 min', 'avgSpd': 34, 'peakRpm': 7600, 'eff': '27.4 km/L', 'score': 84, 'triage': 'MEDIUM'},
      {'route': 'Hebbal Lake Loop to Malleshwaram', 'daysAgo': 6, 'dist': 10.5, 'dur': '26 min', 'avgSpd': 44, 'peakRpm': 6900, 'eff': '33.2 km/L', 'score': 94, 'triage': 'LOW'},
      {'route': 'RT Nagar to Hebbal Outer Ring Road', 'daysAgo': 8, 'dist': 6.2, 'dur': '16 min', 'avgSpd': 48, 'peakRpm': 6200, 'eff': '34.5 km/L', 'score': 96, 'triage': 'LOW'},
      {'route': 'Vijaynagar TTMC to Malleshwaram 18th Cross', 'daysAgo': 10, 'dist': 8.9, 'dur': '25 min', 'avgSpd': 39, 'peakRpm': 6700, 'eff': '30.1 km/L', 'score': 88, 'triage': 'LOW'},
      {'route': 'Hebbal to Vijaynagar Express Commute', 'daysAgo': 13, 'dist': 14.8, 'dur': '36 min', 'avgSpd': 46, 'peakRpm': 7800, 'eff': '31.8 km/L', 'score': 91, 'triage': 'LOW'},
    ];

    for (var t in trips) {
      final date = now.subtract(Duration(days: t['daysAgo'] as int));
      final dayStr = date.day.toString().padLeft(2, '0');
      final monthStr = date.month.toString().padLeft(2, '0');
      _tripHistory.add({
        'id': 'TRIP-' + (1000 + (t['daysAgo'] as int)).toString(),
        'date': '$dayStr/$monthStr/${date.year}',
        'route': t['route'],
        'distanceKm': t['dist'],
        'duration': t['dur'],
        'avgSpeedKmh': t['avgSpd'],
        'peakRpm': t['peakRpm'],
        'efficiency': t['eff'],
        'healthScore': t['score'],
        'triage': t['triage'],
      });
    }

    _previousTripBaseline = {
      'restingBattery': 12.8,
      'averageCoolant': 91.5,
      'longTermFuelTrim': 0.8,
      'peakRpm': 8200,
    };
  }

  Future<void> _saveProfileToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('display_name', _displayName);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_phone', _phoneNumber);
      await prefs.setString('vehicle_name', _vehicleName);
      await prefs.setString('vehicle_vin', _vehicleVin);
      await prefs.setInt('odometer_km', _odometerKm);
      await prefs.setString('subscription_tier', _subscriptionTier);
    } catch (e) {
      debugPrint('Error saving to prefs: ' + e.toString());
    }
  }

  // ==========================================
  // Authentication & Device Binding
  // ==========================================

  void bindDevice(String deviceId, String userIdentifier, {String? displayName, String? email, String? phone}) {
    _deviceOwnerMap[deviceId] = userIdentifier;
    _db.bindDeviceUser(
      deviceId: deviceId,
      userIdentifier: userIdentifier,
      displayName: displayName ?? _displayName,
      email: email ?? _userEmail,
      phone: phone ?? _phoneNumber,
      vehicleName: _vehicleName,
      vehicleVin: _vehicleVin,
      odometerKm: _odometerKm,
      subscriptionTier: _subscriptionTier,
    );
    notifyListeners();
  }

  Future<bool> isDeviceBound(String deviceId) async {
    if (_deviceOwnerMap.containsKey(deviceId)) return true;
    final binding = await _db.getDeviceBinding(deviceId);
    if (binding != null) {
      _deviceOwnerMap[deviceId] = binding['user_identifier'] ?? '';
      return true;
    }
    return false;
  }

  Future<String?> getDeviceOwner(String deviceId) async {
    if (_deviceOwnerMap.containsKey(deviceId)) return _deviceOwnerMap[deviceId];
    final binding = await _db.getDeviceBinding(deviceId);
    if (binding != null) {
      final owner = binding['user_identifier'] as String?;
      if (owner != null) _deviceOwnerMap[deviceId] = owner;
      return owner;
    }
    return null;
  }

  Future<AuthResult> signIn(String emailOrPhone, String password) async {
    final res = await _api.login(emailOrPhone, password);
    if (res.success) {
      _isAuthenticated = true;
      final prefs = await SharedPreferences.getInstance();
      if (emailOrPhone.contains('@')) {
        _userEmail = emailOrPhone;
        final savedEmail = prefs.getString('user_email');
        if (savedEmail == emailOrPhone) {
          _phoneNumber = prefs.getString('user_phone') ?? '';
        } else {
          _phoneNumber = ''; // Fresh account - complete profile required
        }
      } else {
        _phoneNumber = emailOrPhone;
        final savedPhone = prefs.getString('user_phone');
        if (savedPhone == emailOrPhone) {
          _userEmail = prefs.getString('user_email') ?? '';
        } else {
          _userEmail = ''; // Fresh account - complete profile required
        }
      }
      await _saveProfileToPrefs();
      notifyListeners();
    }
    return res;
  }

  void signInWithPhone(String phone, {String? displayName}) async {
    _phoneNumber = phone;
    if (displayName != null && displayName.isNotEmpty) {
      _displayName = displayName;
    } else {
      _displayName = 'VETRI Rider';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('user_phone');
      if (savedPhone == phone) {
        _userEmail = prefs.getString('user_email') ?? '';
      } else {
        _userEmail = ''; // Fresh account - do not leak previous email
      }
    } catch (_) {
      _userEmail = '';
    }
    _isAuthenticated = true;
    _saveProfileToPrefs();
    notifyListeners();
  }

  Future<AuthResult> signUp(String email, String password, {String? displayName, String? phone}) async {
    final res = await _api.register(email, password, displayName: displayName, phone: phone);
    if (res.success) {
      _isAuthenticated = true;
      _userEmail = email;
      if (displayName != null && displayName.isNotEmpty) _displayName = displayName;
      if (phone != null && phone.isNotEmpty) _phoneNumber = phone;
      await _saveProfileToPrefs();
      notifyListeners();
    }
    return res;
  }

  void signOut() {
    _isAuthenticated = false;
    _disconnectDevice();
    notifyListeners();
  }

  // ==========================================
  // Profile & Preferences Updates
  // ==========================================

  void updateUserProfile(String newName, String newEmail, {String? newPhone}) {
    if (newName.isNotEmpty) _displayName = newName;
    _userEmail = newEmail;
    if (newPhone != null) _phoneNumber = newPhone;
    _saveProfileToPrefs();
    notifyListeners();
  }

  void updateVehicleDetails(String newName, String newVin, int newOdometer) {
    _vehicleName = newName;
    _vehicleVin = newVin;
    _vehicleType = _detectVehicleType(newVin, newName);
    _odometerKm = newOdometer;
    _saveProfileToPrefs();
    notifyListeners();
  }

  void updateNotificationSettings({bool? push, bool? sms}) {
    if (push != null) _pushNotifications = push;
    if (sms != null) _criticalSmsAlerts = sms;
    notifyListeners();
  }

  void toggleThemeMode(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void upgradeSubscription(String newTier) {
    _subscriptionTier = newTier;
    _saveProfileToPrefs();
    notifyListeners();
  }

  // ==========================================
  // Bluetooth Connection & Telemetry Engine
  // ==========================================

  // Nordic UART Service (NUS) UUIDs — used by BLE ESP32 firmware
  static const String _NUS_SERVICE_UUID    = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _NUS_TX_CHAR_UUID    = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // ESP32 → Phone (notify)
  static const String _NUS_RX_CHAR_UUID    = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Phone → ESP32 (write)

  BluetoothDevice? _bleDevice;
  StreamSubscription<List<int>>? _charSubscription;
  BluetoothCharacteristic? _rxChar; // For sending commands to ESP32
  String _bleBuffer = '';

  // Called by adapter_found_screen.dart after pairing
  Future<bool> connectBleDevice(String deviceId, String deviceName) async {
    connectToDevice({'id': deviceId, 'name': deviceName, 'rssi': 'LIVE', 'isReal': 'true'});
    return true;
  }

  void connectToDevice(Map<String, String> device) async {
    _connectedDevice = device;
    _isConnected = true;
    _startLiveTelemetry();
    _evaluateInterTripDelta();
    notifyListeners();

    if (kIsWeb || device['id'] == null || device['id']!.isEmpty) return;

    try {
      final id = device['id']!;
      final dev = BluetoothDevice.fromId(id);
      _bleDevice = dev;

      debugPrint('[BLE] Connecting to $id (${device['name']})...');

      await dev.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 12),
      ).catchError((e) => debugPrint('[BLE] Connect error: $e'));

      debugPrint('[BLE] Connected. Discovering services...');
      final services = await dev.discoverServices();

      // Priority 1: Find Nordic UART Service (NUS) — what our BLE ESP32 uses
      bool nusFound = false;
      for (var s in services) {
        final sUuid = s.uuid.toString().toLowerCase();
        if (sUuid == _NUS_SERVICE_UUID || sUuid.contains('6e400001')) {
          debugPrint('[BLE] ✅ Nordic UART Service found!');
          nusFound = true;
          for (var c in s.characteristics) {
            final cUuid = c.uuid.toString().toLowerCase();
            // TX char (ESP32 → Phone): subscribe for notifications
            if (cUuid == _NUS_TX_CHAR_UUID || cUuid.contains('6e400003')) {
              debugPrint('[BLE] ✅ NUS TX characteristic found — subscribing...');
              await c.setNotifyValue(true);
              _charSubscription?.cancel();
              _charSubscription = c.lastValueStream.listen((data) {
                if (data.isNotEmpty) {
                  final text = utf8.decode(data, allowMalformed: true);
                  // ESP32 sends chunks — buffer until newline
                  _bleBuffer += text;
                  while (_bleBuffer.contains('\n')) {
                    final idx = _bleBuffer.indexOf('\n');
                    final line = _bleBuffer.substring(0, idx).trim();
                    _bleBuffer = _bleBuffer.substring(idx + 1);
                    if (line.isNotEmpty) parseIncomingBluetoothPacket(line);
                  }
                }
              });
            }
            // RX char (Phone → ESP32): save reference for sending commands
            if (cUuid == _NUS_RX_CHAR_UUID || cUuid.contains('6e400002')) {
              _rxChar = c;
              debugPrint('[BLE] ✅ NUS RX characteristic found — ready to send commands.');
            }
          }
          break;
        }
      }

      // Priority 2: Fallback — any notifiable characteristic (for ELM327/OBDLink adapters)
      if (!nusFound) {
        debugPrint('[BLE] NUS not found. Falling back to generic notify scan...');
        for (var s in services) {
          for (var c in s.characteristics) {
            if (c.properties.notify || c.properties.indicate) {
              await c.setNotifyValue(true).catchError((_) {});
              _charSubscription?.cancel();
              _charSubscription = c.lastValueStream.listen((data) {
                if (data.isNotEmpty) {
                  final text = utf8.decode(data, allowMalformed: true);
                  _bleBuffer += text;
                  while (_bleBuffer.contains('\n')) {
                    final idx = _bleBuffer.indexOf('\n');
                    final line = _bleBuffer.substring(0, idx).trim();
                    _bleBuffer = _bleBuffer.substring(idx + 1);
                    if (line.isNotEmpty) parseIncomingBluetoothPacket(line);
                  }
                }
              });
              debugPrint('[BLE] Generic notify char subscribed: ${c.uuid}');
            }
          }
        }
      }

      debugPrint('[BLE] Setup complete.');
    } catch (e) {
      debugPrint('[BLE Hook Error]: $e');
    }
  }

  // Send a text command to the ESP32 (e.g. "QUERY:RPM\n")
  Future<void> sendBleCommand(String command) async {
    if (_rxChar == null) return;
    try {
      final bytes = utf8.encode('$command\n');
      await _rxChar!.write(bytes, withoutResponse: false);
    } catch (e) {
      debugPrint('[BLE Send Error]: $e');
    }
  }

  void _disconnectDevice() {
    _charSubscription?.cancel();
    _charSubscription = null;
    _bleDevice?.disconnect().catchError((_) {});
    _bleDevice = null;
    _rxChar = null;
    _bleBuffer = '';
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _isConnected = false;
    _connectedDevice = null;
    _rpm = 0.0;
    _speed = 0.0;
    _rpmHistory.clear();
    _speedHistory.clear();
    notifyListeners();
  }

  void _evaluateInterTripDelta() {
    _interTripDriftWarnings.clear();
    if (_previousTripBaseline == null) return;

    final double prevBat = _previousTripBaseline!['restingBattery'] ?? 12.8;
    final double prevClt = _previousTripBaseline!['averageCoolant'] ?? 91.5;

    if (prevBat - 12.2 > 0.5) {
      _interTripDriftWarnings.add('Resting battery dropped 0.6V since last trip (Parasitic drain check advised).');
    }
    if ((_coolantTemp - prevClt).abs() > 8.0) {
      _interTripDriftWarnings.add('Warm-up coolant variance +8°C compared to previous trip.');
    }
  }

  void _startLiveTelemetry() {
    _telemetryTimer?.cancel();
    final random = Random();

    _rpmHistory.clear();
    _speedHistory.clear();
    for (int i = 0; i < 15; i++) {
      _rpmHistory.add(1040.0 + random.nextInt(20));
      _speedHistory.add(0.0);
    }

    bool _o2Rich = false;
    int _o2Ticker = 0;

    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!_isConnected) return;

      // Toggle O2 sensor rich/lean every ~1.2 seconds (simulates narrowband switching)
      _o2Ticker++;
      if (_o2Ticker >= 2) {
        _o2Ticker = 0;
        _o2Rich = !_o2Rich;
      }

      // Build a realistic idle packet identical to what the ESP32 transmits
      final int rpm = 1050 + random.nextInt(15);
      final double eot = 87.8 + (random.nextDouble() * 0.4);
      final double bat = 14.07 + (random.nextDouble() * 0.06);
      final double stft = 2.1 + (random.nextDouble() * 0.5);
      final double o2 = _o2Rich ? (0.72 + random.nextDouble() * 0.13) : (0.22 + random.nextDouble() * 0.15);

      final String packet =
          'VIN:ME3J350CAN2026VIN;'
          'RPM:$rpm;'
          'SPD:0.0;'
          'TPS:2.1;'
          'MAP:34.0;'
          'IAT:31.0;'
          'EOT:${eot.toStringAsFixed(1)};'
          'O2:${o2.toStringAsFixed(2)};'
          'STFT:+${stft.toStringAsFixed(1)};'
          'LTFT:+1.8;'
          'BAT:${bat.toStringAsFixed(2)};'
          'GEAR:N;'
          'CLUTCH:0;'
          'SIDE_STAND:0;'
          'F_WHEEL:0.0;'
          'R_WHEEL:0.0;'
          'DTC:NO FAULT';

      // Route through the same parser — this populates rawTerminalLogs AND drives the dashboard
      parseIncomingBluetoothPacket(packet);

      _cloudSyncedPackets += 1;
      _cloudStorageUsedMb = (_cloudSyncedPackets * 0.0018).clamp(0.1, 24.5);

      _db.insertTelemetryPoint(
        rpm: _rpm,
        speed: _speed,
        coolantTemp: _coolantTemp,
        batteryVoltage: _batteryVoltage,
        fuelTrim: _fuelTrim,
        triageLevel: _triageLevel,
        failureProbability: _failureProbability,
      );
    });
  }

  void injectDemoFault(String code, String desc, String severity) {
    if (!_activeFaults.any((f) => f['code'] == code)) {
      _activeFaults.add({
        'code': code,
        'description': desc,
        'severity': severity,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _dtcCount = _activeFaults.length;
      notifyListeners();
    }
  }

  void parseIncomingBluetoothPacket(String rawPacket) {
    final clean = rawPacket.trim();
    if (clean.isEmpty) return;

    // 1. Store in real-time terminal monitor buffer
    _rawTerminalLogs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $clean');
    if (_rawTerminalLogs.length > 80) _rawTerminalLogs.removeAt(0);

    try {
      // Format A: Standard JSON Payload (e.g. {"rpm":2400,"speed":10.0,"tps":8.5,"map":42,"coolant":88.5,...})
      if (clean.startsWith('{') && clean.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(clean);
        if (data.containsKey('rpm')) _rpm = (data['rpm'] as num).toDouble();
        if (data.containsKey('speed')) _speed = (data['speed'] as num).toDouble();
        if (data.containsKey('coolant')) _coolantTemp = (data['coolant'] as num).toDouble();
        if (data.containsKey('eot')) _eot = (data['eot'] as num).toDouble();
        if (data.containsKey('iat')) _iat = (data['iat'] as num).toDouble();
        if (data.containsKey('tps')) _tps = (data['tps'] as num).toDouble();
        if (data.containsKey('map')) _mapKpa = (data['map'] as num).toDouble();
        if (data.containsKey('o2')) _o2Voltage = (data['o2'] as num).toDouble();
        if (data.containsKey('voltage')) _batteryVoltage = (data['voltage'] as num).toDouble();
        if (data.containsKey('fuelTrim')) _fuelTrim = (data['fuelTrim'] as num).toDouble();
        if (data.containsKey('stft')) _fuelTrim = (data['stft'] as num).toDouble();
        if (data.containsKey('ltft')) _ltft = (data['ltft'] as num).toDouble();
        if (data.containsKey('gear')) _gear = data['gear'].toString();
        if (data.containsKey('f_wheel')) _frontWheelSpeed = (data['f_wheel'] as num).toDouble();
        if (data.containsKey('r_wheel')) _rearWheelSpeed = (data['r_wheel'] as num).toDouble();

        if (data.containsKey('vin')) {
          _vehicleVin = data['vin'].toString();
          _vehicleType = _detectVehicleType(_vehicleVin, _vehicleName);
        }
        if (data.containsKey('dtc') && data['dtc'].toString() != 'NONE' && data['dtc'].toString() != 'NO FAULT' && data['dtc'].toString().isNotEmpty) {
          injectDemoFault(data['dtc'].toString(), 'Active Powertrain Fault', 'MEDIUM');
        }
      }
      // Format B: Full Royal Enfield Semicolon Key-Value Protocol
      else if (clean.contains(';') || clean.contains(':')) {
        final parts = clean.split(';');
        for (final part in parts) {
          if (!part.contains(':')) continue;
          final kv = part.split(':');
          if (kv.length != 2) continue;
          final key = kv[0].trim().toUpperCase();
          final val = kv[1].trim();

          switch (key) {
            case 'VIN':
              _vehicleVin = val;
              _vehicleType = _detectVehicleType(_vehicleVin, _vehicleName);
              break;
            case 'RPM':
              _rpm = double.tryParse(val) ?? _rpm;
              break;
            case 'SPD':
            case 'SPEED':
              _speed = double.tryParse(val) ?? _speed;
              break;
            case 'TPS':
              _tps = double.tryParse(val) ?? _tps;
              break;
            case 'MAP':
              _mapKpa = double.tryParse(val) ?? _mapKpa;
              break;
            case 'IAT':
              _iat = double.tryParse(val) ?? _iat;
              break;
            case 'EOT':
            case 'CLT':
            case 'COOLANT':
              _coolantTemp = double.tryParse(val) ?? _coolantTemp;
              _eot = _coolantTemp;
              break;
            case 'O2':
              _o2Voltage = double.tryParse(val) ?? _o2Voltage;
              break;
            case 'STFT':
              _fuelTrim = double.tryParse(val.replaceAll('+', '')) ?? _fuelTrim;
              break;
            case 'LTFT':
              _ltft = double.tryParse(val.replaceAll('+', '')) ?? _ltft;
              break;
            case 'BAT':
            case 'VOLTAGE':
              _batteryVoltage = double.tryParse(val) ?? _batteryVoltage;
              break;
            case 'GEAR':
              _gear = val;
              break;
            case 'CLUTCH':
              _clutchReleased = val == '0' || val.toLowerCase().contains('released');
              break;
            case 'SIDE_STAND':
              _sideStandUp = val == '0' || val.toLowerCase().contains('up');
              break;
            case 'F_WHEEL':
              _frontWheelSpeed = double.tryParse(val) ?? _frontWheelSpeed;
              break;
            case 'R_WHEEL':
              _rearWheelSpeed = double.tryParse(val) ?? _rearWheelSpeed;
              break;
            case 'DTC':
              if (val != 'NONE' && val != 'NO FAULT' && val.isNotEmpty) {
                injectDemoFault(val, 'Active Powertrain Fault', 'MEDIUM');
              }
              break;
          }
        }
      }
      // Format C: Raw CAN CSV Frame (e.g. 1702,0x7E8,8,04,41,0C,1A,F8,00,00,00)
      else if (clean.contains(',')) {
        final parts = clean.split(',');
        if (parts.length >= 7) {
          final id = parts[1].trim().toLowerCase();
          if (id.contains('7e8') || id.contains('201') || id.contains('7e0')) {
            final p1 = parts[3].trim().toUpperCase();
            final p2 = parts[4].trim().toUpperCase();
            if (p1 == '41' && p2 == '0C') {
              final a = int.tryParse(parts[5].trim(), radix: 16) ?? 0;
              final b = int.tryParse(parts[6].trim(), radix: 16) ?? 0;
              _rpm = ((a * 256) + b) / 4.0;
            }
          }
        }
      }

      // Record graph history
      _rpmHistory.add(_rpm);
      if (_rpmHistory.length > 25) _rpmHistory.removeAt(0);
      _speedHistory.add(_speed);
      if (_speedHistory.length > 25) _speedHistory.removeAt(0);

      _cloudSyncedPackets += 1;
      _cloudStorageUsedMb = (_cloudSyncedPackets * 0.0018).clamp(0.1, 24.5);

      // Physics-Calibrated AI Triage Evaluation (Royal Enfield J-Series 349cc)
      final double totalTrim = _fuelTrim + _ltft;
      final double vacRatio = _mapKpa / (_tps + 1.0);

      if (_coolantTemp > 115.0 || _batteryVoltage < 11.0 || _activeFaults.length >= 3) {
        _triageLevel = 'CRITICAL';
        _failureProbability = 0.92;
        _remainingUsefulLifeHours = 8.0;
      } else if (_coolantTemp > 108.0 || _batteryVoltage < 11.8 || totalTrim > 18.0 || vacRatio > 20.0 || _activeFaults.isNotEmpty) {
        _triageLevel = 'MEDIUM';
        _failureProbability = 0.65;
        _remainingUsefulLifeHours = 48.0;
      } else {
        _triageLevel = 'LOW';
        _failureProbability = 0.04;
        _remainingUsefulLifeHours = 950.0;
      }

      _db.insertTelemetryPoint(
        rpm: _rpm,
        speed: _speed,
        coolantTemp: _coolantTemp,
        batteryVoltage: _batteryVoltage,
        fuelTrim: _fuelTrim,
        triageLevel: _triageLevel,
        failureProbability: _failureProbability,
      );

      notifyListeners();

      // Trigger debounced live ML prediction on backend
      _dispatchLivePrediction();
    } catch (e) {
      debugPrint('[Telemetry Parser Error]: ' + e.toString());
    }
  }

  Future<void> _dispatchLivePrediction() async {
    final now = DateTime.now();
    // Debounce: send snapshot to ML backend at most once every 3.5 seconds
    if (_isPredicting) return;
    if (_lastPredictionTime != null &&
        now.difference(_lastPredictionTime!).inMilliseconds < 3500) {
      return;
    }
    _isPredicting = true;
    _lastPredictionTime = now;

    try {
      final telemetrySnapshot = {
        'rpm': _rpm,
        'speed': _speed,
        'throttle_pos': _tps,
        'tps': _tps,
        'map_kpa': _mapKpa,
        'map': _mapKpa,
        'iat': _iat,
        'coolant_temp': _coolantTemp,
        'eot': _eot,
        'o2_voltage': _o2Voltage,
        'fuel_trim': _fuelTrim,
        'stft': _fuelTrim,
        'ltft': _ltft,
        'voltage': _batteryVoltage,
        'battery_voltage': _batteryVoltage,
        'bat': _batteryVoltage,
        'gear': _gear,
        'dtc_count': _dtcCount,
        'vehicle_id': 1
      };

      final result = await _api.getPrediction(telemetrySnapshot);
      if (result != null) {
        _triageLevel = result.triageLevel;
        _failureProbability = result.failureProbability;
        _remainingUsefulLifeHours = result.remainingUsefulLifeHours;
        _diagnosticExplanation = result.explanation;
        _predictedFaultClass = result.predictedFaultClass;
        _modelVersion = result.modelVersion;
        if (result.engineeredFeatures != null) {
          _engineeredFeatures = result.engineeredFeatures!;
        }

        // Merge any server-detected active DTCs
        if (result.activeDtcs != null && result.activeDtcs!.isNotEmpty) {
          for (var dtc in result.activeDtcs!) {
            if (dtc is Map) {
              final code = dtc['code']?.toString() ?? '';
              final title = dtc['title']?.toString() ?? 'Fault detected';
              final sev = dtc['severity']?.toString() ?? 'HIGH';
              if (code.isNotEmpty) injectDemoFault(code, title, sev);
            }
          }
        }

        // Check emergency SMS alert trigger
        if ((_triageLevel == 'CRITICAL' || _triageLevel == 'HIGH') && _criticalSmsAlerts) {
          _triggerEmergencyAlert(_diagnosticExplanation);
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Prediction Dispatch Error]: $e');
    } finally {
      _isPredicting = false;
    }
  }

  void _triggerEmergencyAlert(String message) {
    final now = DateTime.now();
    // Throttle emergency alerts to once every 10 minutes max
    if (_lastAlertDispatchTime != null &&
        now.difference(_lastAlertDispatchTime!).inMinutes < 10) {
      return;
    }
    _lastAlertDispatchTime = now;

    if (_phoneNumber.trim().isNotEmpty) {
      FirebaseOtpService().sendEmergencySmsAlert(_phoneNumber, message);
    }
  }

  void clearAllFaults() {
    _activeFaults.clear();
    _dtcCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    super.dispose();
  }
}
