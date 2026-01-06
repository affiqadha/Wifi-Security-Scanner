import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'wifi_platform_service.dart';
import 'vpn_service.dart';
import 'preferences_service.dart';
import 'network_fingerprinting_service.dart';
import '../database/database_helper.dart';

/// ✅ ENHANCED WiFi Connection Monitor
/// 
/// Real-time monitoring every 15 seconds for:
/// - Unsafe encryption (Open, WEP)
/// - VPN status (NEW: detects disconnection!)
/// - Evil Twin attacks
/// 
/// Features:
/// - Shows notifications
/// - Shows dialogs
/// - Shows banners
/// - Auto-scan on network change
/// - VPN disconnection alerts (NEW!)
class WifiConnectionMonitor {
  final WifiPlatformService _wifiService = WifiPlatformService();
  final VpnService _vpnService = VpnService();
  final NetworkFingerprintingService _fingerprintService = NetworkFingerprintingService();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final Connectivity _connectivity = Connectivity();
  
  Timer? _monitorTimer;
  Timer? _autoScanTimer;
  String? _lastConnectedNetwork;
  String? _lastBssid;
  bool _isMonitoring = false;
  bool _fingerprintInitialized = false;
  bool _notificationsInitialized = false;
  
  // ✅ NEW: Track last VPN state and alert state
  bool? _lastVpnState;
  String? _lastAlertedSsid;
  
  // Callback when unsafe connection detected without VPN
  Function(String ssid, String encryption)? onUnsafeConnectionDetected;
  
  // ✅ NEW: Callback when VPN disconnects on unsafe network
  Function()? onDangerousNetworkClear;
  
  // Callback for Evil Twin detection
  Function(String ssid, List<String> changes, String severity)? onEvilTwinDetected;
  
  // Callback for auto-scan trigger
  Function()? onAutoScanTrigger;
  
  // Track alerted Evil Twins to avoid spam
  final Set<String> _alertedEvilTwins = {};
  
  /// Initialize notifications
  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    _notificationsInitialized = true;
    print('✅ Connection Monitor: Notifications initialized');
  }
  
  /// Initialize fingerprinting service
  Future<void> initialize() async {
    if (_fingerprintInitialized) return;
    
    try {
      // Initialize notifications
      await _initializeNotifications();
      
      // Initialize fingerprinting
      final db = await DatabaseHelper.instance.database;
      await _fingerprintService.initialize(db);
      _fingerprintInitialized = true;
      print('✅ Connection Monitor: Fingerprinting initialized');
    } catch (e) {
      print('⚠️ Connection Monitor: Initialization failed - $e');
    }
  }
  
  /// Start monitoring WiFi connections
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    
    // Initialize
    initialize();
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎯 WiFi Connection Monitor Started');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('   - Unsafe encryption detection ✅');
    print('   - VPN status monitoring ✅');
    print('   - VPN disconnection alerts ✅ (NEW!)');
    print('   - Real-time Evil Twin detection ✅');
    print('   - Auto-scan on network change ✅');
    print('   - Notifications enabled ✅');
    print('   - Monitoring interval: 15 seconds');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // ✅ REAL-TIME MONITORING: Check every 15 seconds
    _monitorTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
      await _checkConnection();
    });

    // Auto-scan monitoring
    _autoScanTimer = Timer.periodic(Duration(seconds: 15), (timer) async {
      await _checkForAutoScan();
    });
  }
  
  /// Check current connection and detect threats
  Future<void> _checkConnection() async {
    try {
      final currentNetwork = await _wifiService.getCurrentNetwork();
      
      // No network connected
      if (currentNetwork == null || currentNetwork.isEmpty) {
        return;
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔍 Connection Check for: $currentNetwork');
      
      // ✅ NEW: Check VPN status first
      final connectivityResult = await _connectivity.checkConnectivity();
      final isVpnActive = connectivityResult.contains(ConnectivityResult.vpn);
      
      print('🔍 VPN Status: ${isVpnActive ? "Active ✅" : "Inactive ❌"}');
      
      // Get network details
      final networkInfo = await _wifiService.getCurrentNetworkInfo();
      if (networkInfo == null) {
        print('⚠️ No network info available');
        return;
      }
      
      final bssid = networkInfo['bssid'] ?? '';
      final encryption = networkInfo['encryption'] ?? '';
      
      print('   BSSID: $bssid');
      print('   Encryption: $encryption');
      print('   Gateway MAC: ${networkInfo['gatewayMac']}');
      print('   Gateway IP: ${networkInfo['gatewayIp']}');
      print('   DNS: ${networkInfo['dnsServers']}');
      
      // ✅ CHECK 1: Unsafe encryption detection
      final isUnsafeNetwork = _isUnsafeEncryption(encryption);
      
      if (isUnsafeNetwork) {
        print('⚠️ Network is unsafe: $currentNetwork ($encryption)');
        print('🔍 VPN State Check:');
        print('   - Last VPN State: $_lastVpnState');
        print('   - Current VPN State: $isVpnActive');
        print('   - Last Alerted SSID: $_lastAlertedSsid');
        
        // ✅ NEW: Check for VPN state changes
        if (_lastVpnState != null && _lastVpnState == true && !isVpnActive) {
          // VPN was active, now it's not - user disconnected VPN!
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('🚨 VPN DISCONNECTION DETECTED!');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('   Network: $currentNetwork ($encryption)');
          print('   Sending notification...');
          
          // Send VPN disconnection notification
          await _showVpnDisconnectedNotification(currentNetwork, encryption);
          
          // IMPORTANT: Re-show dangerous network banner
          print('📱 Triggering banner callback...');
          if (onUnsafeConnectionDetected != null) {
            onUnsafeConnectionDetected!(currentNetwork, encryption);
            print('✅ Banner callback executed');
          } else {
            print('❌ Banner callback is null!');
          }
          
          // Mark as alerted
          _lastAlertedSsid = currentNetwork;
        }
        
        // ✅ CRITICAL: ALWAYS show banner when VPN is off on unsafe network
        // This ensures banner appears even after app resumes from background
        if (!isVpnActive) {
          // Trigger banner callback every check cycle when VPN is off
          if (onUnsafeConnectionDetected != null) {
            onUnsafeConnectionDetected!(currentNetwork, encryption);
          }
          
          // Only log once to avoid spam
          if (_lastAlertedSsid != currentNetwork) {
            print('⚠️ Unsafe network without VPN: $currentNetwork ($encryption)');
            _lastAlertedSsid = currentNetwork;
          }
        }
        
        // ✅ NEW: Clear alert if VPN is now active
        if (isVpnActive && _lastAlertedSsid == currentNetwork) {
          print('✅ VPN now active - clearing dangerous network alert');
          
          if (onDangerousNetworkClear != null) {
            onDangerousNetworkClear!();
          }
          
          // Send VPN protection notification
          await _showVpnProtectedNotification(currentNetwork, encryption);
          
          _lastAlertedSsid = null;
        }
      }
      
      // ✅ Store VPN state for next check
      _lastVpnState = isVpnActive;
      
      // ✅ CHECK 2: Evil Twin detection
      if (_fingerprintInitialized && bssid.isNotEmpty) {
        await _checkForEvilTwin(currentNetwork, bssid, networkInfo);
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e) {
      print('❌ Connection check error: $e');
    }
  }
  
  /// Check if encryption is unsafe
  bool _isUnsafeEncryption(String encryption) {
    final unsafe = ['Open', 'WEP', 'None', ''];
    return unsafe.contains(encryption);
  }
  
  /// ✅ NEW: Show notification when VPN is disconnected on unsafe network
  Future<void> _showVpnDisconnectedNotification(String ssid, String encryption) async {
    if (!_notificationsInitialized) return;
    
    try {
      print('🔔 Sending VPN disconnected notification...');
      
      final androidDetails = AndroidNotificationDetails(
        'vpn_disconnected_channel',
        'VPN Disconnection Alerts',
        channelDescription: 'Alerts when VPN disconnects on unsafe networks',
        importance: Importance.max,
        priority: Priority.high,
        color: Color.fromARGB(255, 255, 87, 34), // Deep orange
        playSound: true,
        enableVibration: true,
        ticker: '⚠️ VPN DISCONNECTED!',
        styleInformation: BigTextStyleInformation(
          'You are connected to "$ssid" ($encryption) without VPN protection.\n\n'
          '🔓 Your data is NOT encrypted!\n'
          '⚠️ Attackers can intercept your traffic.\n\n'
          'Recommended Action: Enable VPN immediately or disconnect from this network.',
          htmlFormatBigText: false,
          contentTitle: '⚠️ VPN DISCONNECTED!',
          summaryText: 'You are vulnerable',
        ),
        category: AndroidNotificationCategory.alarm,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        8888, // Unique ID for VPN disconnection
        '⚠️ VPN DISCONNECTED!',
        'Unsafe network "$ssid" - Enable VPN now!',
        notificationDetails,
      );
      
      print('✅ VPN disconnected notification sent');
      
    } catch (e) {
      print('⚠️ Failed to show VPN disconnection notification: $e');
    }
  }
  
  /// ✅ Check for Evil Twin attacks
  Future<void> _checkForEvilTwin(
    String ssid,
    String bssid,
    Map<String, dynamic> networkInfo,
  ) async {
    try {
      final encryption = networkInfo['encryption'] ?? '';
      final gatewayMac = networkInfo['gatewayMac'] ?? '';
      final gatewayIp = networkInfo['gatewayIp'] ?? '';
      final dnsServers = List<String>.from(networkInfo['dnsServers'] ?? []);
      final subnet = networkInfo['subnet'] ?? '';
      
      // ✅ STEP 1: Check if we have ANY fingerprint for this SSID
      final allFingerprints = await _fingerprintService.getAllFingerprints();
      final previousFingerprints = allFingerprints.where((fp) => fp.ssid == ssid).toList();
      
      if (previousFingerprints.isEmpty) {
        // First time seeing this SSID - create fingerprint
        print('📝 First time seeing SSID: $ssid (BSSID: $bssid)');
        final fingerprint = await _fingerprintService.createFingerprint(
          bssid: bssid,
          ssid: ssid,
          gatewayMac: gatewayMac,
          gatewayIp: gatewayIp,
          dnsServers: dnsServers,
          encryptionType: encryption,
          signalStrength: networkInfo['signalStrength'] ?? -100,
          subnet: subnet,
        );
        
        await _fingerprintService.saveFingerprint(fingerprint);
        print('✅ Fingerprint saved for: $ssid');
        return;
      }
      
      // ✅ STEP 2: Check if we've seen this specific BSSID before
      NetworkFingerprint? currentBssidFingerprint;
      try {
        currentBssidFingerprint = previousFingerprints.firstWhere(
          (fp) => fp.networkId == bssid,
        );
      } catch (e) {
        // BSSID not found - this is a new BSSID for this SSID
        currentBssidFingerprint = null;
      }
      
      if (currentBssidFingerprint == null) {
        // ⚠️ NEW BSSID FOR KNOWN SSID - Potential Evil Twin!
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('⚠️ NEW BSSID detected for known SSID!');
        print('   SSID: $ssid');
        print('   Previous BSSIDs: ${previousFingerprints.map((e) => e.networkId).toList()}');
        print('   Current BSSID: $bssid');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        // Use the FIRST fingerprint we saw for this SSID as reference
        final referenceFingerprint = previousFingerprints.first;
        
        // ✅ STEP 3: Manual comparison across BSSIDs
        final manualChanges = <String>[];
        int manualThreatScore = 0;
        
        // Check 1: Gateway MAC (different BSSID = different device)
        if (referenceFingerprint.gatewayMac != gatewayMac) {
          final isMesh = await _fingerprintService.isLegitimeMeshNetwork(
            ssid: ssid,
            oldMac: referenceFingerprint.gatewayMac,
            newMac: gatewayMac,
          );
          
          if (!isMesh) {
            manualChanges.add('Gateway MAC changed: ${referenceFingerprint.gatewayMac} → $gatewayMac');
            manualThreatScore += 40;
            print('⚠️ Gateway MAC changed (not mesh): +40 points');
          } else {
            print('✅ Legitimate mesh roaming detected');
            
            // Save new BSSID for mesh network and exit
            final newFingerprint = await _fingerprintService.createFingerprint(
              bssid: bssid,
              ssid: ssid,
              gatewayMac: gatewayMac,
              gatewayIp: gatewayIp,
              dnsServers: dnsServers,
              encryptionType: encryption,
              signalStrength: networkInfo['signalStrength'] ?? -100,
              subnet: subnet,
            );
            await _fingerprintService.saveFingerprint(newFingerprint);
            print('✅ New mesh AP fingerprint saved');
            return;
          }
        }
        
        // Check 2: Encryption downgrade
        if (referenceFingerprint.encryptionType != encryption) {
          final securityLevels = {'WPA3': 4, 'WPA2': 3, 'WPA': 2, 'WEP': 1, 'Open': 0};
          final oldLevel = securityLevels[referenceFingerprint.encryptionType] ?? 0;
          final newLevel = securityLevels[encryption] ?? 0;
          
          if (newLevel < oldLevel) {
            manualChanges.add('⚠️ SECURITY DOWNGRADE: ${referenceFingerprint.encryptionType} → $encryption');
            manualThreatScore += 35;
            print('⚠️ Encryption downgrade detected: +35 points');
          } else {
            manualChanges.add('Encryption changed: ${referenceFingerprint.encryptionType} → $encryption');
            manualThreatScore += 15;
            print('⚠️ Encryption changed: +15 points');
          }
        }
        
        // Check 3: Gateway IP
        if (referenceFingerprint.gatewayIp != gatewayIp) {
          manualChanges.add('Gateway IP changed: ${referenceFingerprint.gatewayIp} → $gatewayIp');
          manualThreatScore += 30;
          print('⚠️ Gateway IP changed: +30 points');
        }
        
        print('🎯 Manual Threat Score: $manualThreatScore/100');
        
        // ✅ STEP 4: Determine severity
        String severity = 'low';
        if (manualThreatScore >= 50) {
          severity = 'critical';
        } else if (manualThreatScore >= 30) {
          severity = 'high';
        } else if (manualThreatScore >= 15) {
          severity = 'medium';
        }
        
        print('🎯 Final Severity: $severity');
        
        // ✅ STEP 5: Trigger alert if critical
        if (severity == 'critical') {
          final alertKey = '$ssid-$bssid';
          
          if (!_alertedEvilTwins.contains(alertKey)) {
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('🚨 EVIL TWIN ATTACK DETECTED!');
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('   SSID: $ssid');
            print('   Old BSSID: ${referenceFingerprint.networkId}');
            print('   New BSSID: $bssid');
            print('   Threat Score: $manualThreatScore');
            print('   Changes: ${manualChanges.join(', ')}');
            print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            
            // Show notification
            await _showEvilTwinNotification(ssid, manualChanges);
            
            // Trigger callback
            onEvilTwinDetected?.call(ssid, manualChanges, severity);
            
            // Mark as alerted
            _alertedEvilTwins.add(alertKey);
          }
        }
        
        // ✅ STEP 6: Save new fingerprint for this BSSID
        final newFingerprint = await _fingerprintService.createFingerprint(
          bssid: bssid,
          ssid: ssid,
          gatewayMac: gatewayMac,
          gatewayIp: gatewayIp,
          dnsServers: dnsServers,
          encryptionType: encryption,
          signalStrength: networkInfo['signalStrength'] ?? -100,
          subnet: subnet,
        );
        
        await _fingerprintService.saveFingerprint(newFingerprint);
        print('✅ New fingerprint saved for BSSID: $bssid');
        
      } else {
        // Same BSSID as before - just update
        print('✅ Same BSSID as before, updating...');
        await _fingerprintService.updateTrustScore(bssid, 2);
      }
      
      _lastBssid = bssid;
      
    } catch (e, stackTrace) {
      print('⚠️ Evil Twin check failed: $e');
      print('Stack trace: $stackTrace');
    }
  }
  
  /// ✅ Show Evil Twin notification with tap action
  Future<void> _showEvilTwinNotification(String ssid, List<String> changes) async {
    if (!_notificationsInitialized) return;
    
    try {
      // Create detailed changes text
      final changesText = changes.map((change) => '• $change').join('\n');
      
      // ✅ IMPORTANT: Format payload correctly
      final payload = 'evil_twin:$ssid:${changes.join('|||')}'; // Use ||| as separator
      
      print('🔔 Creating notification with payload: $payload');
      
      final androidDetails = AndroidNotificationDetails(
        'evil_twin_channel',
        'Evil Twin Detection',
        channelDescription: 'Alerts for Evil Twin attack detection',
        importance: Importance.max,
        priority: Priority.high,
        color: Color.fromARGB(255, 255, 0, 0),
        playSound: true,
        enableVibration: true,
        ticker: '🚨 EVIL TWIN DETECTED!',
        styleInformation: BigTextStyleInformation(
          'Network: $ssid\n\n'
          'Changes Detected:\n$changesText\n\n'
          '⚠️ This may be an Evil Twin attack!\n'
          'An attacker may have created a fake network with the same name to intercept your data.\n\n'
          'Recommended Action: Disconnect immediately',
          htmlFormatBigText: false,
          contentTitle: '🚨 EVIL TWIN ATTACK DETECTED!',
          summaryText: 'Network changed significantly',
        ),
        category: AndroidNotificationCategory.error,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      // Short body for collapsed view
      final shortBody = 'Network "$ssid" has changed significantly! Tap to see details.';
      
      await _notifications.show(
        9999, // Unique ID for Evil Twin notifications
        '🚨 EVIL TWIN ATTACK DETECTED!',
        shortBody,
        notificationDetails,
        payload: payload,
      );
      
      print('✅ Evil Twin notification shown with payload');
      
    } catch (e) {
      print('⚠️ Failed to show notification: $e');
    }
  }
  
  /// Check if we should trigger auto-scan
  Future<void> _checkForAutoScan() async {
    try {
      final currentNetwork = await _wifiService.getCurrentNetwork();
      
      // No network connected
      if (currentNetwork == null || currentNetwork.isEmpty) {
        // Network disconnected
        if (_lastConnectedNetwork != null) {
          print('📡 WiFi disconnected');
          _lastConnectedNetwork = null;
          _lastBssid = null;
          _lastVpnState = null; // ✅ NEW: Reset VPN state
          _lastAlertedSsid = null; // ✅ NEW: Reset alert state
          
          // Clear Evil Twin alerts for disconnected network
          _alertedEvilTwins.clear();
        }
        return;
      }
      
      // Same network as before
      if (currentNetwork == _lastConnectedNetwork) {
        return;
      }
      
      // ✅ NEW NETWORK DETECTED!
      print('🎯 New WiFi connection detected: $currentNetwork');
      
      // ✅ NEW: Reset VPN state and alert state for new network
      _lastVpnState = null;
      _lastAlertedSsid = null;
      
      // Get preferences
      final prefs = await PreferencesService.getInstance();
      
      // Check if auto-scan is enabled
      if (prefs.autoScanOnConnect) {
        print('✅ Auto-scan enabled! Triggering scan...');
        await triggerAutoScan();
      }
      
      _lastConnectedNetwork = currentNetwork;
      
    } catch (e) {
      print('❌ Auto-scan check error: $e');
    }
  }
  
  /// Trigger auto-scan
  Future<void> triggerAutoScan() async {
    print('🔄 Starting automatic WiFi scan...');
    
    try {
      if (onAutoScanTrigger != null) {
        onAutoScanTrigger!();
        print('✅ Auto-scan callback executed!');
      }
    } catch (e) {
      print('❌ Auto-scan failed: $e');
    }
  }
  
  /// Force check for dangerous network banner (call this on app resume)
  Future<void> checkBannerOnResume() async {
    print('📱 App resumed - forcing banner check...');
    
    try {
      // Check current WiFi status using the existing service
      final currentNetwork = await _wifiService.getCurrentNetwork();
      
      if (currentNetwork == null || currentNetwork.isEmpty) {
        print('📱 No WiFi connection - no banner needed');
        return;
      }
      
      // Check VPN status using the existing service
      final isVpnActive = await _vpnService.isVpnActive();
      
      // If VPN is active, banner should be hidden
      if (isVpnActive) {
        print('📱 VPN is active - no banner needed');
        if (onDangerousNetworkClear != null) {
          onDangerousNetworkClear!();
        }
        return;
      }
      
      // Get network info using the existing service
      final networkInfo = await _wifiService.getCurrentNetworkInfo();
      if (networkInfo == null) {
        print('📱 Could not get network info');
        return;
      }
      
      final encryption = networkInfo['encryption'] ?? 'Unknown';
      
      // Check if network is unsafe
      if (_isUnsafeEncryption(encryption)) {
        print('📱 Unsafe network detected - showing banner');
        print('   Network: $currentNetwork ($encryption)');
        
        // Trigger banner callback
        if (onUnsafeConnectionDetected != null) {
          onUnsafeConnectionDetected!(currentNetwork, encryption);
          print('✅ Banner callback executed on resume');
        } else {
          print('❌ Banner callback is null on resume');
        }
      } else {
        print('📱 Network is safe - no banner needed');
      }
      
    } catch (e) {
      print('❌ Error checking banner on resume: $e');
    }
  }
  
  /// Stop monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _autoScanTimer?.cancel();
    _isMonitoring = false;
    
    print('⏸️ WiFi Connection Monitor stopped');
  }

  /// Show VPN protection active notification
  Future<void> _showVpnProtectedNotification(String ssid, String encryption) async {
    if (!_notificationsInitialized) return;
    
    try {
      print('🔔 Sending VPN protection notification...');
      
      final androidDetails = AndroidNotificationDetails(
        'vpn_protected_channel',
        'VPN Protection Status',
        channelDescription: 'Notifications when VPN protects you on unsafe networks',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        color: Color.fromARGB(255, 76, 175, 80), // Green
        playSound: true,
        enableVibration: false,
        ticker: '✅ VPN Protection Active',
        styleInformation: BigTextStyleInformation(
          'You are now protected on "$ssid" ($encryption).\n\n'
          '🛡️ VPN is encrypting your data\n'
          '✅ Safe to browse\n\n'
          'Your internet traffic is now secure.',
          htmlFormatBigText: false,
          contentTitle: '✅ VPN Protection Active',
          summaryText: 'Your traffic is encrypted',
        ),
        category: AndroidNotificationCategory.status,
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        7777, // Unique ID for VPN protection
        '✅ VPN Protection Active',
        'Connected to $ssid - Your traffic is encrypted',
        notificationDetails,
        payload: 'vpn_protected:$ssid',
      );
      
      print('✅ VPN protection notification sent');
    } catch (e) {
      print('❌ Failed to send VPN protection notification: $e');
    }
  }
  
  /// Clear alerted Evil Twin cache (for testing)
  void clearAlerts() {
    _alertedEvilTwins.clear();
    _lastAlertedSsid = null;
    _lastVpnState = null;
    print('🧹 Cleared all alerts cache');
  }
  
  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;
  
  /// Get current connected network
  String? get currentNetwork => _lastConnectedNetwork;
  
  /// Get current BSSID
  String? get currentBssid => _lastBssid;
  
  /// ✅ NEW: Get current VPN state
  bool? get isVpnActive => _lastVpnState;
}