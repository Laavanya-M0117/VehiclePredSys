import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/rotating_wheel.dart';
import '../widgets/vehicle_speed_animation.dart';

class HomeDashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const HomeDashboardScreen({super.key, this.onOpenDrawer});

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon 🌤️';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening 🌆';
    } else {
      return 'Good night 🌙';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  void _showEditProfileDialog(BuildContext context, AppStateProvider provider) {
    final nameCtrl = TextEditingController(text: provider.displayName);
    final emailCtrl = TextEditingController(text: provider.userEmail);
    final phoneCtrl = TextEditingController(text: provider.phoneNumber);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF6C5CE7)),
              SizedBox(width: 8),
              Text('Complete Profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please provide your contact details to enable emergency SMS dispatch and automated diagnostic reports.',
                  style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                    filled: true,
                    fillColor: const Color(0xFF0D0E15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                    hintText: 'name@gmail.com',
                    hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                    filled: true,
                    fillColor: const Color(0xFF0D0E15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                    hintText: '+91 9876543210',
                    hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                    filled: true,
                    fillColor: const Color(0xFF0D0E15),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E92A4))),
            ),
            ElevatedButton(
              onPressed: () {
                provider.updateUserProfile(
                  nameCtrl.text.trim(),
                  emailCtrl.text.trim(),
                  newPhone: phoneCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully!'),
                    backgroundColor: Color(0xFF00B894),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showLiveSerialTerminalModal(BuildContext context, AppStateProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0C10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _LiveTerminalSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final String triage = provider.triageLevel;
    final int score = ((1.0 - provider.failureProbability) * 100).toInt().clamp(5, 99);

    Color triageColor = const Color(0xFF00B894);
    if (triage == 'HIGH' || triage == 'CRITICAL') {
      triageColor = const Color(0xFFFF7675);
    } else if (triage == 'MEDIUM') {
      triageColor = const Color(0xFFFDCB6E);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0E15),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getDynamicGreeting(),
                style: const TextStyle(
                    color: Color(0xFF8E92A4), fontSize: 11, fontWeight: FontWeight.w500)),
            Text(
              provider.displayName.isNotEmpty
                  ? provider.displayName.toUpperCase()
                  : 'VETRI DRIVER',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF6C5CE7), size: 22),
            tooltip: 'Prediction Server Settings',
            onPressed: () => _showServerConfigDialog(context, provider),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: RotatingWheelWidget(size: 24, color: triageColor),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live System Date Banner with Interactive Serial Terminal Opener
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Color(0xFF8E92A4), size: 14),
                        const SizedBox(width: 8),
                        Text(_getFormattedDate(),
                            style: const TextStyle(
                                color: Color(0xFFD1D5DB), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showLiveSerialTerminalModal(context, provider),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00B894).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration:
                                  const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00B894)),
                            ),
                            const SizedBox(width: 6),
                            const Text('OBD-II LIVE (TERMINAL)',
                                style: TextStyle(
                                    color: Color(0xFF00B894), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // PROFILE INCOMPLETE WARNING BANNER
              if (provider.isProfileIncomplete) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDCB6E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDCB6E), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDCB6E).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFDCB6E), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Profile Incomplete',
                                style: TextStyle(
                                    color: Color(0xFFFDCB6E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.missingProfileFields.join(", ")} required for SMS emergency alerts.',
                              style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showEditProfileDialog(context, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDCB6E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        child: const Text('Complete',
                            style: TextStyle(
                                color: Color(0xFF0D0E15), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Speed Trail Animated Card
              VehicleSpeedAnimation(
                speed: provider.speed,
                isMotorcycle: provider.vehicleName.toLowerCase().contains('bike') ||
                    provider.vehicleName.toLowerCase().contains('ktm') ||
                    provider.vehicleName.toLowerCase().contains('motorcycle'),
              ),
              const SizedBox(height: 16),

              // Glowing Vehicle Health Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF161922),
                      triageColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: triageColor.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: triageColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('OVERALL VEHICLE HEALTH',
                                style: TextStyle(
                                    color: Color(0xFF8E92A4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              triage == 'LOW'
                                  ? 'Optimal Condition'
                                  : (triage == 'MEDIUM' ? 'Check Advised' : 'Attention Needed'),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: triageColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$triage RISK',
                            style: TextStyle(
                                color: triageColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Health Ring
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CircularProgressIndicator(
                              value: score / 100.0,
                              strokeWidth: 12,
                              backgroundColor: const Color(0xFF232736),
                              valueColor: AlwaysStoppedAnimation<Color>(triageColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$score',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                              ),
                              const Text('/ 100',
                                  style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failure Probability: ${(provider.failureProbability * 100).toStringAsFixed(1)}%  •  Estimated RUL: ${provider.remainingUsefulLifeHours.toStringAsFixed(1)} hrs',
                      style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    // Diagnostic Explanation Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: triageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: triageColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                triage == 'LOW' ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                color: triageColor,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                provider.predictedFaultClass.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: triageColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                provider.modelVersion,
                                style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.diagnosticExplanation,
                            style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Sensor Tiles Grid
              const Text(
                'LIVE TELEMETRY READINGS',
                style: TextStyle(
                    color: Color(0xFF8E92A4),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricTile(
                    title: 'Engine RPM',
                    value: provider.rpm.toInt().toString(),
                    unit: 'RPM',
                    icon: Icons.speed_rounded,
                    color: const Color(0xFF6C5CE7),
                  ),
                  _buildMetricTile(
                    title: 'Coolant Temp',
                    value: provider.coolantTemp.toStringAsFixed(1),
                    unit: '°C',
                    icon: Icons.thermostat_rounded,
                    color: provider.coolantTemp > 105
                        ? const Color(0xFFFF7675)
                        : const Color(0xFF00B894),
                  ),
                  _buildMetricTile(
                    title: 'Battery Voltage',
                    value: provider.batteryVoltage.toStringAsFixed(2),
                    unit: 'V',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFDCB6E),
                  ),
                  _buildMetricTile(
                    title: 'Fuel Trim (STFT)',
                    value:
                        '${provider.fuelTrim >= 0 ? '+' : ''}${provider.fuelTrim.toStringAsFixed(1)}',
                    unit: '%',
                    icon: Icons.local_gas_station_rounded,
                    color: const Color(0xFFA29BFE),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // AI PREDICTIVE MAINTENANCE & COMPONENT WEAR ADVISORY
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI PREDICTIVE MAINTENANCE & COMPONENT LIFE',
                        style: TextStyle(
                            color: Color(0xFF8E92A4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Component 1: Cooling System
                    _buildAiComponentRow(
                      context,
                      title: 'Cooling & Radiator System',
                      healthPct: provider.coolantTemp > 105 ? 42 : 94,
                      statusText: provider.coolantTemp > 105
                          ? 'Critical Thermal Strain — Coolant flush & thermostat test required immediately!'
                          : 'Nominal city thermal cycles • Recommended coolant flush in 3,200 km.',
                      icon: Icons.thermostat_rounded,
                      color: provider.coolantTemp > 105 ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    ),
                    const Divider(color: Color(0xFF232736), height: 20),

                    // Component 2: Battery & Alternator Stator
                    _buildAiComponentRow(
                      context,
                      title: 'Battery & Alternator Stator Rail',
                      healthPct: provider.batteryVoltage < 12.0 ? 38 : 98,
                      statusText: provider.batteryVoltage < 12.0
                          ? 'Voltage sag detected (${provider.batteryVoltage.toStringAsFixed(2)}V) — Charge battery or test alternator stator coil.'
                          : 'Charging current nominal at ${provider.batteryVoltage.toStringAsFixed(2)}V • Resting voltage baseline stable.',
                      icon: Icons.bolt_rounded,
                      color: provider.batteryVoltage < 12.0 ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    ),
                    const Divider(color: Color(0xFF232736), height: 20),

                    // Component 3: Air-Fuel Mixture & Throttle Body
                    _buildAiComponentRow(
                      context,
                      title: 'Fuel Injection & Lambda Trim (STFT)',
                      healthPct: provider.fuelTrim.abs() > 10.0 ? 65 : 91,
                      statusText: provider.fuelTrim.abs() > 10.0
                          ? 'Fuel trim drift (${provider.fuelTrim.toStringAsFixed(1)}%) — Clean throttle body & check air filter.'
                          : 'Air-fuel mixture balanced (${provider.fuelTrim >= 0 ? '+' : ''}${provider.fuelTrim.toStringAsFixed(1)}%) • Air filter inspection in 4,500 km.',
                      icon: Icons.local_gas_station_rounded,
                      color: provider.fuelTrim.abs() > 10.0 ? const Color(0xFFFDCB6E) : const Color(0xFF00B894),
                    ),
                    const Divider(color: Color(0xFF232736), height: 20),

                    // Component 4: Drive Chain & Brake Wear
                    _buildAiComponentRow(
                      context,
                      title: 'Brake Deceleration & Drive Chain Slack',
                      healthPct: 88,
                      statusText: 'Kinetic deceleration load nominal based on ${provider.tripHistory.length} recorded commutes • Clean & lube chain in 600 km.',
                      icon: Icons.settings_input_component_rounded,
                      color: const Color(0xFF6C5CE7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiComponentRow(
    BuildContext context, {
    required String title,
    required int healthPct,
    required String statusText,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            // Expanded prevents title from overflowing into health badge
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$healthPct%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          statusText,
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232736)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF8E92A4), fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showServerConfigDialog(BuildContext context, AppStateProvider provider) {
    final urlCtrl = TextEditingController(text: provider.currentServerUrl);
    String? statusMessage;
    bool isTesting = false;
    Color statusColor = Colors.white;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: const [
              Icon(Icons.cloud_sync_rounded, color: Color(0xFF6C5CE7)),
              SizedBox(width: 10),
              Text(
                'AI Prediction Server',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure the FastAPI ML backend endpoint for live predictive triage:',
                style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  labelStyle: const TextStyle(color: Color(0xFF8E92A4)),
                  hintText: 'http://192.168.1.100:8000',
                  hintStyle: const TextStyle(color: Color(0xFF5A5E73)),
                  filled: true,
                  fillColor: const Color(0xFF0D0E15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF6C5CE7), size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPresetChip('Emulator', 'http://10.0.2.2:8000', urlCtrl, setDialogState),
                  _buildPresetChip('Localhost', 'http://127.0.0.1:8000', urlCtrl, setDialogState),
                  _buildPresetChip('Hotspot / LAN', 'http://192.168.43.1:8000', urlCtrl, setDialogState),
                ],
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        statusColor == const Color(0xFF00B894) ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        statusMessage = 'Testing server latency...';
                        statusColor = const Color(0xFF8E92A4);
                      });
                      final target = urlCtrl.text.trim();
                      try {
                        final sw = Stopwatch()..start();
                        final res = await http.get(Uri.parse(target + '/health')).timeout(const Duration(seconds: 3));
                        sw.stop();
                        if (res.statusCode == 200) {
                          setDialogState(() {
                            isTesting = false;
                            statusMessage = 'Online! Latency: ${sw.elapsedMilliseconds} ms';
                            statusColor = const Color(0xFF00B894);
                          });
                        } else {
                          setDialogState(() {
                            isTesting = false;
                            statusMessage = 'HTTP ${res.statusCode}: Service unavailable.';
                            statusColor = const Color(0xFFFF7675);
                          });
                        }
                      } catch (e) {
                        setDialogState(() {
                          isTesting = false;
                          statusMessage = 'Connection failed. Verify server is running.';
                          statusColor = const Color(0xFFFF7675);
                        });
                      }
                    },
              child: const Text('Test Connection', style: TextStyle(color: Color(0xFF6C5CE7))),
            ),
            ElevatedButton(
              onPressed: () {
                final newUrl = urlCtrl.text.trim();
                if (newUrl.isNotEmpty) {
                  provider.setCustomServerUrl(newUrl);
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Server endpoint set to: $newUrl'),
                    backgroundColor: const Color(0xFF6C5CE7),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save & Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url, TextEditingController ctrl, StateSetter setDialogState) {
    return InkWell(
      onTap: () {
        ctrl.text = url;
        setDialogState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF232736),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ============================================================
// Live Serial Terminal Sheet — StatefulWidget with own timer
// Polls provider rawTerminalLogs every 500ms and auto-scrolls
// ============================================================
class _LiveTerminalSheet extends StatefulWidget {
  final AppStateProvider provider;
  const _LiveTerminalSheet({required this.provider});

  @override
  State<_LiveTerminalSheet> createState() => _LiveTerminalSheetState();
}

class _LiveTerminalSheetState extends State<_LiveTerminalSheet> {
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _refreshTimer;
  List<String> _logs = [];
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    // Snapshot immediately
    _logs = List<String>.from(widget.provider.rawTerminalLogs);
    // Poll every 500ms and rebuild with latest logs
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final latest = List<String>.from(widget.provider.rawTerminalLogs);
      setState(() => _logs = latest);
      if (_autoScroll && _scrollCtrl.hasClients && _logs.isNotEmpty) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF333846),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.terminal_rounded, color: Color(0xFF00FF88), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text('Live OBD Serial Terminal',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      // Auto-scroll toggle
                      GestureDetector(
                        onTap: () => setState(() => _autoScroll = !_autoScroll),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _autoScroll
                                ? const Color(0xFF00B894).withValues(alpha: 0.2)
                                : const Color(0xFF333846),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _autoScroll ? const Color(0xFF00B894) : const Color(0xFF555A6E),
                            ),
                          ),
                          child: Text(
                            _autoScroll ? '⬇ AUTO' : '⏸ PAUSED',
                            style: TextStyle(
                              color: _autoScroll ? const Color(0xFF00B894) : const Color(0xFF8E92A4),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00B894)),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(color: Color(0xFF00B894), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Device: ${widget.provider.connectedDevice?['name'] ?? "VETRI-OBD"} • '
                '${_logs.length} packets received • Protocol: CAN 500k',
                style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 11),
              ),
              const SizedBox(height: 12),
              // Terminal Screen
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF040608),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF232736)),
                  ),
                  child: _logs.isEmpty
                      ? const SingleChildScrollView(
                          child: Text(
                            '>>> VETRI OBD Serial Terminal ACTIVE\n'
                            '>>> Connect to VETRI-OBD via Bluetooth to begin\n'
                            '>>> Waiting for first packet...\n\n'
                            'Expected format (ESP32 → App):\n'
                            'RPM:1051;SPD:0.0;TPS:2.1;MAP:34.0;\n'
                            'IAT:31.0;EOT:87.8;O2:0.25;STFT:+2.5;\n'
                            'LTFT:+1.8;BAT:14.09;GEAR:N;DTC:NO FAULT',
                            style: TextStyle(
                                color: Color(0xFF00FF88),
                                fontFamily: 'monospace',
                                fontSize: 11,
                                height: 1.7),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: _logs.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(
                              _logs[i],
                              style: TextStyle(
                                // Alternate line shading for readability
                                color: i % 2 == 0
                                    ? const Color(0xFF00FF88)
                                    : const Color(0xFF00CC66),
                                fontFamily: 'monospace',
                                fontSize: 10.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              // Stats bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RPM: ${widget.provider.rpm.toStringAsFixed(0)}  '
                    'SPD: ${widget.provider.speed.toStringAsFixed(1)} km/h  '
                    'EOT: ${widget.provider.eot.toStringAsFixed(1)}°C',
                    style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'BAT: ${widget.provider.batteryVoltage.toStringAsFixed(2)}V',
                    style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Inject buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.provider.parseIncomingBluetoothPacket(
                          'RPM:3200;SPD:58.5;TPS:14.0;MAP:64.0;IAT:38.0;EOT:91.5;O2:0.71;STFT:+1.8;LTFT:+1.6;BAT:13.95;GEAR:3;CLUTCH:0;SIDE_STAND:0;F_WHEEL:58.5;R_WHEEL:58.5;DTC:NO FAULT'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6C5CE7)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Inject Cruising Packet',
                          style: TextStyle(color: Color(0xFFA29BFE), fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.provider.parseIncomingBluetoothPacket(
                          'RPM:1055;SPD:0.0;TPS:2.1;MAP:34.0;IAT:31.0;EOT:88.0;O2:0.35;STFT:+2.4;LTFT:+1.8;BAT:14.10;GEAR:N;CLUTCH:0;SIDE_STAND:0;F_WHEEL:0.0;R_WHEEL:0.0;DTC:NO FAULT'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00B894)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Inject Idle Packet',
                          style: TextStyle(color: Color(0xFF00B894), fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
