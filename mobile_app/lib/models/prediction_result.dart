import 'dtc_alert.dart';
import 'telemetry_reading.dart';

class PredictionResult {
  final int healthScore;
  final String triageLabel; // NORMAL, WARNING, CRITICAL
  final double rulHours;
  final double failureProbability;
  final List<DtcAlert> activeDtcs;
  final String modelVersion;
  final TelemetryReading sensorSnapshot;

  PredictionResult({
    required this.healthScore,
    required this.triageLabel,
    required this.rulHours,
    required this.failureProbability,
    required this.activeDtcs,
    required this.modelVersion,
    required this.sensorSnapshot,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    var dtcsJson = json['active_dtcs'] as List? ?? [];
    List<DtcAlert> dtcList = dtcsJson.map((d) => DtcAlert.fromJson(d)).toList();

    return PredictionResult(
      healthScore: json['health_score'] ?? 87,
      triageLabel: json['triage_label'] ?? 'NORMAL',
      rulHours: (json['rul_hours'] ?? 1200.0).toDouble(),
      failureProbability: (json['failure_probability'] ?? 0.05).toDouble(),
      activeDtcs: dtcList,
      modelVersion: json['model_version'] ?? 'v1.0',
      sensorSnapshot: json['sensor_snapshot'] != null
          ? TelemetryReading.fromJson(json['sensor_snapshot'])
          : TelemetryReading(
              rpm: 3200, coolantTemp: 88, engineLoad: 40, throttlePos: 25, fuelTrim: 0.5, o2Voltage: 0.45, speed: 55, voltage: 13.8),
    );
  }
}
