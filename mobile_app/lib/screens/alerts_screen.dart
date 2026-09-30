import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/pdf_report_service.dart';

class AlertsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const AlertsScreen({super.key, this.onOpenDrawer});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isGeneratingPdf = false;

  Color _getTriageColor(String triage) {
    switch (triage.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFFF7675);
      case 'MEDIUM':
        return const Color(0xFFFDCB6E);
      case 'LOW':
      default:
        return const Color(0xFF00B894);
    }
  }

  void _showDiagnosticReportModal(BuildContext context, AppStateProvider provider) {
    // 1. FREEZE IMMUTABLE STATIC SNAPSHOT AT TIME OF OPENING
    final snapshot = DiagnosticSnapshot.fromProvider(provider);
    final triage = snapshot.triageLevel;
    final Color triageColor = _getTriageColor(triage);
    final int score = ((1.0 - snapshot.failureProbability) * 100).toInt().clamp(5, 99);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              builder: (_, controller) => SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5E73),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.description_rounded,
                                  color: Color(0xFF6C5CE7), size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Diagnostic Health Report',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: triageColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: triageColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '$triage RISK',
                            style: TextStyle(
                                color: triageColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('ID: ${snapshot.reportId}',
                            style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                        Text('Captured: ${snapshot.generatedTimestamp}',
                            style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Static Vehicle Profile Specs
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0E15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF232736)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildReportSpec('VEHICLE', snapshot.vehicleName),
                              _buildReportSpec('TYPE', snapshot.vehicleType),
                              _buildReportSpec('ODOMETER', '${snapshot.odometerKm} km'),
                            ],
                          ),
                          const Divider(color: Color(0xFF232736), height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildReportSpec('HEALTH SCORE', '$score / 100', color: triageColor),
                              _buildReportSpec(
                                  'FAIL PROBABILITY',
                                  '${(snapshot.failureProbability * 100).toStringAsFixed(1)}%',
                                  color: triageColor),
                              _buildReportSpec(
                                  'ESTIMATED RUL',
                                  '${snapshot.remainingUsefulLifeHours.toStringAsFixed(1)} hrs',
                                  color: const Color(0xFF6C5CE7)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Static Sensor Health Matrix
                    const Text(
                      'CAPTURED SENSOR TELEMETRY READINGS (STATIC SNAPSHOT)',
                      style: TextStyle(
                          color: Color(0xFF8E92A4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 10),
                    _buildReportSensorRow(
                      'Cooling & Thermostat System',
                      '${snapshot.coolantTemp.toStringAsFixed(1)} °C',
                      snapshot.coolantTemp > 105 ? 'CRITICAL THERMAL' : 'NOMINAL (85-102°C)',
                      snapshot.coolantTemp > 105 ? const Color(0xFFFF7675) : const Color(0xFF00B894),
                    ),
                    _buildReportSensorRow(
                      'Alternator & Battery Rail',
                      '${snapshot.batteryVoltage.toStringAsFixed(2)} V',
                      snapshot.batteryVoltage < 12.0 ? 'VOLTAGE SAG' : 'NOMINAL (12.4-14.5V)',
                      snapshot.batteryVoltage < 12.0
                          ? const Color(0xFFFF7675)
                          : const Color(0xFF00B894),
                    ),
                    _buildReportSensorRow(
                      'Fuel Trim / Lambda Sensor',
                      '${snapshot.fuelTrim >= 0 ? '+' : ''}${snapshot.fuelTrim.toStringAsFixed(1)} %',
                      snapshot.fuelTrim.abs() > 10.0 ? 'LEAN/RICH DRIFT' : 'BALANCED (±5%)',
                      snapshot.fuelTrim.abs() > 10.0
                          ? const Color(0xFFFDCB6E)
                          : const Color(0xFF00B894),
                    ),
                    _buildReportSensorRow(
                      'Engine RPM & Valve Timing',
                      '${snapshot.rpm.toInt()} RPM',
                      'STABLE IDLE / CRUISE',
                      const Color(0xFF00B894),
                    ),
                    const SizedBox(height: 20),

                    // Static Inter-Trip Delta Baseline
                    const Text(
                      'INTER-TRIP DELTA DRIFT (BETWEEN KEY CYCLES)',
                      style: TextStyle(
                          color: Color(0xFF8E92A4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0E15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF232736)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.interTripWarnings.isEmpty)
                            const Text(
                              '✓ No significant inter-trip baseline drift detected since last ride.',
                              style: TextStyle(color: Color(0xFF00B894), fontSize: 12),
                            )
                          else
                            ...snapshot.interTripWarnings.map((w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: Color(0xFFFDCB6E), size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(w,
                                            style: const TextStyle(
                                                color: Color(0xFFFDCB6E), fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Real Static PDF Downloader Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingPdf
                            ? null
                            : () async {
                                setModalState(() => _isGeneratingPdf = true);
                                setState(() => _isGeneratingPdf = true);
                                try {
                                  await PdfReportService.downloadStaticPdf(snapshot);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✓ PDF Report downloaded: ${snapshot.reportId}.pdf'),
                                        backgroundColor: const Color(0xFF00B894),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('PDF download error: $e');
                                } finally {
                                  if (mounted) {
                                    setModalState(() => _isGeneratingPdf = false);
                                    setState(() => _isGeneratingPdf = false);
                                  }
                                }
                              },
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download_for_offline_rounded, color: Colors.white, size: 22),
                        label: Text(
                          _isGeneratingPdf
                              ? 'Saving Real PDF File...'
                              : 'Download Real Diagnostic PDF File',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B894),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildReportSpec(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  static Widget _buildReportSensorRow(
      String component, String reading, String status, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF232736)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(component,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Text(reading,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final String triage = provider.triageLevel;
    final Color triageColor = _getTriageColor(triage);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Fault Alerts & Triage',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: triageColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: triageColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: triageColor),
                ),
                const SizedBox(width: 6),
                Text(
                  '$triage TRIAGE',
                  style: TextStyle(color: triageColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Triage Risk Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: triageColor.withValues(alpha: 0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: triageColor.withValues(alpha: 0.15),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              triage == 'CRITICAL'
                                  ? Icons.error_rounded
                                  : (triage == 'MEDIUM'
                                      ? Icons.warning_rounded
                                      : Icons.check_circle_rounded),
                              color: triageColor,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              triage == 'CRITICAL'
                                  ? 'CRITICAL BREAKDOWN RISK'
                                  : (triage == 'MEDIUM'
                                      ? 'MEDIUM MAINTENANCE ALERT'
                                      : 'NOMINAL OPERATING CONDITION'),
                              style: TextStyle(
                                  color: triageColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      triage == 'CRITICAL'
                          ? 'Sensors indicate severe abnormal thermal runaway or critical electrical voltage loss. Stop vehicle safely.'
                          : (triage == 'MEDIUM'
                              ? 'Sensor baseline drift or minor fault detected. Preventive maintenance recommended.'
                              : 'All powertrain components, thermals, and voltages are running within nominal manufacturer limits.'),
                      style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTriageStat('Active DTC Codes', '${provider.dtcCount} Faults'),
                        _buildTriageStat(
                            'Failure Probability',
                            '${(provider.failureProbability * 100).toStringAsFixed(1)}%',
                            color: triageColor),
                        _buildTriageStat('Estimated RUL',
                            '${provider.remainingUsefulLifeHours.toStringAsFixed(1)} hrs'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // GENERATE REAL DIAGNOSTIC REPORT BUTTON
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _showDiagnosticReportModal(context, provider),
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                  label: const Text('Generate Real Diagnostic Report (PDF)',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Active DTC List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ACTIVE DIAGNOSTIC TROUBLE CODES',
                      style: TextStyle(
                          color: Color(0xFF8E92A4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                  if (provider.activeFaults.isNotEmpty)
                    TextButton(
                      onPressed: () => provider.clearAllFaults(),
                      child: const Text('Clear All',
                          style: TextStyle(color: Color(0xFFFF7675), fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (provider.activeFaults.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF232736)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.verified_rounded, color: Color(0xFF00B894), size: 40),
                      SizedBox(height: 12),
                      Text('No Faults Detected',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 4),
                      Text('OBD-II continuous monitor reported zero active DTC triggers.',
                          style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                    ],
                  ),
                )
              else
                ...provider.activeFaults.map(
                  (f) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF7675).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.warning_rounded,
                              color: Color(0xFFFF7675), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(f['code'] ?? 'DTC',
                                      style: const TextStyle(
                                          color: Color(0xFFFF7675),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7675).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      f['severity'] ?? 'FAULT',
                                      style: const TextStyle(
                                          color: Color(0xFFFF7675),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(f['description'] ?? 'Powertrain fault detected.',
                                  style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Workbench Fault Simulator
              const Text('WORKBENCH FAULT INJECTION SIMULATOR',
                  style: TextStyle(
                      color: Color(0xFF8E92A4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => provider.injectDemoFault(
                          'P0217', 'Engine Coolant Over-Temperature Condition', 'CRITICAL'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF7675)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('+ P0217 Overheat',
                          style: TextStyle(
                              color: Color(0xFFFF7675), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => provider.injectDemoFault(
                          'P0171', 'System Too Lean (Bank 1 Sensor 1)', 'MEDIUM'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDCB6E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('+ P0171 Lean Fuel',
                          style: TextStyle(
                              color: Color(0xFFFDCB6E), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriageStat(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
