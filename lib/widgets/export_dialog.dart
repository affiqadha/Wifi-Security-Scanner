import 'package:flutter/material.dart';
import '../services/export_service.dart';

class ExportDialog extends StatelessWidget {
  final Map<String, dynamic> scanData;
  final String exportType; // 'single' or 'history' or 'devices'

  const ExportDialog({
    Key? key,
    required this.scanData,
    this.exportType = 'single',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Export Options'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (exportType == 'single') ...[
            const Text(
              'Choose export format for this scan result:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildExportOption(
              context,
              icon: Icons.picture_as_pdf,
              title: 'PDF Report',
              description: 'Detailed security report with analysis',
              color: Colors.red,
              onTap: () => _exportPDF(context),
            ),
          ],
          if (exportType == 'history') ...[
            const Text(
              'Choose export format for scan history:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildExportOption(
              context,
              icon: Icons.table_chart,
              title: 'CSV Spreadsheet',
              description: 'All scan results in spreadsheet format',
              color: Colors.green,
              onTap: () => _exportHistoryCSV(context),
            ),
          ],
          if (exportType == 'devices') ...[
            const Text(
              'Choose export format for devices:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            _buildExportOption(
              context,
              icon: Icons.table_chart,
              title: 'CSV Spreadsheet',
              description: 'Device list in spreadsheet format',
              color: Colors.blue,
              onTap: () => _exportDevicesCSV(context),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }

  Widget _buildExportOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPDF(BuildContext context) async {
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final file = await exportService.exportToPDF(
        networkName: scanData['networkName'] ?? 'Unknown Network',
        timestamp: scanData['timestamp'] ?? DateTime.now().toString(),
        threats: List<String>.from(scanData['threats'] ?? []),
        devices: List<Map<String, dynamic>>.from(scanData['devices'] ?? []),
        networkInfo: scanData['networkInfo'] ?? {},
      );

      Navigator.pop(context); // Close loading

      if (file != null) {
        // Show success and share option
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Export Successful'),
              ],
            ),
            content: Text('PDF report saved to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.share),
                label: const Text('SHARE'),
              ),
            ],
          ),
        );

        if (share == true) {
          await exportService.shareFile(file, subject: 'WiFense Security Report');
        }
      } else {
        throw Exception('Failed to generate PDF');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showErrorDialog(context, 'Failed to export PDF: $e');
    }
  }

  Future<void> _exportHistoryCSV(BuildContext context) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating CSV...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final file = await exportService.exportToCSV(
        scanResults: List<Map<String, dynamic>>.from(scanData['history'] ?? []),
      );

      Navigator.pop(context);

      if (file != null) {
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Export Successful'),
              ],
            ),
            content: Text('CSV file saved to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.share),
                label: const Text('SHARE'),
              ),
            ],
          ),
        );

        if (share == true) {
          await exportService.shareFile(file, subject: 'WiFense Scan History');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to export CSV: $e');
    }
  }

  Future<void> _exportDevicesCSV(BuildContext context) async {
    Navigator.pop(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating CSV...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final exportService = ExportService();
      final file = await exportService.exportDevicesToCSV(
        devices: List<Map<String, dynamic>>.from(scanData['devices'] ?? []),
      );

      Navigator.pop(context);

      if (file != null) {
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 12),
                Text('Export Successful'),
              ],
            ),
            content: Text('CSV file saved to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('OK'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.share),
                label: const Text('SHARE'),
              ),
            ],
          ),
        );

        if (share == true) {
          await exportService.shareFile(file, subject: 'WiFense Device List');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog(context, 'Failed to export CSV: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('Export Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
