import 'package:flutter/material.dart';
import '/services/wifi_platform_service.dart';
import '/theme/background_pattern.dart';
import '/services/location_helper.dart';
import '/models/wifi_access_point.dart';
import '/database/database_helper.dart';
import '/services/vpn_service.dart';
import '/services/wifi_connection_monitor.dart';
import '/widgets/unsafe_connection_banner.dart';
import '/widgets/dismissible_unsafe_connection_blocker.dart';
import '/services/network_fingerprinting_service.dart';
import 'dart:io';
import 'dart:async'; // For TimeoutException

class WifiScannerScreen extends StatefulWidget {
  @override
  _WifiScannerScreenState createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends State<WifiScannerScreen> {
  List<Widget> _wifiList = [];
  Map<String, Set<String>> ssidToBssids = {};
  final WifiPlatformService _wifiService = WifiPlatformService();
  final NetworkFingerprintingService _fingerprintService = NetworkFingerprintingService();
  bool _fingerprintInitialized = false;
  final VpnService _vpnService = VpnService();
  final WifiConnectionMonitor _connectionMonitor = WifiConnectionMonitor();
  bool _isScanning = false;
  
  // Track if we've already shown alerts for specific networks
  Set<String> _alertedNetworks = {};

  // Banner state
  bool _showUnsafeBanner = false;
  String _unsafeNetworkSsid = '';
  String _unsafeNetworkEncryption = '';

  // ✅ NEW: Track dismissed networks to prevent repeated pop-ups
  Set<String> _dismissedNetworks = {};

  // ✅ NEW: Track networks that have already shown the full-screen blocker
  Set<String> _shownBlockerForNetworks = {};

  // ✅ NEW: Initialize fingerprinting on start
  @override
  void initState() {
    super.initState();

    // Initialize fingerprinting
    _initializeFingerprinting();

    // Start monitoring WiFi connections
    _connectionMonitor.startMonitoring();

    // Set callback for when unsafe connection detected
    _connectionMonitor.onUnsafeConnectionDetected = (ssid, encryption) {
      if (mounted) {
        // ✅ NEW: Only show banner if not dismissed for this network
        if (!_dismissedNetworks.contains(ssid)) {
          // ✅ NEW: Only show full-screen blocker ONCE per network
          if (!_shownBlockerForNetworks.contains(ssid)) {
            _showFullScreenBlocker(ssid, encryption);
            _shownBlockerForNetworks.add(ssid); // Mark as shown
          }

          // Enable persistent banner (can show without blocker)
          setState(() {
            _showUnsafeBanner = true;
            _unsafeNetworkSsid = ssid;
            _unsafeNetworkEncryption = encryption;
          });
        }
      }
    };
  }

  // ✅ NEW: Initialize fingerprinting service
  Future<void> _initializeFingerprinting() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await _fingerprintService.initialize(db);
      setState(() => _fingerprintInitialized = true);
      print("✅ Fingerprinting initialized in WiFi Scanner");
    } catch (e) {
      print("⚠️ Fingerprinting initialization failed: $e");
    }
  }

  // Save scan results to database
  Future<void> _saveScanToDatabase(List<WifiNetwork> networks) async {
    try {
      final db = DatabaseHelper.instance;
      final timestamp = DateTime.now().toIso8601String();
      
      // Count threats
      int threatsFound = 0;
      int highRisk = 0;
      int mediumRisk = 0;
      int lowRisk = 0;
      
      for (var network in networks) {
        final encryptionType = getEncryptionType(network.capabilities);
        final riskLevel = getRiskLevel(network.signalLevel, encryptionType);
        
        if (riskLevel == 'High' || riskLevel == 'Critical') {
          threatsFound++;
          highRisk++;
        } else if (riskLevel == 'Medium') {
          mediumRisk++;
        } else {
          lowRisk++;
        }
      }
      
      // Insert main scan record
      final scanId = await db.insertWifiScan({
        'timestamp': timestamp,
        'total_networks': networks.length,
        'threats_found': threatsFound,
        'high_risk_count': highRisk,
        'medium_risk_count': mediumRisk,
        'low_risk_count': lowRisk,
      });
      
      // Insert individual network details
      for (var network in networks) {
        final encryptionType = getEncryptionType(network.capabilities);
        final riskLevel = getRiskLevel(network.signalLevel, encryptionType);
        
        await db.insertNetworkDetail({
          'scan_id': scanId,
          'ssid': network.ssid,
          'bssid': network.bssid,
          'encryption_type': encryptionType,
          'signal_strength': network.signalLevel,
          'frequency': network.frequency,
          'risk_level': riskLevel,
          'is_threat': (riskLevel == 'High' || riskLevel == 'Critical') ? 1 : 0,
          'threat_type': (riskLevel == 'High' || riskLevel == 'Critical') ? 'Weak/No Encryption' : null,
          'timestamp': timestamp,
        });
      }

      /*
      // ✅ NEW: Check network fingerprints (Evil Twin detection)
      if (_fingerprintInitialized) {
        for (var network in networks) {
          await _checkNetworkFingerprint(network);
        }
      }
      */
      
      print('✅ Saved ${networks.length} networks to database (Scan ID: $scanId)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Scan saved to history'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error saving scan to database: $e');
    }
  }

  // ✅ NEW: Check network fingerprint for Evil Twin detection
  Future<void> _checkNetworkFingerprint(WifiNetwork network) async {
    try {
      // Get basic network info
      final ssid = network.ssid ?? 'Unknown';
      final bssid = network.bssid ?? 'Unknown';
      final encryptionType = getEncryptionType(network.capabilities);
      final signalStrength = network.signalLevel;
      
      // For now, use placeholder values for gateway/DNS
      // In production, you'd get these from actual network info
      final gatewayMac = 'placeholder'; // Would come from ARP table
      final gatewayIp = '192.168.1.1'; // Would come from network info
      final dnsServers = ['8.8.8.8', '8.8.4.4']; // Would come from network config
      final subnet = '192.168.1.0/24'; // Would come from network info
      
      // Skip if we don't have essential info
      if (bssid == 'Unknown' || ssid == 'Unknown') {
        return;
      }
      
      // Check for network changes (Evil Twin detection)
      final changeResult = await _fingerprintService.checkForChanges(
        bssid: bssid,
        ssid: ssid,
        gatewayMac: gatewayMac,
        gatewayIp: gatewayIp,
        dnsServers: dnsServers,
        encryptionType: encryptionType,
        subnet: subnet,
      );
      
      if (changeResult['hasChanges'] == true) {
        // Network has changed - possible Evil Twin attack!
        final severity = changeResult['severity'] as String;
        final changes = changeResult['changes'] as List<String>;
        
        print("🚨 Evil Twin detected for $ssid: ${changes.join(', ')}");
        
        // Show Evil Twin alert (delayed to avoid overlapping with other alerts)
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) {
            _showEvilTwinAlert(severity, changes, ssid);
          }
        });
        
        // Decrease trust score for suspicious changes
        await _fingerprintService.updateTrustScore(bssid, -20);
        
      } else if (changeResult['isNew'] == true) {
        // First time seeing this network - create fingerprint
        final fingerprint = await _fingerprintService.createFingerprint(
          bssid: bssid,
          ssid: ssid,
          gatewayMac: gatewayMac,
          gatewayIp: gatewayIp,
          dnsServers: dnsServers,
          encryptionType: encryptionType,
          signalStrength: signalStrength,
          subnet: subnet,
        );
        
        await _fingerprintService.saveFingerprint(fingerprint);
        print("✅ Created fingerprint for new network: $ssid");
        
      } else {
        // Network is unchanged - good!
        print("✅ Network verified: $ssid (no changes detected)");
        
        // Small trust score increase for consistent networks
        await _fingerprintService.updateTrustScore(bssid, 2);
      }
      
    } catch (e) {
      print("⚠️ Fingerprint check failed: $e");
    }
  }

  // ✅ NEW: Show Evil Twin attack alert
  void _showEvilTwinAlert(String severity, List<String> changes, String ssid) {
    final color = severity == 'critical' ? Colors.red : 
                  severity == 'high' ? Colors.orange : 
                  Colors.yellow[700]!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: color, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                severity == 'critical' ? '🚨 CRITICAL ALERT!' : 
                severity == 'high' ? '⚠️ High Risk Alert' : 
                '⚠️ Network Changed',
                style: TextStyle(color: color, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The network "$ssid" has changed significantly:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: changes.map((change) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                        Expanded(child: Text(change, style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This may be an Evil Twin attack!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'An attacker may have created a fake network with the same name to intercept your data.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('Recommended Actions:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• Disconnect immediately', style: TextStyle(fontSize: 12)),
              Text('• Verify network with owner', style: TextStyle(fontSize: 12)),
              Text('• Use a VPN if you must connect', style: TextStyle(fontSize: 12)),
              Text('• Avoid sensitive transactions', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('DISCONNECT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/trusted-networks');
            },
            child: Text('VIEW DETAILS'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CONTINUE ANYWAY', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String getEncryptionType(String capabilities) {
    if (capabilities.contains("WEP")) return "WEP";
    if (capabilities.contains("WPA3")) return "WPA3";
    if (capabilities.contains("WPA2")) return "WPA2";
    if (capabilities.contains("WPA")) return "WPA";
    return "Open/None";
  }

  String getSignalStrengthLabel(int dbm) {
    if (dbm >= -50) return "Excellent";
    if (dbm >= -60) return "Very Good";
    if (dbm >= -70) return "Good";
    if (dbm >= -80) return "Fair";
    return "Weak";
  }

  String getRiskLevel(int signalLevel, String encryptionType) {
    if (encryptionType == "WEP" || encryptionType == "Open/None") return "High";
    if (signalLevel <= -80) return "Medium";
    return "Low";
  }

  Color getRiskColor(String risk) {
    switch (risk) {
      case "Critical":
        return Colors.red.shade800;
      case "High":
        return Colors.redAccent;
      case "Medium":
        return Colors.orangeAccent;
      default:
        return Colors.green;
    }
  }

  IconData getSignalIcon(int dbm) {
    if (dbm >= -60) return Icons.wifi;
    if (dbm >= -70) return Icons.wifi;
    if (dbm >= -80) return Icons.wifi;
    return Icons.signal_wifi_off;
  }

  Color getSignalColor(int dbm) {
    if (dbm >= -50) return Colors.green;
    if (dbm >= -60) return Colors.lightGreen;
    if (dbm >= -70) return Colors.yellow;
    if (dbm >= -80) return Colors.orange;
    return Colors.red;
  }

  // Show alert for real high-risk networks detected during scan
  void _showRealThreatAlert(WifiNetwork network, String encryptionType, String riskLevel) {
    final networkKey = '${network.ssid}_${network.bssid}';
    
    // Don't show alert if we've already alerted for this network
    if (_alertedNetworks.contains(networkKey)) {
      return;
    }
    
    _alertedNetworks.add(networkKey);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text("⚠️ Security Risk Detected!", style: TextStyle(color: Colors.red))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Unsecured Network Found",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text("A network with weak or no encryption has been detected in your area."),
                    SizedBox(height: 12),
                    Text("SSID: ${network.ssid}", style: TextStyle(fontFamily: 'monospace')),
                    Text("BSSID: ${network.bssid}", style: TextStyle(fontFamily: 'monospace')),
                    Text("Encryption: $encryptionType", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Risk Level: $riskLevel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("🛡️ Security Recommendations:", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text("• Avoid connecting to open/unsecured networks"),
                    Text("• If you must connect, use a VPN"),
                    Text("• Do not access sensitive information"),
                    Text("• Enable 'Ask to Join Networks' on your device"),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text("Recommended VPN Apps:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildVpnButton("ProtonVPN", "Free & Secure", "ch.protonvpn.android"),
                    SizedBox(height: 8),
                    _buildVpnButton("Windscribe VPN", "10GB Free Monthly", "com.windscribe.vpn"),
                    SizedBox(height: 8),
                    _buildVpnButton("NordVPN", "Premium Security", "com.nordvpn.android"),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Understood"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildVpnButton(String name, String description, String packageName) {
    return InkWell(
      onTap: () async {
        try {
          await _vpnService.openVpnInPlayStore(packageName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening Play Store for $name...'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open Play Store. Please search manually.'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.security, color: Colors.blue, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Future<void> scanWifi() async {
    print('🔍 DEBUG Step 1: scanWifi() called');
    
    // Prevent duplicate scans
    if (_isScanning) {
      print('⏸️ DEBUG: Scan already in progress, skipping...');
      return;
    }

    print('🔍 DEBUG Step 2: Setting scanning state to true');
    setState(() {
      _isScanning = true;
      _alertedNetworks.clear();
    });

    print('🔍 DEBUG Step 3: Requesting permissions...');
    bool hasPermission = false;
    try {
      hasPermission = await _wifiService.requestPermissions();
      print('🔍 DEBUG Step 3 Result: Permission = $hasPermission');
    } catch (e) {
      print('❌ DEBUG Step 3 ERROR: Failed to request permissions: $e');
      setState(() => _isScanning = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Permission Error"),
          content: Text("Failed to request permissions: $e"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
        ),
      );
      return;
    }
    
    if (!hasPermission) {
      print('❌ DEBUG: Permission denied by user');
      setState(() => _isScanning = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Permission Required"),
          content: Text("WiFi scanning requires location permission. Please grant location access in Settings > Apps > WiFense > Permissions."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Request again
                scanWifi();
              },
              child: Text("TRY AGAIN"),
            ),
          ],
        ),
      );
      return;
    }

    print('🔍 DEBUG Step 4: Checking location service...');
    bool locationEnabled = false;
    try {
      locationEnabled = await checkLocationService(context);
      print('🔍 DEBUG Step 4 Result: Location service = $locationEnabled');
    } catch (e) {
      print('❌ DEBUG Step 4 ERROR: Failed to check location service: $e');
      setState(() => _isScanning = false);
      return;
    }
    
    if (!locationEnabled) {
      print('❌ DEBUG: Location service is disabled');
      setState(() => _isScanning = false);
      return;
    }

    print('🔍 DEBUG Step 5: Calling getWifiNetworks() with forceRefresh...');
    try {
      final networks = await _wifiService.getWifiNetworks(forceRefresh: true).timeout(
        Duration(seconds: 45),
        onTimeout: () {
          print('⏰ TIMEOUT: WiFi scan took too long');
          throw TimeoutException('WiFi scan timed out after 15 seconds');
        },
      );
      print('✅ DEBUG Step 5 SUCCESS: Found ${networks.length} networks');

      // Show message if using cached results
      if (networks.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan throttled by Android. Please wait 30 seconds between scans.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (networks.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${networks.length} networks'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (networks.isEmpty) {
        print('⚠️ DEBUG WARNING: No networks found!');
        print('   - Is WiFi turned on?');
        print('   - Are you in range of any networks?');
        print('   - Try toggling WiFi off and on');
      }
      
      // Print each network for debugging
      for (int i = 0; i < networks.length; i++) {
        print('  📡 Network ${i + 1}: ${networks[i].ssid} (${networks[i].bssid})');
      }
      
      if (!mounted) {
        print('⚠️ DEBUG: Widget not mounted, stopping');
        return;
      }
      
      print('🔍 DEBUG Step 6: Updating UI with ${networks.length} networks...');
      setState(() {
        _wifiList = networks.map((network) => _buildNetworkCard(network)).toList();
        _isScanning = false;
      });
      print('✅ DEBUG Step 6 SUCCESS: UI updated, scanning = false');
      
      // Check for real high-risk networks and show alerts
      print('🔍 DEBUG Step 7: Checking for high-risk networks...');
      int highRiskCount = 0;
      for (var network in networks) {
        final encryptionType = getEncryptionType(network.capabilities);
        final riskLevel = getRiskLevel(network.signalLevel, encryptionType);
        
        if (riskLevel == 'High') {
          highRiskCount++;
          print('⚠️ DEBUG: High-risk network found: ${network.ssid} ($encryptionType)');
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _showRealThreatAlert(network, encryptionType, riskLevel);
            }
          });
        }
      }
      print('✅ DEBUG Step 7 SUCCESS: Found $highRiskCount high-risk networks');
      
      print('🔍 DEBUG Step 8: Saving scan to database...');
      await _saveScanToDatabase(networks);
      print('✅ DEBUG Step 8 SUCCESS: Scan saved to database');
      
      print('🎉 DEBUG: Scan completed successfully!');
      
    } catch (e, stackTrace) {
      print('❌ DEBUG Step 5 CRITICAL ERROR: $e');
      print('❌ DEBUG Stack trace:');
      print(stackTrace);
      
      if (!mounted) return;
      
      setState(() => _isScanning = false);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Scan Failed"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Failed to scan Wi-Fi networks."),
                SizedBox(height: 16),
                Text("Error Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$e',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                SizedBox(height: 16),
                Text("Troubleshooting:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text("• Check if WiFi is turned on"),
                Text("• Enable Location services"),
                Text("• Grant location permission"),
                Text("• Restart the app"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CLOSE"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                scanWifi(); // Try again
              },
              child: Text("TRY AGAIN"),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNetworkCard(WifiNetwork network) {
    final signalLabel = getSignalStrengthLabel(network.signalLevel);
    final encryptionType = getEncryptionType(network.capabilities);
    final riskLevel = getRiskLevel(network.signalLevel, encryptionType);
    final riskColor = getRiskColor(riskLevel);
    final wifiIcon = getSignalIcon(network.signalLevel);
    final wifiColor = getSignalColor(network.signalLevel);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              riskLevel == "Low" 
                  ? Colors.green.withOpacity(isDarkMode ? 0.05 : 0.03)
                  : riskLevel == "Medium"
                      ? Colors.orange.withOpacity(isDarkMode ? 0.05 : 0.03)
                      : Colors.red.withOpacity(isDarkMode ? 0.05 : 0.03),
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: wifiColor.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: wifiColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(wifiIcon, size: 20, color: Colors.white),
          ),
          title: Text(
            "SSID: ${network.ssid}", 
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                "BSSID: ${network.bssid}",
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Signal: ${network.signalLevel} dBm ($signalLabel)",
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 4),
              Text(
                "Frequency: ${network.frequency} MHz",
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 4),
              Text(
                "Encryption: $encryptionType",
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Risk: $riskLevel",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVpnRecommendations() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.vpn_key, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text("Recommended VPN Apps")),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVpnButton("ProtonVPN", "Free & Secure", "ch.protonvpn.android"),
                SizedBox(height: 8),
                _buildVpnButton("Windscribe VPN", "10GB Free Monthly", "com.windscribe.vpn"),
                SizedBox(height: 8),
                _buildVpnButton("NordVPN", "Premium Security", "com.nordvpn.android"),
                SizedBox(height: 8),
                _buildVpnButton("ExpressVPN", "Fast & Reliable", "com.expressvpn.vpn"),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showFullScreenBlocker(String ssid, String encryption) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DismissibleUnsafeConnectionBlocker(
          ssid: ssid,
          encryption: encryption,
          onDismiss: () {
            Navigator.of(context).pop();
            // Banner stays visible
          },
          onVpnTap: (packageName) async {
            try {
              await _vpnService.openVpnInPlayStore(packageName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening Play Store...'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not open Play Store'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void dispose() {
    _connectionMonitor.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundPattern(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text("Wi-Fi Scanner"),
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Persistent banner at top
              if (_showUnsafeBanner)
                UnsafeConnectionBanner(
                  ssid: _unsafeNetworkSsid,
                  encryption: _unsafeNetworkEncryption,
                  onTapGetVpn: () {
                    _showVpnRecommendations();
                  },
                  onTapDetails: () {
                    _showFullScreenBlocker(_unsafeNetworkSsid, _unsafeNetworkEncryption);
                  },
                  // ✅ NEW: Handle banner dismissal
                  onDismiss: () {
                    setState(() {
                      _showUnsafeBanner = false;
                      // Track dismissed network to prevent re-showing
                      _dismissedNetworks.add(_unsafeNetworkSsid);
                      // ✅ Also clear blocker tracking so it can show again if reconnected
                      _shownBlockerForNetworks.remove(_unsafeNetworkSsid);
                    });
                  },
                ),
              
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isScanning ? null : scanWifi,
                              child: _isScanning
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text("Scanning..."),
                                      ],
                                    )
                                  : Text("Scan Networks"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Detected Networks:",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _isScanning
                            ? Center(child: CircularProgressIndicator())
                            : _wifiList.isEmpty
                                ? Center(
                                    child: Text(
                                      "No networks found",
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color
                                      ),
                                    ),
                                  )
                                : ListView(children: _wifiList),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}