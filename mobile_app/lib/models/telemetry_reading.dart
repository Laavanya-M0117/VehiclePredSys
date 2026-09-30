class TelemetryReading {
  final double rpm;
  final double coolantTemp;
  final double engineLoad;
  final double throttlePos;
  final double fuelTrim;
  final double o2Voltage;
  final double speed;
  final double voltage;
  final DateTime timestamp;

  TelemetryReading({
    required this.rpm,
    required this.coolantTemp,
    required this.engineLoad,
    required this.throttlePos,
    required this.fuelTrim,
    required this.o2Voltage,
    required this.speed,
    required this.voltage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TelemetryReading.fromJson(Map<String, dynamic> json) {
    return TelemetryReading(
      rpm: (json['rpm'] ?? 3200.0).toDouble(),
      coolantTemp: (json['coolant_temp'] ?? 88.0).toDouble(),
      engineLoad: (json['engine_load'] ?? 40.0).toDouble(),
      throttlePos: (json['throttle_pos'] ?? 25.0).toDouble(),
      fuelTrim: (json['fuel_trim'] ?? 0.5).toDouble(),
      o2Voltage: (json['o2_voltage'] ?? 0.45).toDouble(),
      speed: (json['speed'] ?? 55.0).toDouble(),
      voltage: (json['voltage'] ?? 13.8).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] * 1000).toInt())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rpm': rpm,
      'coolant_temp': coolantTemp,
      'engine_load': engineLoad,
      'throttle_pos': throttlePos,
      'fuel_trim': fuelTrim,
      'o2_voltage': o2Voltage,
      'speed': speed,
      'voltage': voltage,
    };
  }
}
