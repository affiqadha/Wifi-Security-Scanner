import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'preferences_service.dart';
import 'wifi_platform_service.dart';

/// Enhanced Background Monitoring Service
/// Shows notification + dialog for dangerous connections
class BackgroundMonitoringService {
  static final BackgroundMonitoringService _instance = 
      BackgroundMonitoringService._internal();
  factory BackgroundMonitoringService() => _instance;
  BackgroundMonitoringService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  final WifiPlatformService _wifiService = WifiPlatformService();
  final Connectivity _connectivity = Connectivity();
  
  // For showing dialogs
  BuildContext? _context;
  
  // ✅ NEW: Callback for dangerous network detection (for home screen banner)
  Function(WifiNetwork)? _onDangerousNetworkDetected;
  Function()? _onDangerousNetworkCleared;
  
  // Timers
  Timer? _scanTimer;
  Timer? _connectionMonitor;
  bool _isMonitoring = false;
  
  // Track warned networks
  final Set<String> _warnedNetworks = {};
  final List<DangerousNetwork> _currentDangerousNetworks = [];
  
  String? _lastConnectedSSID;
  WifiNetwork? _lastDangerousNetwork; // ✅ Store last dangerous network
  bool _isInitialized = false;

  /// Set context for showing dialogs
  void setContext(BuildContext context) {
    _context = context;
    print('✅ Context set for dialog display');
  }

  /// ✅ NEW: Set callback for when dangerous network is detected (for banner)
  void setOnDangerousNetworkDetected(Function(WifiNetwork) callback) {
    _onDangerousNetworkDetected = callback;
    print('✅ Dangerous network callback registered');
  }

  /// ✅ NEW: Set callback for when dangerous network is cleared (for banner)
  void setOnDangerousNetworkCleared(Function() callback) {
    _onDangerousNetworkCleared = callback;
    print('✅ Dangerous network clear callback registered');
  }

  /// Initialize background monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    // Add notification tap handler
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📱 NOTIFICATION TAPPED!');
        print('   Action ID: ${response.actionId}');
        print('   Payload: ${response.payload}');
        print('   Notification ID: ${response.id}');
        print('   Last dangerous network: ${_lastDangerousNetwork?.ssid}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        try {
          // ✅ Check if this is a connection warning notification
          if (response.id == 8888 && _lastDangerousNetwork != null) {
            print('🎯 Connection warning notification (ID: 8888) tapped');
            print('📱 Dangerous network available: ${_lastDangerousNetwork!.ssid}');
            
            // Small delay to ensure app transitions to foreground
            await Future.delayed(Duration(milliseconds: 800));
            
            // The HomeScreen will detect the pending dangerous network via didChangeAppLifecycleState
            print('✅ App will check for pending dangerous network on resume');
            return;
          }
          
          // Fallback: Show dialog if we have a context
          if (_context != null && _lastDangerousNetwork != null) {
            print('✅ Context available, showing dialog');
            
            final network = _lastDangerousNetwork!;
            print('📱 About to show dialog for: ${network.ssid}');
            
            // Show dialog
            await _showDangerousConnectionDialog(network);
            
            print('✅ Dialog shown successfully!');
          } else {
            print('⚠️ Cannot show dialog - Context or network info missing');
          }
        } catch (e, stackTrace) {
          print('❌ Error in notification tap handler:');
          print('   Error: $e');
          print('   Stack: $stackTrace');
        }
      },
    );

    _isInitialized = true;
    print('✅ Background Monitoring Service initialized (Enhanced)');
  }

  /// Start periodic scanning
  Future<void> startPeriodicScanning() async {
    final prefs = await PreferencesService.getInstance();
    
    if (!prefs.backgroundMonitoring) {
      await stopPeriodicScanning();
      return;
    }

    await startTimerMonitoring();
    await startConnectionMonitoring();
    
    print('✅ Background monitoring started');
  }

  /// Stop periodic scanning
  Future<void> stopPeriodicScanning() async {
    stopTimerMonitoring();
    stopConnectionMonitoring();
    print('⏸️ Background monitoring stopped');
  }

  /// Start timer-based network scanning
  Future<void> startTimerMonitoring() async {
    if (_isMonitoring) {
      print('⚠️ Timer monitoring already running');
      return;
    }
    
    _isMonitoring = true;
    print('🎯 Starting timer-based monitoring...');
    
    await _scanForDangerousNetworks();
    
    final prefs = await PreferencesService.getInstance();
    final intervalMinutes = prefs.scanFrequency;
    
    _scanTimer = Timer.periodic(Duration(minutes: intervalMinutes), (timer) async {
      await _scanForDangerousNetworks();
    });
    
    print('✅ Timer monitoring started (${intervalMinutes}min interval)');
  }

  /// Stop timer-based monitoring
  void stopTimerMonitoring() {
    _scanTimer?.cancel();
    _isMonitoring = false;
    print('⏸️ Timer monitoring stopped');
  }

  /// Start connection monitoring
  Future<void> startConnectionMonitoring() async {
    print('🎯 Starting connection monitoring...');

    _connectionMonitor = Timer.periodic(Duration(seconds: 15), (timer) async {
      await _checkCurrentConnection();
    });

    print('✅ Connection monitoring started (15sec interval)');
  }

  /// Stop connection monitoring
  void stopConnectionMonitoring() {
    _connectionMonitor?.cancel();
    print('⏸️ Connection monitoring stopped');
  }

  /// Check current WiFi connection
  Future<void> _checkCurrentConnection() async {
    try {
      final currentSSID = await _wifiService.getCurrentNetwork();
      
      if (currentSSID == null || currentSSID.isEmpty) {
        if (_lastConnectedSSID != null) {
          print('📴 Disconnected from: $_lastConnectedSSID');
          // ✅ NEW: Clear the dangerous network banner when disconnecting
          _lastDangerousNetwork = null;
          _onDangerousNetworkCleared?.call(); // ✅ Notify to clear banner
          print('🧹 Cleared dangerous network banner on disconnect');
        }
        _lastConnectedSSID = null;
        return;
      }
      
      if (currentSSID == _lastConnectedSSID) {
        // ✅ NEW: Even if same connection, check if VPN status changed
        if (_lastDangerousNetwork != null) {
          final vpnActive = await _checkVPNStatus();
          if (vpnActive) {
            print('✅ VPN became active - clearing dangerous banner');
            _lastDangerousNetwork = null;
            _onDangerousNetworkCleared?.call(); // ✅ Notify to clear banner
          }
        }
        return; // Same connection
      }
      
      print('🔄 WiFi connection changed: $_lastConnectedSSID → $currentSSID');
      _lastConnectedSSID = currentSSID;
      
      // Check security immediately
      await _checkConnectionSecurity(currentSSID);
      
    } catch (e) {
      print('❌ Connection check error: $e');
    }
  }

  /// Check security of current connection
  Future<void> _checkConnectionSecurity(String ssid) async {
    try {
      WifiNetwork connectedNetwork;
      
      // Try to get network details using cached results
      try {
        final networks = await _wifiService.getWifiNetworks(forceRefresh: false);
        connectedNetwork = networks.firstWhere(
          (n) => n.ssid == ssid,
          orElse: () => WifiNetwork(
            ssid: ssid,
            bssid: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
            signalLevel: 0,
            isSecure: false, // Assume dangerous if can't verify
            frequency: 0,
            capabilities: '',
          ),
        );
      } catch (e) {
        print('⚠️ WiFi scan failed, assuming dangerous: $e');
        connectedNetwork = WifiNetwork(
          ssid: ssid,
          bssid: 'unknown_${DateTime.now().millisecondsSinceEpoch}',
          signalLevel: 0,
          isSecure: false,
          frequency: 0,
          capabilities: '',
        );
      }
      
      final encryption = _getEncryptionType(connectedNetwork.capabilities);
      final isDangerous = encryption == 'Open/None' || encryption == 'WEP';
      
      print('🔍 Network: $ssid, Encryption: $encryption, Dangerous: $isDangerous');
      
      if (isDangerous) {
        final vpnActive = await _checkVPNStatus();
        print('🛡️ VPN Status: ${vpnActive ? "Active" : "NOT Active"}');
        
        if (!vpnActive) {
          // NO VPN - Send notification ONLY (no immediate dialog)
          print('⚠️ DANGER: No VPN protection!');
          _lastDangerousNetwork = connectedNetwork; // ✅ Store for later
          await _sendConnectionWarning(connectedNetwork, vpnActive);
          // ✅ NEW: Notify home screen to show banner immediately
          _onDangerousNetworkDetected?.call(connectedNetwork);
          print('📡 Callback triggered: Dangerous network detected');
          // ❌ REMOVED: Immediate dialog - only show when notification tapped
          // await _showDangerousConnectionDialog(connectedNetwork);
        } else {
          // VPN Active - Clear the dangerous banner since user is protected
          print('✅ VPN is protecting user');
          _lastDangerousNetwork = null; // ✅ Clear banner when VPN is active
          print('🧹 Cleared dangerous network banner - VPN is active');
          _onDangerousNetworkCleared?.call(); // ✅ Notify to clear banner
          await _sendVPNProtectedNotification(connectedNetwork);
        }
      } else {
        print('✅ Connected to secure network: $ssid ($encryption)');
      }
      
    } catch (e) {
      print('❌ Security check error: $e');
    }
  }

  /// Show in-app danger dialog
  Future<void> _showDangerousConnectionDialog(WifiNetwork network) async {
    if (_context == null) {
      print('⚠️ No context available for dialog');
      return;
    }
    
    print('📱 Showing danger dialog for ${network.ssid}');
    
    try {
      await showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.red.shade50,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dangerous Network!',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi, color: Colors.red.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              network.ssid,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.lock_open, color: Colors.red.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Encryption: Open/None',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.red.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'VPN Status: NOT ACTIVE',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '⚠️ YOUR DATA IS EXPOSED!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'This network has no encryption. Anyone nearby can intercept your data including:',
                  style: TextStyle(color: Colors.red.shade800),
                ),
                SizedBox(height: 8),
                _buildWarningItem('Passwords and login credentials'),
                _buildWarningItem('Banking and payment information'),
                _buildWarningItem('Personal messages and emails'),
                _buildWarningItem('Browsing history'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  print('⚠️ User acknowledged danger');
                },
                child: Text(
                  'I Understand the Risk',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              ElevatedButton.icon(
                icon: Icon(Icons.shield),
                label: Text('Enable VPN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  print('🛡️ User tapped Enable VPN button');
                  Navigator.of(context).pop();
                  await openVPNApps();
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('❌ Error showing dialog: $e');
    }
  }

  /// Build warning item widget
  Widget _buildWarningItem(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.red.shade800)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Check if VPN is active
  Future<bool> _checkVPNStatus() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      print('🔍 Connectivity check result: $connectivityResult');
      
      // connectivityResult is a List<ConnectivityResult>
      final isVpn = connectivityResult.contains(ConnectivityResult.vpn);
      print('🔍 VPN detected: $isVpn');
      
      return isVpn;
    } catch (e) {
      print('⚠️ VPN check failed: $e');
      return false;
    }
  }

  /// Send connection warning notification
  Future<void> _sendConnectionWarning(WifiNetwork network, bool vpnActive) async {
    final prefs = await PreferencesService.getInstance();
    if (!prefs.notificationsEnabled) {
      print('⚠️ Notifications disabled in settings');
      return;
    }

    final connectionKey = 'notif_${network.ssid}_${network.bssid}';
    if (_warnedNetworks.contains(connectionKey)) {
      print('⏭️ Already warned about this connection');
      return;
    }

    final title = '🚨 URGENT: Dangerous Network!';
    final body = 'Connected to ${network.ssid} (Open Network)\n\n⚠️ Tap here to protect yourself';
  
    final androidDetails = AndroidNotificationDetails(
      'urgent_connection_warnings',
      'Connection Warnings',
      channelDescription: 'Critical security warnings',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      ongoing: false,
      autoCancel: false,
      enableLights: true,
      color: const Color(0xFFFF0000),
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '⚠️ Tap to enable VPN protection',
      ),
    );
    
    await _notifications.show(
      8888,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: network.ssid,
    );
    
    _warnedNetworks.add(connectionKey);
    print('🚨 Connection warning notification sent (ID: 8888, SSID: ${network.ssid})');
  }

  /// VPN Protected notification
  Future<void> _sendVPNProtectedNotification(WifiNetwork network) async {
    final title = '✅ VPN Protection Active';
    final body = 'Connected to ${network.ssid}\nYour traffic is encrypted. You\'re safe!';
    
    final androidDetails = AndroidNotificationDetails(
      'vpn_protected',
      'VPN Protection Status',
      channelDescription: 'Confirms VPN protection is active',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      color: const Color(0xFF00C853),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '✅ Protected',
      ),
    );
    
    await _notifications.show(
      7777,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
    
    print('✅ VPN protected notification sent');
  }

  /// Open VPN apps on Play Store
  Future<void> openVPNApps() async {
    try {
      print('🎯 Opening VPN app on Play Store...');
      
      // ✅ VPN app IDs and their package names (in priority order)
      final vpnApps = [
        ('com.windscribe.vpn', 'Windscribe'),
        ('com.opera.browser', 'Opera Browser'),
        ('com.tunnelbear.android', 'TunnelBear'),
        ('com.anchorfree.hotspotshield.vpn', 'Hotspot Shield'),
      ];
      
      // Try opening each VPN app's Play Store page in order
      for (final (packageName, appName) in vpnApps) {
        try {
          print('📱 Opening Play Store for: $appName');
          final playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';
          
          await launchUrl(
            Uri.parse(playStoreUrl),
            mode: LaunchMode.externalApplication,
          );
          
          print('✅ Opened Play Store for: $appName');
          print('📌 User can now tap "Open" to launch the VPN app');
          return;
        } catch (e) {
          print('⏭️ Play Store unavailable for $appName: $e');
          continue;
        }
      }
      
      // Fallback: Open generic VPN search
      print('⚠️ Opening generic VPN search...');
      try {
        final searchUrl = 'https://play.google.com/store/search?q=vpn&c=apps';
        await launchUrl(
          Uri.parse(searchUrl),
          mode: LaunchMode.externalApplication,
        );
        print('✅ Opened Play Store VPN search');
        return;
      } catch (e) {
        print('❌ Failed to open Play Store: $e');
      }
      
    } catch (e) {
      print('❌ Error in openVPNApps: $e');
    }
  }

  /// Scan for dangerous networks (PROXIMITY - Disabled notifications)
  Future<void> _scanForDangerousNetworks() async {
    try {
      print('🔍 Scanning for dangerous networks...');
      
      // ✅ NEW: Skip scan if VPN is active (Android blocks WiFi scan with VPN for security)
      final vpnActive = await _checkVPNStatus();
      if (vpnActive) {
        print('⏭️ Skipping WiFi scan - VPN is active (user is protected)');
        return;
      }
      
      final networks = await _wifiService.getWifiNetworks();
      final List<DangerousNetwork> dangerousNetworks = [];
      int newDangerousCount = 0;
      
      for (var network in networks) {
        final encryption = _getEncryptionType(network.capabilities);
        final riskLevel = _getRiskLevel(encryption);
        
        if (riskLevel == 'HIGH') {
          final dangerous = DangerousNetwork(
            ssid: network.ssid,
            bssid: network.bssid,
            encryption: encryption,
            signalStrength: network.signalLevel,
          );
          
          dangerousNetworks.add(dangerous);
          
          final networkKey = '${network.ssid}_${network.bssid}';
          if (!_warnedNetworks.contains(networkKey)) {
            print('🔍 Dangerous network nearby: ${network.ssid} ($encryption)');
            // ❌ DISABLED: No proximity notifications
            // await _sendDangerousNetworkWarning(dangerous);
            _warnedNetworks.add(networkKey);
            newDangerousCount++;
          }
        }
      }
      
      _currentDangerousNetworks.clear();
      _currentDangerousNetworks.addAll(dangerousNetworks);
      
      print('✅ Scan complete: ${dangerousNetworks.length} dangerous, $newDangerousCount new');
      
      // ✅ NEW: Send startup notification if this is the first scan and dangerous networks found
      if (newDangerousCount > 0 && dangerousNetworks.isNotEmpty) {
        await _sendStartupDangerousNetworksNotification(dangerousNetworks);
      }
      
    } catch (e) {
      print('❌ Scan error: $e');
    }
  }

  /// ✅ NEW: Send notification on app startup about dangerous networks nearby
  Future<void> _sendStartupDangerousNetworksNotification(List<DangerousNetwork> networks) async {
    final prefs = await PreferencesService.getInstance();
    if (!prefs.notificationsEnabled) {
      print('⚠️ Notifications disabled in settings');
      return;
    }

    // Check if we've already sent startup notification in this session
    if (_warnedNetworks.contains('_startup_notified')) {
      return;
    }

    final networkList = networks.take(3).map((n) => n.ssid).join(', ');
    final title = '🚨 Dangerous WiFi Networks Detected!';
    final body = networks.length == 1 
      ? 'Found 1 unsafe network: $networkList\n\n⚠️ Avoid connecting without VPN'
      : 'Found ${networks.length} unsafe networks: $networkList\n\n⚠️ Avoid connecting without VPN';
  
    final androidDetails = AndroidNotificationDetails(
      'startup_warnings',
      'WiFi Safety Alerts',
      channelDescription: 'Alerts about dangerous networks on app startup',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
      enableLights: true,
      color: const Color(0xFFFF9800),
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '⚠️ Nearby dangerous networks',
      ),
    );
    
    await _notifications.show(
      9999,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: 'startup_dangerous_networks',
    );
    
    _warnedNetworks.add('_startup_notified');
    print('🚨 Startup dangerous networks notification sent (Found ${networks.length} networks)');
  }

  String _getEncryptionType(String capabilities) {
    if (capabilities.isEmpty || capabilities == '[]') return 'Open/None';
    if (capabilities.contains('WEP')) return 'WEP';
    if (capabilities.contains('WPA3')) return 'WPA3';
    if (capabilities.contains('WPA2')) return 'WPA2';
    if (capabilities.contains('WPA')) return 'WPA';
    return 'Open/None';
  }

  String _getRiskLevel(String encryption) {
    if (encryption == 'Open/None' || encryption == 'WEP') return 'HIGH';
    if (encryption == 'WPA') return 'MEDIUM';
    return 'LOW';
  }

  List<DangerousNetwork> getCurrentDangerousNetworks() {
    return List.unmodifiable(_currentDangerousNetworks);
  }

  // ✅ NEW: Get last dangerous network
  WifiNetwork? getLastDangerousNetwork() {
    return _lastDangerousNetwork;
  }

  void clearWarningHistory() {
    _warnedNetworks.clear();
    _lastConnectedSSID = null;
    print('🧹 Warning history cleared');
  }

  Future<void> reset() async {
    stopTimerMonitoring();
    stopConnectionMonitoring();
    clearWarningHistory();
    await startTimerMonitoring();
    await startConnectionMonitoring();
    print('🔄 Monitoring reset');
  }

  Future<void> triggerImmediateScan() async {
    await _scanForDangerousNetworks();
  }

  Future<void> updateScanFrequency(int minutes) async {
    if (_isMonitoring) {
      stopTimerMonitoring();
      await startTimerMonitoring();
    }
  }

  Future<void> showThreatNotification({
    required String title,
    required String body,
    required String severity,
    String? payload,
  }) async {
    final prefs = await PreferencesService.getInstance();
    if (!prefs.notificationsEnabled) return;

    final androidDetails = AndroidNotificationDetails(
      'threats',
      'Security Threats',
      importance: Importance.high,
      priority: Priority.high,
      playSound: prefs.soundAlerts,
      enableVibration: prefs.vibrationAlerts,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> showNetworkChangeNotification({
    required String ssid,
    required List<String> changes,
  }) async {
    await showThreatNotification(
      title: 'Network Changed: $ssid',
      body: 'Changes detected: ${changes.join(', ')}',
      severity: 'high',
      payload: 'network_change',
    );
  }
}

class DangerousNetwork {
  final String ssid;
  final String bssid;
  final String encryption;
  final int signalStrength;
  
  DangerousNetwork({
    required this.ssid,
    required this.bssid,
    required this.encryption,
    required this.signalStrength,
  });
}
