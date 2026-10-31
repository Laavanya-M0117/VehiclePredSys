import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/app_state_provider.dart';
import 'device_login_screen.dart';
import 'device_registration_screen.dart';
import 'main_navigation_shell.dart';

class BlePairingScreen extends StatefulWidget {
  const BlePairingScreen({super.key});

  @override
  State<BlePairingScreen> createState() => _BlePairingScreenState();
}

class _BlePairingScreenState extends State<BlePairingScreen> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  bool _isScanning = false;
  final List<Map<String, String>> _discoveredDevices = [];

  @override
  void initState() {
    super.initState();
    // Hardware list starts empty - only Workbench Simulation is shown until real device pairs
    _initBluetooth();
  }

  void _initBluetooth() {
    _adapterSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
        if (!kIsWeb && state == BluetoothAdapterState.on && _discoveredDevices.isEmpty) {
          _fetchBondedAndScan();
        }
      }
    });

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      for (ScanResult r in results) {
        final name = r.device.platformName.trim().isNotEmpty
            ? r.device.platformName
            : (r.advertisementData.advName.trim().isNotEmpty
                ? r.advertisementData.advName
                : 'BLE Device (${r.device.remoteId.str.length > 5 ? r.device.remoteId.str.substring(0, 5) : r.device.remoteId.str})');
        final id = r.device.remoteId.str;
        final rssi = '${r.rssi} dBm';

        if (!_discoveredDevices.any((d) => d['id'] == id)) {
          setState(() {
            _discoveredDevices.add({
              'name': name,
              'id': id,
              'rssi': rssi,
              'isReal': 'true',
              'isBonded': 'false',
            });
          });
        }
      }
    });
  }

  void _fetchBondedAndScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.removeWhere((d) => d['isReal'] == 'true' && d['isHc05'] != 'true');
    });

    // 1. First fetch bonded/paired system devices (already paired in Android Bluetooth)
    try {
      if (!kIsWeb) {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (var dev in bonded) {
          final name = dev.platformName.trim().isNotEmpty ? dev.platformName : 'Paired OBD Device';
          final id = dev.remoteId.str;
          if (!_discoveredDevices.any((d) => d['id'] == id)) {
            _discoveredDevices.add({
              'name': name,
              'id': id,
              'rssi': 'PAIRED',
              'isReal': 'true',
              'isBonded': 'true',
            });
          }
        }

        final systemDevs = await FlutterBluePlus.systemDevices([]);
        for (var dev in systemDevs) {
          final name = dev.platformName.trim().isNotEmpty ? dev.platformName : 'Connected Device';
          final id = dev.remoteId.str;
          if (!_discoveredDevices.any((d) => d['id'] == id)) {
            _discoveredDevices.add({
              'name': name,
              'id': id,
              'rssi': 'CONNECTED',
              'isReal': 'true',
              'isBonded': 'true',
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[Bluetooth Bonded Fetch Error]: $e');
    }

    if (mounted) setState(() {});

    // 2. Start active live scan for new peripherals
    if (_adapterState != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint('[Bluetooth TurnOn Error]: $e');
      }
    }

    try {
      // First: scan specifically for NUS-based VETRI-OBD ESP32 devices (fast, targeted)
      await FlutterBluePlus.startScan(
        withServices: [Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E')],
        timeout: const Duration(seconds: 6),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('[BLE NUS Scan Error — trying generic scan]: $e');
    }

    // Then: broad scan for ELM327/OBDLink/commercial adapters
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint('[Bluetooth Scan Error]: $e');
    }

    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  void _showManualPairDialog() {
    final nameCtrl = TextEditingController(text: 'HC-05');
    final macCtrl = TextEditingController(text: '20:25:08:00:1C:89');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.bluetooth_connected_rounded, color: Color(0xFF00B894)),
            SizedBox(width: 8),
            Text('Direct Device Connect',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Bluetooth Name or MAC identifier of your ESP32 module to connect directly:',
              style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Bluetooth Name',
                labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                hintText: 'HC-05 (Bluetooth Module)',
                hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                filled: true,
                fillColor: const Color(0xFF0D0E15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.label_outline_rounded, color: Color(0xFF6C5CE7)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: macCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Hardware ID / MAC (Optional)',
                labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                hintText: '20:25:08:00:1C:89 (Bluetooth MAC)',
                hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                filled: true,
                fillColor: const Color(0xFF0D0E15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.memory_rounded, color: Color(0xFF00B894)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E92A4))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final devName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'HC-05';
              final devId = macCtrl.text.trim().isNotEmpty ? macCtrl.text.trim() : '20:25:08:00:1C:89';
              final newDev = {
                'name': devName,
                'id': devId,
                'rssi': 'PAIRED (SPP)',
                'isReal': 'true',
                'isBonded': 'true',
              };
              if (!_discoveredDevices.any((d) => d['id'] == devId)) {
                setState(() => _discoveredDevices.add(newDev));
              }
              _connectDevice(newDev);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B894),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect Now',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _connectDevice(Map<String, String> device) async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final deviceId = device['id'] ?? 'unknown';

    // Workbench simulation connects directly
    if (deviceId.contains('DEMO')) {
      provider.connectToDevice(device);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
      return;
    }

    // Real hardware must undergo registration / security authentication
    final isBound = await provider.isDeviceBound(deviceId);
    if (!mounted) return;

    if (isBound) {
      final binding = await provider.getDeviceBinding(deviceId);
      final ownerEmail = binding?['email'] ?? binding?['user_identifier'] ?? '';
      final ownerPhone = binding?['phone'] ?? '';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceLoginScreen(
            device: device,
            boundEmail: ownerEmail,
            boundPhone: ownerPhone,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeviceRegistrationScreen(device: device),
        ),
      );
    }
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBtOff = _adapterState == BluetoothAdapterState.off;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // VETRI Branding Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.speed_rounded, color: Color(0xFF6C5CE7), size: 24),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'VETRI',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Vehicle Predictive Triage & Health Monitor',
                        style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                      ),
                    ],
                  ),
                  if (_isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C5CE7)),
                      onPressed: _fetchBondedAndScan,
                      tooltip: 'Rescan Devices',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Bluetooth Power State Banner if OFF
              if (isBtOff) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF7675), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_disabled_rounded,
                          color: Color(0xFFFF7675), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Bluetooth is Turned OFF',
                              style: TextStyle(
                                  color: Color(0xFFFF7675),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Please enable Bluetooth to pair with your ESP32 OBD-II module.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await FlutterBluePlus.turnOn();
                          } catch (e) {
                            debugPrint('Turn on error: $e');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7675),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('Turn ON',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Scanning Status Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'DISCOVERED OBD HARDWARE',
                        style: TextStyle(
                            color: Color(0xFF8E92A4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_discoveredDevices.length + 1}',
                          style: const TextStyle(
                              color: Color(0xFF6C5CE7),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showManualPairDialog,
                    icon: const Icon(Icons.add_link_rounded, color: Color(0xFF00B894), size: 16),
                    label: const Text('Pair Hardware',
                        style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Device List
              Expanded(
                child: ListView(
                  children: [
                    if (_discoveredDevices.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161922).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF232736)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth_searching_rounded, color: Color(0xFF8E92A4), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('No Real Hardware Paired Yet',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 2),
                                  Text('Tap "Pair Hardware" above to link your HC-05 (20:25:08:00:1C:89), or tap Workbench Simulation below.',
                                      style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // REAL PAIRED / DISCOVERED HARDWARE MODULES
                    ..._discoveredDevices.map((d) {
                      final bool isBonded = d['isBonded'] == 'true';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161922),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isBonded
                                ? const Color(0xFF00B894).withValues(alpha: 0.6)
                                : const Color(0xFF232736),
                            width: isBonded ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _connectDevice(d),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isBonded
                                          ? const Color(0xFF00B894).withValues(alpha: 0.15)
                                          : const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.bluetooth_connected_rounded,
                                      color: isBonded
                                          ? const Color(0xFF00B894)
                                          : const Color(0xFF6C5CE7),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                d['name'] ?? 'OBD Device',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isBonded) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00B894)
                                                      .withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text('PAIRED',
                                                    style: TextStyle(
                                                        color: Color(0xFF00B894),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${d['id']} • Signal: ${d['rssi']}',
                                          style: const TextStyle(
                                              color: Color(0xFF8E92A4), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      color: Color(0xFF8E92A4), size: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // WORKBENCH DEMO MODULE (Always available for testing)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161922),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF232736)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _connectDevice({
                            'name': 'Workbench Demo OBD-II Module',
                            'id': 'ESP32-OBD-VETRI-DEMO',
                            'rssi': '-42 dBm',
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDCB6E).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.science_rounded,
                                      color: Color(0xFFFDCB6E), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Workbench Demo Module',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFDCB6E)
                                                  .withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('EMULATOR',
                                                style: TextStyle(
                                                    color: Color(0xFFFDCB6E),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Simulates live engine telemetry stream without bike connection',
                                        style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios_rounded,
                                    color: Color(0xFF8E92A4), size: 14),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
