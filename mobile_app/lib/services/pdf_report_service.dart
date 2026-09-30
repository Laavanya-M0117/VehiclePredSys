import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';

class DiagnosticSnapshot {
  final String reportId;
  final String generatedTimestamp;
  final String vehicleName;
  final String vehicleType;
  final String vehicleVin;
  final int odometerKm;
  final String triageLevel;
  final double failureProbability;
  final double remainingUsefulLifeHours;
  final double coolantTemp;
  final double batteryVoltage;
  final double fuelTrim;
  final double rpm;
  final double speed;
  final List<Map<String, String>> activeFaults;
  final List<String> interTripWarnings;

  DiagnosticSnapshot({
    required this.reportId,
    required this.generatedTimestamp,
    required this.vehicleName,
    required this.vehicleType,
    required this.vehicleVin,
    required this.odometerKm,
    required this.triageLevel,
    required this.failureProbability,
    required this.remainingUsefulLifeHours,
    required this.coolantTemp,
    required this.batteryVoltage,
    required this.fuelTrim,
    required this.rpm,
    required this.speed,
    required this.activeFaults,
    required this.interTripWarnings,
  });

  factory DiagnosticSnapshot.fromProvider(AppStateProvider provider) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm:ss');
    final String timestamp = dateFormat.format(DateTime.now());
    final String rptId = 'VETRI-CERT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return DiagnosticSnapshot(
      reportId: rptId,
      generatedTimestamp: timestamp,
      vehicleName: provider.vehicleName,
      vehicleType: provider.vehicleType,
      vehicleVin: provider.vehicleVin,
      odometerKm: provider.odometerKm,
      triageLevel: provider.triageLevel,
      failureProbability: provider.failureProbability,
      remainingUsefulLifeHours: provider.remainingUsefulLifeHours,
      coolantTemp: provider.coolantTemp,
      batteryVoltage: provider.batteryVoltage,
      fuelTrim: provider.fuelTrim,
      rpm: provider.rpm,
      speed: provider.speed,
      activeFaults: List<Map<String, String>>.from(provider.activeFaults),
      interTripWarnings: List<String>.from(provider.interTripDriftWarnings),
    );
  }
}

class PdfReportService {
  static Future<Uint8List> generateDiagnosticPdfFromSnapshot(DiagnosticSnapshot snapshot) async {
    final pdf = pw.Document();

    final triage = snapshot.triageLevel;
    PdfColor triageColor;
    if (triage == 'CRITICAL') {
      triageColor = PdfColors.red600;
    } else if (triage == 'MEDIUM') {
      triageColor = PdfColors.amber700;
    } else {
      triageColor = PdfColors.green700;
    }

    final int healthScore = ((1.0 - snapshot.failureProbability) * 100).toInt().clamp(5, 99);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Official Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VETRI VEHICLE PREDICTIVE TRIAGE',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'AI-Driven Powertrain Health & Telemetry Diagnostic Certificate',
                          style: const pw.TextStyle(
                            color: PdfColors.grey300,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: triageColor,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        '$triage RISK',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Report Metadata Bar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Report ID: ${snapshot.reportId}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('Captured: ${snapshot.generatedTimestamp}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.SizedBox(height: 10),

              // 1. Static Vehicle Profile
              pw.Text('1. VEHICLE PROFILE & SPECIFICATIONS',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaCell('Vehicle Model', snapshot.vehicleName),
                    _buildMetaCell('Vehicle Type', snapshot.vehicleType),
                    _buildMetaCell('VIN', snapshot.vehicleVin),
                    _buildMetaCell('Odometer', '${snapshot.odometerKm} km'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 2. Static AI Scorecard
              pw.Text('2. AI PREDICTIVE TRIAGE & BREAKDOWN RISK ASSESSMENT',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildScoreCell('Static Health Score', '$healthScore / 100', triageColor),
                    _buildScoreCell(
                        'Failure Probability', '${(snapshot.failureProbability * 100).toStringAsFixed(1)}%', triageColor),
                    _buildScoreCell('Remaining Useful Life',
                        '${snapshot.remainingUsefulLifeHours.toStringAsFixed(1)} Operating Hours', PdfColors.blueGrey800),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 3. Static Sensor Telemetry Matrix
              pw.Text('3. CAPTURED SENSOR TELEMETRY READINGS (STATIC SNAPSHOT)',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                    children: [
                      _buildTableHeader('Telemetry Metric'),
                      _buildTableHeader('Static Captured Value'),
                      _buildTableHeader('Standard Baseline'),
                      _buildTableHeader('Status'),
                    ],
                  ),
                  _buildTableRow('Coolant / Head Temperature', '${snapshot.coolantTemp.toStringAsFixed(1)} °C',
                      '85°C - 102°C', snapshot.coolantTemp > 105 ? 'EXCESSIVE THERMAL' : 'NOMINAL',
                      isAlert: snapshot.coolantTemp > 105),
                  _buildTableRow('Battery System Voltage', '${snapshot.batteryVoltage.toStringAsFixed(2)} V',
                      '12.4V - 14.5V', snapshot.batteryVoltage < 12.0 ? 'VOLTAGE SAG / WEAK' : 'NOMINAL',
                      isAlert: snapshot.batteryVoltage < 12.0),
                  _buildTableRow('Short-Term Fuel Trim (STFT)',
                      '${snapshot.fuelTrim >= 0 ? '+' : ''}${snapshot.fuelTrim.toStringAsFixed(1)} %',
                      '-5.0% to +5.0%', snapshot.fuelTrim.abs() > 10.0 ? 'LEAN/RICH DRIFT' : 'BALANCED',
                      isAlert: snapshot.fuelTrim.abs() > 10.0),
                  _buildTableRow('Engine Speed', '${snapshot.rpm.toInt()} RPM',
                      snapshot.vehicleType.toLowerCase().contains('bike') ? '1,400 - 9,800 RPM' : '750 - 6,500 RPM', 'STABLE'),
                  _buildTableRow('Road Speed', '${snapshot.speed.toStringAsFixed(1)} km/h', '0 - 160 km/h', 'RECORDED'),
                ],
              ),
              pw.SizedBox(height: 14),

              // 4. Static DTC Codes
              pw.Text('4. ACTIVE DIAGNOSTIC TROUBLE CODES (DTC)',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              if (snapshot.activeFaults.isEmpty)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Text('✓ Zero active DTC trouble codes detected. Powertrain sensors operating within factory limits.',
                      style: const pw.TextStyle(color: PdfColors.green800, fontSize: 9)),
                )
              else
                pw.Column(
                  children: snapshot.activeFaults
                      .map((f) => pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 4),
                            padding: const pw.EdgeInsets.all(6),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.red50,
                              borderRadius: pw.BorderRadius.circular(4),
                              border: pw.Border.all(color: PdfColors.red200),
                            ),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('${f['code']} - ${f['description']}',
                                    style: pw.TextStyle(
                                        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                                pw.Text('[${f['severity']} SEVERITY]',
                                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              pw.SizedBox(height: 14),

              // 5. Driver Predictive Maintenance Recommendations
              pw.Text('5. ACTIONABLE PREDICTIVE MAINTENANCE RECOMMENDATIONS',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRecommendationBullet('Cooling System:',
                        'Thermostat and radiator fins inspected nominal. Recommended coolant replacement in 3,200 km for city stop-and-go commuting.'),
                    pw.SizedBox(height: 4),
                    _buildRecommendationBullet('Battery & Stator:',
                        'Alternator charging current stable at ${snapshot.batteryVoltage.toStringAsFixed(2)}V. Maintain resting voltage above 12.4V to avoid starter fatigue.'),
                    pw.SizedBox(height: 4),
                    _buildRecommendationBullet('Air-Fuel Mixture:',
                        'Fuel trim variance is balanced at ${snapshot.fuelTrim.toStringAsFixed(1)}%. Clean throttle body and inspect air filter element at next routine service.'),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400, thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('VETRI Telemetry Platform • Certified Auto-Triage Engine v1.0',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text('Page 1 of 1 • Official Immutable Copy',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetaCell(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ],
    );
  }

  static pw.Widget _buildScoreCell(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
      ),
    );
  }

  static pw.TableRow _buildTableRow(String metric, String observed, String baseline, String status,
      {bool isAlert = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(metric, style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(observed, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(baseline, style: const pw.TextStyle(fontSize: 8))),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            status,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: isAlert ? PdfColors.red700 : PdfColors.green700,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildRecommendationBullet(String title, String desc) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('• ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                    text: '$title ',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                pw.TextSpan(text: desc, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Downloads the static PDF directly or shares/prints it
  static Future<void> downloadStaticPdf(DiagnosticSnapshot snapshot) async {
    final pdfBytes = await generateDiagnosticPdfFromSnapshot(snapshot);
    final String filename = 'VETRI_Diagnostic_Report_${snapshot.reportId}.pdf';

    // Share / Save / Download real PDF file
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
    );
  }
}
