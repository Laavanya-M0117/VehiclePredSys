import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state_provider.dart';
import '../widgets/rotating_wheel.dart';
import '../theme/app_colors.dart';

class DiagnosticsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  const DiagnosticsScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final int currentRpm = provider.rpm.toInt();
    final int currentSpeed = provider.speed.toInt();
    final double currentCoolant = provider.coolantTemp;
    final double currentVoltage = provider.batteryVoltage;
    final double fuelTrim = provider.fuelTrim;

    final List<FlSpot> rpmSpots = [];
    for (int i = 0; i < provider.rpmHistory.length; i++) {
      rpmSpots.add(FlSpot(i.toDouble(), provider.rpmHistory[i]));
    }
    if (rpmSpots.isEmpty) {
      rpmSpots.addAll(const [FlSpot(0, 0), FlSpot(1, 0)]);
    }

    final List<FlSpot> speedSpots = [];
    for (int i = 0; i < provider.speedHistory.length; i++) {
      speedSpots.add(FlSpot(i.toDouble(), provider.speedHistory[i]));
    }
    if (speedSpots.isEmpty) {
      speedSpots.addAll(const [FlSpot(0, 0), FlSpot(1, 0)]);
    }

    // Battery voltage: only real readings are plotted; gaps where the ECU gave no value
    final List<FlSpot> voltSpots = [];
    for (int i = 0; i < provider.voltageHistory.length; i++) {
      final v = provider.voltageHistory[i];
      voltSpots.add(v > 0 ? FlSpot(i.toDouble(), v.clamp(9.0, 16.0)) : FlSpot.nullSpot);
    }
    if (voltSpots.length < 2) voltSpots.addAll([FlSpot.nullSpot, FlSpot.nullSpot]);
    final bool hasVolt = provider.hasLiveVoltage;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.menu_rounded, color: AppColors.icon(context), size: 26),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: Text('Live Diagnostics',
            style: TextStyle(color: AppColors.text(context), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00B894).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                RotatingWheelWidget(size: 14, color: Color(0xFF00B894)),
                SizedBox(width: 6),
                Text('60 FPS STREAM',
                    style: TextStyle(
                        color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 10)),
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
              // Dual Telemetry Hero Gauges
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('ENGINE SPEED',
                              style: TextStyle(
                                  color: Color(0xFF8E92A4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            '$currentRpm',
                            style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text('RPM',
                              style: TextStyle(
                                  color: Color(0xFF6C5CE7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Container(height: 50, width: 1, color: const Color(0xFF232736)),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('ROAD SPEED',
                              style: TextStyle(
                                  color: Color(0xFF8E92A4),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            '$currentSpeed',
                            style: const TextStyle(
                                color: Color(0xFF00B894),
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                          const Text('KM / H',
                              style: TextStyle(
                                  color: Color(0xFF00B894),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live RPM Line Chart
              _buildChartCard(
                context,
                title: 'Real-Time RPM Stream (0 - 9,000 RPM)',
                color: const Color(0xFF6C5CE7),
                spots: rpmSpots,
                minY: 0,
                maxY: 9000,
                unit: 'RPM',
              ),
              const SizedBox(height: 20),

              // Live Speed Line Chart
              _buildChartCard(
                context,
                title: 'Real-Time Speed Stream (0 - 160 km/h)',
                color: const Color(0xFF00B894),
                spots: speedSpots,
                minY: 0,
                maxY: 160,
                unit: 'km/h',
              ),
              const SizedBox(height: 20),

              // Live Battery Voltage Line Chart (real ECU / sensor readings only)
              _buildChartCard(
                context,
                title: 'Real-Time Battery Voltage Stream (9 - 16 V)',
                color: const Color(0xFFFDCB6E),
                spots: voltSpots,
                minY: 9,
                maxY: 16,
                unit: 'V',
                emptyNote: hasVolt ? null : 'No battery voltage received from the ECU yet',
              ),
              const SizedBox(height: 20),

              // Aux Sensors Row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniCard(
                      context,
                      title: 'Coolant Temp',
                      value: '${currentCoolant.toStringAsFixed(1)} °C',
                      icon: Icons.thermostat_rounded,
                      color: currentCoolant > 105
                          ? const Color(0xFFFF7675)
                          : const Color(0xFF00B894),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniCard(
                      context,
                      title: 'Battery Voltage',
                      value: hasVolt ? '${currentVoltage.toStringAsFixed(2)} V' : '-- V',
                      icon: Icons.bolt_rounded,
                      color: const Color(0xFFFDCB6E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniCard(
                      context,
                      title: 'Fuel Trim',
                      value:
                          '${fuelTrim >= 0 ? '+' : ''}${fuelTrim.toStringAsFixed(1)} %',
                      icon: Icons.local_gas_station_rounded,
                      color: const Color(0xFFA29BFE),
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

  Widget _buildChartCard(
    BuildContext context, {
    required String title,
    required Color color,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required String unit,
    String? emptyNote,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                      color: AppColors.text(context), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(unit,
                    style: TextStyle(
                        color: color, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
            LineChart(
              LineChartData(
                minX: 0,
                maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 10,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) =>
                      FlLine(color: AppColors.border(context), strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
            if (emptyNote != null)
              Text(emptyNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: AppColors.text(context), fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
