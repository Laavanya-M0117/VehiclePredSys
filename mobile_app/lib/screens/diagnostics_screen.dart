import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_state_provider.dart';
import '../widgets/rotating_wheel.dart';

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
      rpmSpots.addAll(const [
        FlSpot(0, 2200),
        FlSpot(1, 2800),
        FlSpot(2, 3400),
        FlSpot(3, 3100),
        FlSpot(4, 3800)
      ]);
    }

    final List<FlSpot> speedSpots = [];
    for (int i = 0; i < provider.speedHistory.length; i++) {
      speedSpots.add(FlSpot(i.toDouble(), provider.speedHistory[i]));
    }
    if (speedSpots.isEmpty) {
      speedSpots.addAll(
          const [FlSpot(0, 30), FlSpot(1, 45), FlSpot(2, 60), FlSpot(3, 55), FlSpot(4, 70)]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Live Diagnostics & Graphs',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF232736)),
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
                title: 'Real-Time Speed Stream (0 - 160 km/h)',
                color: const Color(0xFF00B894),
                spots: speedSpots,
                minY: 0,
                maxY: 160,
                unit: 'km/h',
              ),
              const SizedBox(height: 20),

              // Aux Sensors Row
              Row(
                children: [
                  Expanded(
                    child: _buildMiniCard(
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
                      title: 'Battery Voltage',
                      value: '${currentVoltage.toStringAsFixed(2)} V',
                      icon: Icons.bolt_rounded,
                      color: const Color(0xFFFDCB6E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMiniCard(
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

  Widget _buildChartCard({
    required String title,
    required Color color,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF232736)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
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
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: spots.length > 1 ? (spots.length - 1).toDouble() : 10,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) =>
                      const FlLine(color: Color(0xFF232736), strokeWidth: 1),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232736)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
