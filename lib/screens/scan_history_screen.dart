import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '/theme/background_pattern.dart';
import '../widgets/export_dialog.dart';

class ScanHistoryScreen extends StatefulWidget {
  @override
  _ScanHistoryScreenState createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _wifiScans = [];
  List<Map<String, dynamic>> _deviceScans = [];
  List<Map<String, dynamic>> _mitmScans = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final db = DatabaseHelper.instance;
    
    final wifiScans = await db.getAllWifiScans();
    final deviceScans = await db.getAllDeviceScans();
    final mitmScans = await db.getAllMitmScans();
    final stats = await db.getStatistics();

    setState(() {
      _wifiScans = wifiScans;
      _deviceScans = deviceScans;
      _mitmScans = mitmScans;
      _statistics = stats;
      _isLoading = false;
    });
  }

  String _formatDateTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundPattern(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Scan History'),
          actions: [
            // ✅ NEW: Export button
            IconButton(
              icon: Icon(Icons.file_download),
              tooltip: 'Export History',
              onPressed: () => _showExportDialog(context),
            ),
            // Existing statistics button
            if (_statistics != null)
              IconButton(
                icon: Icon(Icons.info_outline),
                onPressed: () => _showStatistics(context),
              ),
            // Existing clear history button
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => _confirmClearHistory(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'WiFi Scans', icon: Icon(Icons.wifi, size: 20)),
              Tab(text: 'Device Scans', icon: Icon(Icons.devices, size: 20)),
              Tab(text: 'MITM Scans', icon: Icon(Icons.security, size: 20)),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildWifiScansList(),
                  _buildDeviceScansList(),
                  _buildMitmScansList(),
                ],
              ),
      ),
    );
  }

  Widget _buildWifiScansList() {
    if (_wifiScans.isEmpty) {
      return _buildEmptyState('No WiFi scans yet', Icons.wifi_off);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _wifiScans.length,
        itemBuilder: (context, index) {
          final scan = _wifiScans[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getThreatsColor(scan['threats_found']),
                child: Icon(Icons.wifi, color: Colors.white),
              ),
              title: Text('${scan['total_networks']} networks found'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDateTime(scan['timestamp'])),
                  if (scan['threats_found'] > 0)
                    Text(
                      '⚠️ ${scan['threats_found']} threats detected',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showWifiScanDetails(scan),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceScansList() {
    if (_deviceScans.isEmpty) {
      return _buildEmptyState('No device scans yet', Icons.devices_other);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _deviceScans.length,
        itemBuilder: (context, index) {
          final scan = _deviceScans[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.devices, color: Colors.white),
              ),
              title: Text('${scan['total_devices']} devices found'),
              subtitle: Text(_formatDateTime(scan['timestamp'])),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showDeviceScanDetails(scan),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMitmScansList() {
    if (_mitmScans.isEmpty) {
      return _buildEmptyState('No MITM scans yet', Icons.shield_outlined);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _mitmScans.length,
        itemBuilder: (context, index) {
          final scan = _mitmScans[index];
          final isThreat = scan['mitm_detected'] == 1;
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isThreat ? Colors.red : Colors.green,
                child: Icon(
                  isThreat ? Icons.warning : Icons.check_circle,
                  color: Colors.white,
                ),
              ),
              title: Text(isThreat ? 'MITM Detected!' : 'Network Secure'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatDateTime(scan['timestamp'])),
                  if (isThreat && scan['reason'] != null)
                    Text(
                      scan['reason'],
                      style: TextStyle(color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showMitmScanDetails(scan),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Start scanning to see history here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getThreatsColor(int threats) {
    if (threats == 0) return Colors.green;
    if (threats <= 2) return Colors.orange;
    return Colors.red;
  }

  void _showWifiScanDetails(Map<String, dynamic> scan) async {
    final db = DatabaseHelper.instance;
    final networks = await db.getNetworkDetailsForScan(scan['id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(_formatDateTime(scan['timestamp'])),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: networks.length,
                    itemBuilder: (context, index) {
                      final network = networks[index];
                      return Card(
                        child: ListTile(
                          title: Text(network['ssid'] ?? 'Hidden Network'),
                          subtitle: Text(
                            '${network['encryption_type']} • ${network['signal_strength']} dBm\nRisk: ${network['risk_level']}',
                          ),
                          leading: Icon(
                            Icons.wifi,
                            color: _getRiskColor(network['risk_level']),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeviceScanDetails(Map<String, dynamic> scan) async {
    final db = DatabaseHelper.instance;
    final devices = await db.getDeviceDetailsForScan(scan['id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devices Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(_formatDateTime(scan['timestamp'])),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return Card(
                        child: ListTile(
                          title: Text(device['vendor'] ?? 'Unknown Device'),
                          subtitle: Text(
                            'IP: ${device['ip_address']}\nMAC: ${device['mac_address']}',
                          ),
                          leading: Icon(Icons.devices),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showMitmScanDetails(Map<String, dynamic> scan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(scan['mitm_detected'] == 1 ? '⚠️ MITM Detected' : '✅ Network Secure'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Time: ${_formatDateTime(scan['timestamp'])}'),
              SizedBox(height: 12),
              if (scan['detection_type'] != null) ...[
                Text('Detection Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(scan['detection_type']),
                SizedBox(height: 8),
              ],
              if (scan['reason'] != null) ...[
                Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(scan['reason']),
                SizedBox(height: 8),
              ],
              if (scan['recommendations'] != null) ...[
                Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(scan['recommendations']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStatistics(BuildContext context) {
    if (_statistics == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('📊 Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('WiFi Scans', _statistics!['total_wifi_scans'].toString()),
            _buildStatRow('Device Scans', _statistics!['total_device_scans'].toString()),
            _buildStatRow('MITM Scans', _statistics!['total_mitm_scans'].toString()),
            Divider(),
            _buildStatRow('Total Threats', _statistics!['total_threats_found'].toString(),
                color: Colors.red),
            _buildStatRow('MITM Attacks', _statistics!['mitm_attacks_detected'].toString(),
                color: Colors.red),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    // Determine which tab is active and export that data
    final currentTab = _tabController.index;
    
    List<Map<String, dynamic>> dataToExport = [];
    String exportType = 'history';
    
    switch (currentTab) {
      case 0: // WiFi Scans
        dataToExport = _wifiScans.map((scan) => {
          'timestamp': scan['timestamp'],
          'network': '${scan['total_networks']} networks',
          'bssid': 'N/A',
          'encryption': 'Various',
          'signal': 'N/A',
          'threats': '${scan['threats_found']} threats',
          'deviceCount': 0,
        }).toList();
        break;
      case 1: // Device Scans
        dataToExport = _deviceScans.map((scan) => {
          'timestamp': scan['timestamp'],
          'network': 'Device Scan',
          'bssid': 'N/A',
          'encryption': 'N/A',
          'signal': 'N/A',
          'threats': 'N/A',
          'deviceCount': scan['devices_found'] ?? 0,
        }).toList();
        break;
      case 2: // MITM Scans
        dataToExport = _mitmScans.map((scan) => {
          'timestamp': scan['timestamp'],
          'network': scan['network_ssid'] ?? 'Unknown',
          'bssid': scan['network_bssid'] ?? 'N/A',
          'encryption': 'N/A',
          'signal': 'N/A',
          'threats': scan['threats_detected'] ?? 'None',
          'deviceCount': 0,
        }).toList();
        break;
    }

    if (dataToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data to export in this tab'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        scanData: {'history': dataToExport},
        exportType: exportType,
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All History?'),
        content: Text('This will delete all scan history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DatabaseHelper.instance.clearAllHistory();
              await _loadHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ History cleared')),
              );
            },
            child: Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical':
        return Colors.red.shade800;
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}