import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export scan result to PDF
  Future<File?> exportToPDF({
    required String networkName,
    required String timestamp,
    required List<String> threats,
    required List<Map<String, dynamic>> devices,
    required Map<String, dynamic> networkInfo,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'WiFense Security Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Network Information
              pw.Header(level: 1, text: 'Network Information'),
              pw.SizedBox(height: 10),
              _buildPDFInfoTable([
                ['Network Name', networkName],
                ['BSSID', networkInfo['bssid'] ?? 'N/A'],
                ['Encryption', networkInfo['encryption'] ?? 'N/A'],
                ['Signal Strength', networkInfo['signal'] ?? 'N/A'],
                ['Scan Time', timestamp],
              ]),
              pw.SizedBox(height: 20),

              // Threat Analysis
              pw.Header(level: 1, text: 'Threat Analysis'),
              pw.SizedBox(height: 10),
              if (threats.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Icon(
                        const pw.IconData(0xe86c), // check_circle
                        color: PdfColors.green,
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'No threats detected. Network appears secure.',
                        style: pw.TextStyle(
                          color: PdfColors.green900,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: threats.map((threat) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Icon(
                            const pw.IconData(0xe002), // warning
                            color: PdfColors.red,
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: pw.Text(
                              threat,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              pw.SizedBox(height: 20),

              // Connected Devices
              pw.Header(level: 1, text: 'Connected Devices (${devices.length})'),
              pw.SizedBox(height: 10),
              if (devices.isNotEmpty)
                pw.TableHelper.fromTextArray(
                  headers: ['Device Name', 'IP Address', 'MAC Address', 'Vendor'],
                  data: devices.map((device) {
                    return [
                      device['name'] ?? 'Unknown',
                      device['ip'] ?? 'N/A',
                      device['mac'] ?? 'N/A',
                      device['vendor'] ?? 'Unknown',
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                ),

              pw.SizedBox(height: 20),

              // Recommendations
              pw.Header(level: 1, text: 'Security Recommendations'),
              pw.SizedBox(height: 10),
              _buildPDFRecommendations(threats),

              // Footer
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'WiFense - WiFi Security Scanner\nGenerated by WiFense Mobile App',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ];
          },
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/wifense_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      return file;
    } catch (e) {
      print('Error generating PDF: $e');
      return null;
    }
  }

  pw.Widget _buildPDFInfoTable(List<List<String>> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      children: data.map((row) {
        return pw.TableRow(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              color: PdfColors.grey100,
              child: pw.Text(
                row[0],
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        );
      }).toList(),
    );
  }

  pw.Widget _buildPDFRecommendations(List<String> threats) {
    final recommendations = <String>[];

    if (threats.isEmpty) {
      recommendations.addAll([
        'Continue monitoring your network regularly',
        'Keep your device software updated',
        'Use strong passwords for your WiFi network',
      ]);
    } else {
      if (threats.any((t) => t.toLowerCase().contains('arp'))) {
        recommendations.add('ARP Spoofing detected - Use a VPN to encrypt your traffic');
      }
      if (threats.any((t) => t.toLowerCase().contains('dns'))) {
        recommendations.add('DNS Hijacking detected - Verify your DNS server settings');
      }
      if (threats.any((t) => t.toLowerCase().contains('ssl'))) {
        recommendations.add('SSL Stripping detected - Avoid entering sensitive information');
      }
      if (threats.any((t) => t.toLowerCase().contains('weak') || t.toLowerCase().contains('wep'))) {
        recommendations.add('Weak encryption detected - Upgrade to WPA3 if possible');
      }
      recommendations.addAll([
        'Consider using a VPN service for additional protection',
        'Disconnect from this network if possible',
        'Avoid accessing sensitive accounts or banking sites',
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: recommendations.map((rec) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
              pw.Expanded(
                child: pw.Text(rec, style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Export scan result to CSV
  Future<File?> exportToCSV({
    required List<Map<String, dynamic>> scanResults,
  }) async {
    try {
      final List<List<dynamic>> rows = [
        // Header
        ['Timestamp', 'Network', 'BSSID', 'Encryption', 'Signal', 'Threats', 'Devices'],
      ];

      // Data rows
      for (var result in scanResults) {
        rows.add([
          result['timestamp'] ?? '',
          result['network'] ?? '',
          result['bssid'] ?? '',
          result['encryption'] ?? '',
          result['signal'] ?? '',
          (result['threats'] as List?)?.join('; ') ?? 'None',
          result['deviceCount'] ?? 0,
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);

      // Save CSV
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/wifense_history_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      return file;
    } catch (e) {
      print('Error generating CSV: $e');
      return null;
    }
  }

  /// Share file using native share dialog
  Future<void> shareFile(File file, {String? subject}) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'WiFense Security Report',
      );
    } catch (e) {
      print('Error sharing file: $e');
    }
  }

  /// Export devices list to CSV
  Future<File?> exportDevicesToCSV({
    required List<Map<String, dynamic>> devices,
  }) async {
    try {
      final List<List<dynamic>> rows = [
        // Header
        ['Device Name', 'IP Address', 'MAC Address', 'Vendor', 'First Seen', 'Last Seen'],
      ];

      // Data rows
      for (var device in devices) {
        rows.add([
          device['name'] ?? 'Unknown',
          device['ip'] ?? '',
          device['mac'] ?? '',
          device['vendor'] ?? 'Unknown',
          device['firstSeen'] ?? '',
          device['lastSeen'] ?? '',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);

      // Save CSV
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/wifense_devices_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);

      return file;
    } catch (e) {
      print('Error generating devices CSV: $e');
      return null;
    }
  }
}
