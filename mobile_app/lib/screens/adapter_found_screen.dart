import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'main_navigation_shell.dart';

class AdapterFoundScreen extends StatefulWidget {
  final Map<String, String> device;

  const AdapterFoundScreen({super.key, required this.device});

  @override
  State<AdapterFoundScreen> createState() => _AdapterFoundScreenState();
}

class _AdapterFoundScreenState extends State<AdapterFoundScreen> {
  bool _isConnecting = false;

  void _handleConnect() async {
    setState(() => _isConnecting = true);
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    bool connected = await provider.connectBleDevice(
      widget.device['id'] ?? 'BLE-ELM327',
      widget.device['name'] ?? 'ELM327 OBD-II',
    );
    setState(() => _isConnecting = false);

    if (connected && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Pair OBD-II Device', style: TextStyle(color: Colors.white, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00B894).withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0xFF00B894), width: 2),
                ),
                child: const Icon(
                  Icons.bluetooth_connected_rounded,
                  size: 44,
                  color: Color(0xFF00B894),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Adapter Found!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.device['name'] ?? 'ELM327 Bluetooth OBD-II Adapter',
                style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 14),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B894).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.bluetooth, color: Color(0xFF00B894), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.device['name'] ?? 'ELM327 OBD-II',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Signal ${widget.device['rssi']}  •  ${widget.device['protocol']}',
                                style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B894).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'READY',
                            style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xFF232736)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDetailItem('CHIP', widget.device['chip'] ?? 'ELM327'),
                        _buildDetailItem('PROTOCOL', 'ISO 15765'),
                        _buildDetailItem('BAUD', widget.device['baud'] ?? '500K'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF6C5CE7), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DETECTED VEHICLE', style: TextStyle(color: Color(0xFF5A5E73), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            provider.vehicleName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'VIN  •  ${provider.vehicleVin}',
                            style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF5A5E73)),
                  ],
                ),
              ),
              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isConnecting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Connect & Begin Monitoring',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF5A5E73), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
