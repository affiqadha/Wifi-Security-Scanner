import 'package:flutter/material.dart';
import '../services/network_fingerprinting_service.dart';
import 'package:intl/intl.dart';

class TrustedNetworksScreen extends StatefulWidget {
  const TrustedNetworksScreen({Key? key}) : super(key: key);

  @override
  State<TrustedNetworksScreen> createState() => _TrustedNetworksScreenState();
}

class _TrustedNetworksScreenState extends State<TrustedNetworksScreen> {
  final _fingerprintService = NetworkFingerprintingService();
  List<NetworkFingerprint> _trustedNetworks = [];
  List<NetworkFingerprint> _suspiciousNetworks = [];
  List<NetworkFingerprint> _allNetworks = []; // ✅ NEW: Show all fingerprinted networks
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadNetworks();
  }

  Future<void> _loadNetworks() async {
    setState(() => _isLoading = true);
    
    print('🔍 Loading networks from database...');
    
    // ✅ FIXED: Get all networks by combining trusted and suspicious, then get all from DB
    final trusted = await _fingerprintService.getTrustedNetworks();
    final suspicious = await _fingerprintService.getSuspiciousNetworks();
    
    // Get all networks from database (including untrusted ones)
    final allNetworks = await _fingerprintService.getAllFingerprints();
    
    print('📊 Found: ${allNetworks.length} total, ${trusted.length} trusted, ${suspicious.length} suspicious');
    
    setState(() {
      _allNetworks = allNetworks;
      _trustedNetworks = trusted;
      _suspiciousNetworks = suspicious;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Management'),
        elevation: 0,
        actions: [
          // ✅ NEW: Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNetworks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab selector - ✅ UPDATED: Changed to show All/Trusted/Suspicious
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ✅ NEW: "All Networks" tab to show everything
                Expanded(
                  child: _buildTabButton(
                    'All',
                    0,
                    Icons.wifi,
                    Colors.blue,
                    _allNetworks.length,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    'Trusted',
                    1,
                    Icons.verified_user,
                    Colors.green,
                    _trustedNetworks.length,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    'Suspicious',
                    2,
                    Icons.warning,
                    Colors.orange,
                    _suspiciousNetworks.length,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildAllNetworksList(), // ✅ NEW: Show all networks
                      _buildTrustedNetworksList(),
                      _buildSuspiciousNetworksList(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon, Color color, int count) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Show all fingerprinted networks
  Widget _buildAllNetworksList() {
    if (_allNetworks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.wifi_off,
        title: 'No Networks Found',
        message: 'Scan for WiFi networks to create fingerprints and detect Evil Twin attacks.',
        color: Colors.blue,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNetworks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allNetworks.length,
        itemBuilder: (context, index) {
          final network = _allNetworks[index];
          return _buildNetworkCard(
            network,
            isTrusted: network.isTrusted == 1,
            isSuspicious: network.trustScore < 30,
          );
        },
      ),
    );
  }

  Widget _buildTrustedNetworksList() {
    if (_trustedNetworks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.wifi_lock,
        title: 'No Trusted Networks',
        message: 'Mark networks as trusted to quickly identify them and detect Evil Twin attacks.\n\nTip: Go to "All" tab to mark networks as trusted.',
        actionButton: TextButton.icon(
          onPressed: () => setState(() => _selectedTab = 0),
          icon: const Icon(Icons.arrow_back),
          label: const Text('View All Networks'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNetworks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trustedNetworks.length,
        itemBuilder: (context, index) {
          return _buildNetworkCard(_trustedNetworks[index], isTrusted: true);
        },
      ),
    );
  }

  Widget _buildSuspiciousNetworksList() {
    if (_suspiciousNetworks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle,
        title: 'All Clear',
        message: 'No suspicious network activity detected. All networks are behaving normally.',
        color: Colors.green,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNetworks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _suspiciousNetworks.length,
        itemBuilder: (context, index) {
          return _buildNetworkCard(_suspiciousNetworks[index], isTrusted: false, isSuspicious: true);
        },
      ),
    );
  }

  // ✅ UPDATED: Added isSuspicious parameter
  Widget _buildNetworkCard(NetworkFingerprint network, {bool isTrusted = false, bool isSuspicious = false}) {
    Color color;
    IconData iconData;
    
    if (isSuspicious) {
      color = Colors.red;
      iconData = Icons.warning;
    } else if (isTrusted) {
      color = Colors.green;
      iconData = Icons.wifi_lock;
    } else {
      color = Colors.blue;
      iconData = Icons.wifi;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showNetworkDetails(network),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          network.ssid.isEmpty ? 'Hidden Network' : network.ssid,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          network.networkId,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trust score badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getTrustScoreColor(network.trustScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getTrustScoreColor(network.trustScore),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getTrustScoreIcon(network.trustScore),
                          size: 14,
                          color: _getTrustScoreColor(network.trustScore),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${network.trustScore}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getTrustScoreColor(network.trustScore),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Network info
              _buildInfoRow(Icons.router, 'Gateway', network.gatewayIp),
              _buildInfoRow(Icons.dns, 'DNS', network.dnsServers.isNotEmpty ? network.dnsServers.first : 'N/A'),
              _buildInfoRow(Icons.security, 'Encryption', network.encryptionType),
              _buildInfoRow(Icons.access_time, 'Last Seen', _formatTimestamp(network.lastSeen)),
              _buildInfoRow(Icons.history, 'First Seen', _formatTimestamp(network.firstSeen)),

              const SizedBox(height: 12),

              // Status badge
              if (isTrusted || isSuspicious)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        isSuspicious ? 'SUSPICIOUS - Review Changes' : 'TRUSTED NETWORK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _showChangeHistory(network),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('History', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  const Spacer(),
                  if (isTrusted)
                    OutlinedButton(
                      onPressed: () => _removeTrust(network),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Remove', style: TextStyle(fontSize: 12)),
                    )
                  else if (isSuspicious)
                    OutlinedButton(
                      onPressed: () => _clearSuspicion(network),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 12)),
                    )
                  else
                    Wrap(
                      spacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _markSuspicious(network),
                          icon: const Icon(Icons.warning, size: 14),
                          label: const Text('Suspect', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _addTrust(network),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('Trust', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 28),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    Color color = Colors.grey,
    Widget? actionButton,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  Color _getTrustScoreColor(int score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  IconData _getTrustScoreIcon(int score) {
    if (score >= 70) return Icons.check_circle;
    if (score >= 40) return Icons.warning;
    return Icons.error;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d, y').format(timestamp);
  }

  Future<void> _showNetworkDetails(NetworkFingerprint network) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              network.isTrusted == 1 ? Icons.wifi_lock : Icons.wifi,
              color: network.isTrusted == 1 ? Colors.green : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                network.ssid.isEmpty ? 'Hidden Network' : network.ssid,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('BSSID', network.networkId),
              _buildDetailItem('Gateway MAC', network.gatewayMac),
              _buildDetailItem('Gateway IP', network.gatewayIp),
              _buildDetailItem('DNS Servers', network.dnsServers.join(', ')),
              _buildDetailItem('Encryption', network.encryptionType),
              _buildDetailItem('Subnet', network.subnet),
              _buildDetailItem('Trust Score', '${network.trustScore}'),
              _buildDetailItem('Signal Strength', '${network.signalStrength} dBm'),
              _buildDetailItem('First Seen', DateFormat('MMM d, y HH:mm').format(network.firstSeen)),
              _buildDetailItem('Last Seen', DateFormat('MMM d, y HH:mm').format(network.lastSeen)),
              _buildDetailItem('Fingerprint Hash', network.fingerprintHash),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangeHistory(NetworkFingerprint network) async {
    final history = await _fingerprintService.getChangeHistory(network.networkId);
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        network.ssid,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No changes recorded',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This network has remained consistent',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final change = history[index];
                          return _buildChangeItem(change);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeItem(Map<String, dynamic> change) {
    final severity = change['severity'] as String;
    Color color = Colors.grey;
    IconData icon = Icons.info;
    
    if (severity == 'critical') {
      color = Colors.red;
      icon = Icons.error;
    } else if (severity == 'high') {
      color = Colors.orange;
      icon = Icons.warning;
    } else if (severity == 'medium') {
      color = Colors.yellow[700]!;
      icon = Icons.warning_amber;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          change['change_type'].toString().replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.arrow_forward, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'From: ${change['old_value']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.arrow_forward, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'To: ${change['new_value']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(DateTime.parse(change['detected_at'])),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _addTrust(NetworkFingerprint network) async {
    print('✅ Adding trust for: ${network.ssid} (${network.networkId})');
    
    await _fingerprintService.setTrustedNetwork(network.networkId, true);
    await _loadNetworks();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${network.ssid} marked as trusted'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ✅ NEW: Mark network as suspicious
  Future<void> _markSuspicious(NetworkFingerprint network) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Mark as Suspicious?'),
          ],
        ),
        content: Text(
          'Mark ${network.ssid} as suspicious?\n\n'
          'This will:\n'
          '• Lower trust score to 20\n'
          '• Move it to Suspicious tab\n'
          '• Show warning when detected\n\n'
          'Use this for networks you don\'t trust or that seem dangerous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('MARK SUSPICIOUS'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('⚠️ Marking as suspicious: ${network.ssid} (${network.networkId})');
      
      // Set trust score to 20 (below suspicious threshold of 30)
      await _fingerprintService.updateTrustScore(network.networkId, -100); // Force to minimum
      await _fingerprintService.updateTrustScore(network.networkId, 20); // Set to 20
      await _loadNetworks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${network.ssid} marked as suspicious'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ NEW: Clear suspicious status
  Future<void> _clearSuspicion(NetworkFingerprint network) async {
    print('✅ Clearing suspicion for: ${network.ssid} (${network.networkId})');
    
    // Reset trust score to default 50
    await _fingerprintService.updateTrustScore(network.networkId, -100); // Force to 0
    await _fingerprintService.updateTrustScore(network.networkId, 50); // Set to 50
    await _loadNetworks();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${network.ssid} cleared from suspicious list'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _removeTrust(NetworkFingerprint network) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remove Trust?'),
          ],
        ),
        content: Text(
          'Remove ${network.ssid} from trusted networks?\n\nYou can mark it as trusted again later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('❌ Removing trust for: ${network.ssid} (${network.networkId})');
      
      await _fingerprintService.setTrustedNetwork(network.networkId, false);
      await _loadNetworks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${network.ssid} removed from trusted networks'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}