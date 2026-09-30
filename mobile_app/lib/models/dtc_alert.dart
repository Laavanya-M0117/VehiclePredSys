class DtcAlert {
  final String code;
  final String title;
  final String description;
  final String severity; // NORMAL, WARNING, CRITICAL, INFO
  final String action;
  final DateTime triggeredAt;

  DtcAlert({
    required this.code,
    required this.title,
    required this.description,
    required this.severity,
    required this.action,
    DateTime? triggeredAt,
  }) : triggeredAt = triggeredAt ?? DateTime.now();

  factory DtcAlert.fromJson(Map<String, dynamic> json) {
    return DtcAlert(
      code: json['code'] ?? json['dtc_code'] ?? 'P0000',
      title: json['title'] ?? 'Unknown Diagnostic Code',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'WARNING',
      action: json['action'] ?? 'Check vehicle service manual.',
      triggeredAt: json['triggered_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['triggered_at'] * 1000).toInt())
          : DateTime.now(),
    );
  }
}
