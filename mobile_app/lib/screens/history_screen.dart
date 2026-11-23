import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const HistoryScreen({super.key, this.onOpenDrawer});

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

  void _showTripDetailModal(BuildContext context, Map<String, dynamic> trip) {
    final int score = (trip['healthScore'] as num?)?.toInt() ?? 90;
    final String triage = trip['triage']?.toString() ?? 'LOW';
    final Color color = _getTriageColor(triage);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['route']?.toString() ?? 'Trip Details',
                        style: TextStyle(
                          color: AppColors.text(ctx),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip['date']} • ${trip['duration']}',
                        style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$triage RISK',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSubtle(ctx),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(ctx)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile(ctx, 'Distance', '${trip['distanceKm']} km', Icons.straighten_rounded),
                      _buildMetricTile(ctx, 'Duration', '${trip['duration']}', Icons.timer_outlined),
                      _buildMetricTile(ctx, 'Avg Speed', '${trip['avgSpeedKmh']} km/h', Icons.speed_rounded),
                    ],
                  ),
                  Divider(color: AppColors.border(ctx), height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetricTile(ctx, 'Peak RPM', '${trip['peakRpm']}', Icons.electric_bolt_rounded),
                      _buildMetricTile(ctx, 'Efficiency', '${trip['efficiency']}', Icons.local_gas_station_rounded),
                      _buildMetricTile(ctx, 'Health Score', '$score / 100', Icons.health_and_safety_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TRIP TELEMETRY OBSERVATIONS',
              style: TextStyle(color: AppColors.textSecondary(ctx), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSubtle(ctx),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(ctx)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Peak speed ${trip['peakSpeedKmh'] ?? '--'} km/h, peak engine speed ${trip['peakRpm']} RPM.',
                      style: const TextStyle(color: Color(0xFF00B894), fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('• Hard-braking events detected: ${trip['hardBrakes'] ?? 0}.',
                      style: const TextStyle(color: Color(0xFF00B894), fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('• Overall health outcome for this ride: $triage risk (score $score/100).',
                      style: TextStyle(color: color, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildMetricTile(BuildContext context, String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary(context), size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final trips = provider.tripHistory;
    final int avgScore = trips.isEmpty
        ? 0
        : (trips.fold<num>(0, (a, t) => a + ((t['healthScore'] as num?) ?? 90)) / trips.length).round();
    final int criticalTrips = trips.where((t) => t['triage'] == 'CRITICAL').length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: AppColors.icon(context), size: 26),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: Text('History',
            style: TextStyle(color: AppColors.text(context), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFF6C5CE7), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${trips.length} Trips',
                  style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 12),
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
              // Incomplete profile reminder banner if phone/email missing
              if (provider.isProfileIncomplete) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDCB6E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFFDCB6E), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Complete Profile Required',
                              style: TextStyle(
                                  color: Color(0xFFFDCB6E), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Missing: ${provider.missingProfileFields.join(", ")}. Tap profile to complete.',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Live trip-in-progress banner
              if (provider.tripActive) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00B894).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00B894)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF00B894), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Trip in progress • ${provider.currentTripKm.toStringAsFixed(2)} km • ${provider.currentTripDuration.inMinutes} min',
                          style: const TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Aggregate Stats Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('TOTAL RECORDED DISTANCE',
                            style: TextStyle(
                                color: Color(0xFF8E92A4), fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('VEHICLE HEALTH AVG',
                            style: TextStyle(
                                color: Color(0xFF8E92A4), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${provider.totalRecordedKm.toStringAsFixed(1)} km',
                            style: TextStyle(
                                color: AppColors.text(context), fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(trips.isEmpty ? '-- / 100' : '$avgScore / 100',
                            style: const TextStyle(
                                color: Color(0xFF00B894), fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: AppColors.border(context)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text('${trips.length} trips logged • ${provider.odometerKm} km odometer',
                              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        Text('$criticalTrips critical trips',
                            style: TextStyle(
                                color: criticalTrips == 0 ? const Color(0xFF00B894) : const Color(0xFFFF7675),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('RECORDED TRIPS & TELEMETRY LOGS',
                  style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              const SizedBox(height: 12),

              if (trips.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.route_outlined, color: Color(0xFF5A5E73), size: 40),
                      const SizedBox(height: 12),
                      Text('No Trips Recorded Yet',
                          style: TextStyle(
                              color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Start your bike with VETRI OBD connected to log your first ride.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                    ],
                  ),
                )
              else
                ...trips.map(
                  (t) {
                    final int score = (t['healthScore'] as num?)?.toInt() ?? 90;
                    final String triage = t['triage']?.toString() ?? 'LOW';
                    final Color color = _getTriageColor(triage);

                    return GestureDetector(
                      onTap: () => _showTripDetailModal(context, t),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.navigation_rounded,
                                            color: Color(0xFF6C5CE7), size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t['route']?.toString() ?? 'Commute',
                                              style: TextStyle(
                                                  color: AppColors.text(context),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${t['date']} • ${t['duration']}',
                                              style: TextStyle(
                                                  color: AppColors.textSecondary(context), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$score/100',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: AppColors.border(context)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildTripStat(context, 'Distance', '${t['distanceKm']} km'),
                                _buildTripStat(context, 'Avg Speed', '${t['avgSpeedKmh']} km/h'),
                                _buildTripStat(context, 'Peak RPM', '${t['peakRpm']}'),
                                _buildTripStat(context, 'Efficiency', '${t['efficiency']}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
