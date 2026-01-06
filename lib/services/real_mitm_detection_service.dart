import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'vpn_service.dart';

/// Optimized Real MITM Detection Service
/// Features:
/// - Smart continuous monitoring with configurable intervals
/// - Pauses during manual scans
/// - Lightweight background checks
/// - Battery-efficient scheduling
/// - ✅ NEW: Push notifications for MITM attacks
class RealMitmDetectionService {
  static const platform = MethodChannel('wifi_security/mitm');
  final Logger _logger = Logger();
  
  // ✅ NEW: Notification support
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  
  // ✅ NEW: VPN service for checking VPN status and WiFi connectivity
  final VpnService _vpnService = VpnService();
  final Set<String> _alertedThreats = {}; // Track alerted threats to avoid spam
  
  // Singleton pattern
  static final RealMitmDetectionService _instance = RealMitmDetectionService._internal();
  
  factory RealMitmDetectionService() {
    return _instance;
  }
  
  RealMitmDetectionService._internal();
  
  // Detection state
  bool _isDetectionRunning = false;
  bool _isManualScan = false;
  
  // Monitoring timer
  Timer? _monitoringTimer;
  bool _isMonitoringEnabled = false;
  
  // Stream controller for continuous monitoring
  final _mitmDetectionController = StreamController<MitmDetectionResult>.broadcast();
  Stream<MitmDetectionResult> get detectionStream => _mitmDetectionController.stream;
  
  // Last detection result (for caching)
  MitmDetectionResult? _lastResult;
  DateTime? _lastDetectionTime;
  
  // ========================================
  // CONFIGURATION
  // ========================================
  
  /// Interval for background monitoring (default: 30 seconds)
  /// Adjust this based on your needs:
  /// - 30s: Balanced (recommended)
  /// - 60s: Light (better battery)
  /// - 15s: Aggressive (worse battery, more real-time)
  Duration _monitoringInterval = const Duration(seconds: 30);
  
  /// Minimum time between scans (prevents rapid re-scanning)
  Duration _minScanInterval = const Duration(seconds: 5);
  
  // ========================================
  // ✅ NEW: NOTIFICATION METHODS
  // ========================================
  
  /// Initialize notifications
  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _notifications.initialize(initSettings);
    _notificationsInitialized = true;
    print('✅ MITM Service: Notifications initialized');
  }
  
  /// Show MITM attack notification
  Future<void> _showMitmNotification(MitmDetectionResult result) async {
    if (!result.mitmDetected) return;
    
    try {
      // Initialize if needed
      await _initializeNotifications();
      
      // Create unique key for this threat
      final threatKey = '${result.detectionType}_${result.threatScore}';
      
      // Skip if already alerted
      if (_alertedThreats.contains(threatKey)) {
        print('⏭️ Already alerted for this threat, skipping notification');
        return;
      }
      
      // Determine notification details based on detection type
      String title = '🚨 MITM ATTACK DETECTED!';
      String body = '';
      int notificationId = 7777;
      
      switch (result.detectionType) {
        case DetectionType.arpSpoofing:
          notificationId = 7777;
          body = 'ARP Spoofing detected on your network!\n\nThreat Level: ${_getThreatLevel(result.threatScore)}\nDisconnect immediately!';
          break;
        case DetectionType.dnsHijacking:
          notificationId = 7778;
          body = 'DNS Hijacking detected!\n\nYour DNS requests may be intercepted.\nDisconnect immediately!';
          break;
        case DetectionType.sslStripping:
          notificationId = 7779;
          body = 'SSL Stripping detected!\n\nYour secure connections are compromised.\nDisconnect immediately!';
          break;
        case DetectionType.networkAnomaly:
          notificationId = 7780;
          body = 'Network anomaly detected!\n\n${result.reason}\nCheck your network security.';
          break;
        case DetectionType.packetAnalysis:
          notificationId = 7781;
          body = 'Suspicious traffic pattern detected!\n\n${result.reason}\nYour data may be intercepted.';
          break;
        default:
          notificationId = 7776;
          body = '${result.reason}\n\nThreat Level: ${_getThreatLevel(result.threatScore)}';
      }
      
      // Create notification
      final androidDetails = AndroidNotificationDetails(
        'mitm_detection',
        'MITM Attack Alerts',
        channelDescription: 'Critical alerts for MITM attack detection',
        importance: Importance.max,
        priority: Priority.high,
        color: const Color.fromARGB(255, 220, 20, 60),
        playSound: true,
        enableVibration: true,
        ticker: 'MITM Attack Detected!',
      );
      
      final notificationDetails = NotificationDetails(android: androidDetails);
      
      await _notifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: 'mitm:${result.detectionType}',
      );
      
      // Mark as alerted
      _alertedThreats.add(threatKey);
      
      print('✅ MITM notification shown: ${result.detectionType}');
      
    } catch (e) {
      print('⚠️ Failed to show MITM notification: $e');
    }
  }
  
  /// Get human-readable threat level
  String _getThreatLevel(int score) {
    if (score >= 80) return 'CRITICAL';
    if (score >= 60) return 'HIGH';
    if (score >= 40) return 'MEDIUM';
    return 'LOW';
  }
  
  /// Clear alerted threats (call when network changes)
  void clearAlerts() {
    _alertedThreats.clear();
    print('🧹 MITM alerts cleared');
  }
  
  // ========================================
  // MANUAL DETECTION (User-triggered)
  // ========================================
  
  /// Performs a comprehensive MITM attack detection scan
  /// This is called when user taps "Start Detection"
  Future<MitmDetectionResult> detectMitm({bool isManual = true}) async {
    // Prevent concurrent scans
    if (_isDetectionRunning) {
      _logger.w("Detection already in progress, skipping...");
      return _lastResult ?? MitmDetectionResult(
        mitmDetected: false,
        reason: "Detection already in progress",
        detectionType: DetectionType.none,
      );
    }
    
    // Check minimum scan interval (prevent spam)
    if (_lastDetectionTime != null && !isManual) {
      final timeSinceLastScan = DateTime.now().difference(_lastDetectionTime!);
      if (timeSinceLastScan < _minScanInterval) {
        _logger.d("Skipping scan, too soon (${timeSinceLastScan.inSeconds}s since last scan)");
        return _lastResult ?? MitmDetectionResult(
          mitmDetected: false,
          reason: "Recent scan, using cached result",
          detectionType: DetectionType.none,
        );
      }
    }
    
    _isDetectionRunning = true;
    _isManualScan = isManual;
    
    // ⚠️ PAUSE continuous monitoring during manual scan
    if (isManual && _isMonitoringEnabled) {
      _pauseMonitoring();
    }
    
    try {
      final startTime = DateTime.now();
      _logger.i(isManual ? "🔍 Manual MITM detection started..." : "🔄 Background MITM check...");
      
      // Call native platform code
      final Map<dynamic, dynamic> response = await platform.invokeMethod('detectMitm');
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      _logger.i("⏱️ Detection completed in ${duration.inMilliseconds}ms");
      
      // Parse response
      final bool mitmDetected = response['mitmDetected'] ?? false;
      final String detectionTypeStr = response['detectionType'] ?? 'none';
      final String reason = response['reason'] ?? 'Unknown';
      final int threatScore = response['threatScore'] ?? 0;
      
      // Parse detection type
      DetectionType detectionType = DetectionType.none;
      switch (detectionTypeStr) {
        case 'arpSpoofing':
          detectionType = DetectionType.arpSpoofing;
          break;
        case 'sslStripping':
          detectionType = DetectionType.sslStripping;
          break;
        case 'dnsHijacking':
          detectionType = DetectionType.dnsHijacking;
          break;
        case 'packetAnalysis':
          detectionType = DetectionType.packetAnalysis;
          break;
        case 'networkAnomaly':
          detectionType = DetectionType.networkAnomaly;
          break;
      }
      
      // Parse ARP details
      final arpData = response['arpSpoofing'] as Map<dynamic, dynamic>?;
      List<String>? suspiciousIps;
      List<String>? duplicatedMacs;
      bool? gatewayCompromised;
      
      if (arpData != null) {
        final duplicateMacsList = arpData['duplicateMacs'] as List?;
        if (duplicateMacsList != null && duplicateMacsList.isNotEmpty) {
          duplicatedMacs = [];
          for (var item in duplicateMacsList) {
            if (item is Map) {
              final mac = item['macAddress']?.toString() ?? '';
              final ips = (item['ipAddresses'] as List?)
                  ?.map((ip) => ip.toString())
                  .join(', ') ?? '';
              duplicatedMacs.add("$mac -> $ips");
            }
          }
        }
        
        final suspiciousIpsList = arpData['suspiciousIps'] as List?;
        if (suspiciousIpsList != null) {
          suspiciousIps = suspiciousIpsList.map((ip) => ip.toString()).toList();
        }
        
        gatewayCompromised = arpData['gatewayCompromised'] as bool?;
      }
      
      // Parse network analysis (gateway latency, etc.)
      final networkAnalysisData = response['networkAnalysis'] as Map<dynamic, dynamic>?;
      Map<String, dynamic>? networkAnalysis;
      if (networkAnalysisData != null) {
        networkAnalysis = Map<String, dynamic>.from(networkAnalysisData);
      }
      
      final result = MitmDetectionResult(
        mitmDetected: mitmDetected,
        detectionType: detectionType,
        reason: reason,
        threatScore: threatScore,
        networkAnalysis: networkAnalysis,
        suspiciousIps: suspiciousIps,
        duplicatedMacs: duplicatedMacs,
        gatewayCompromised: gatewayCompromised,
        details: Map<String, dynamic>.from(response),
      );
      
      _logger.i(mitmDetected 
        ? "⚠️ MITM Detection: THREAT DETECTED (Score: $threatScore)" 
        : "✅ MITM Detection: Secure (Score: $threatScore)");
      
      // Cache result
      _lastResult = result;
      _lastDetectionTime = DateTime.now();
      
      // Emit result to stream
      _mitmDetectionController.add(result);
      
      // ✅ NEW: Show notification if MITM detected
      if (result.mitmDetected) {
        await _showMitmNotification(result);
      }
      
      return result;
      
    } on PlatformException catch (e) {
      _logger.e("MITM detection error: ${e.message}");
      
      final result = MitmDetectionResult(
        mitmDetected: false,
        reason: "Detection failed: ${e.message}",
        detectionType: DetectionType.none,
      );
      
      _mitmDetectionController.add(result);
      return result;
      
    } catch (e) {
      _logger.e("Unexpected error: $e");
      
      final result = MitmDetectionResult(
        mitmDetected: false,
        reason: "Unexpected error during detection",
        detectionType: DetectionType.none,
      );
      
      _mitmDetectionController.add(result);
      return result;
      
    } finally {
      _isDetectionRunning = false;
      
      // ⚠️ RESUME continuous monitoring after manual scan
      if (_isManualScan && _isMonitoringEnabled) {
        _resumeMonitoring();
      }
      _isManualScan = false;
    }
  }
  
  // ========================================
  // CONTINUOUS MONITORING
  // ========================================
  
  /// Start continuous background monitoring
  /// 
  /// [interval] - How often to check (default: 30s)
  /// [onThreatDetected] - Callback when threat is found
  void startContinuousMonitoring({
    Duration? interval,
    Function(MitmDetectionResult)? onThreatDetected,
  }) {
    if (_isMonitoringEnabled) {
      _logger.w("Continuous monitoring already running");
      return;
    }
    
    _monitoringInterval = interval ?? const Duration(seconds: 30);
    _isMonitoringEnabled = true;
    
    // ✅ NEW: Initialize notifications
    _initializeNotifications();
    
    _logger.i("🔄 Starting continuous MITM monitoring (interval: ${_monitoringInterval.inSeconds}s)");
    
    // Start periodic timer
    _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
      // Skip if manual scan is running
      if (_isDetectionRunning) {
        _logger.d("Skipping background scan - manual scan in progress");
        return;
      }
      
      // ✅ NEW: Check if WiFi is connected before running detection
      try {
        // First check if WiFi is connected
        final connectivityResult = await Connectivity().checkConnectivity();
        
        // connectivity_plus returns List<ConnectivityResult>
        if (!connectivityResult.contains(ConnectivityResult.wifi)) {
          _logger.d("⏭️ Skipping MITM check - WiFi not connected");
          return;
        }
        
        // Then check if VPN is active (user is already protected)
        final isVpnActive = await _vpnService.isVpnActive();
        if (isVpnActive) {
          _logger.d("⏭️ Skipping MITM check - VPN is active");
          return;
        }
        
        _logger.d("🔄 Running scheduled MITM check...");
        final result = await detectMitm(isManual: false);
        
        // Call callback if threat detected
        if (result.mitmDetected && onThreatDetected != null) {
          onThreatDetected(result);
        }
      } catch (e) {
        _logger.w("⚠️ Error during scheduled MITM check: $e");
        // Don't propagate the error, just skip this scan
      }
    });
  }
  
  /// Stop continuous monitoring
  void stopContinuousMonitoring() {
    if (!_isMonitoringEnabled) {
      _logger.w("Continuous monitoring not running");
      return;
    }
    
    _logger.i("⏹️ Stopping continuous MITM monitoring");
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoringEnabled = false;
  }
  
  /// Pause monitoring (internal use)
  void _pauseMonitoring() {
    if (_monitoringTimer != null) {
      _logger.d("⏸️ Pausing continuous monitoring");
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
    }
  }
  
  /// Resume monitoring after manual scan (internal use)
  void _resumeMonitoring() {
    if (_isMonitoringEnabled && _monitoringTimer == null) {
      _logger.d("▶️ Resuming continuous monitoring");
      _monitoringTimer = Timer.periodic(_monitoringInterval, (timer) async {
        if (!_isDetectionRunning) {
          try {
            // Check WiFi connectivity
            final connectivityResult = await Connectivity().checkConnectivity();
            if (!connectivityResult.contains(ConnectivityResult.wifi)) {
              return; // Skip if no WiFi
            }
            
            // Check VPN status
            final isVpnActive = await _vpnService.isVpnActive();
            if (!isVpnActive) {
              await detectMitm(isManual: false);
            }
          } catch (e) {
            _logger.w("⚠️ Error during resumed MITM check: $e");
          }
        }
      });
    }
  }
  
  /// Check if continuous monitoring is active
  bool get isMonitoringActive => _isMonitoringEnabled;
  
  /// Get current monitoring interval
  Duration get currentMonitoringInterval => _monitoringInterval;
  
  /// Update monitoring interval (will restart monitoring if active)
  void setMonitoringInterval(Duration interval) {
    _monitoringInterval = interval;
    if (_isMonitoringEnabled) {
      _logger.i("📝 Updating monitoring interval to ${interval.inSeconds}s");
      stopContinuousMonitoring();
      startContinuousMonitoring();
    }
  }
  
  // ========================================
  // UTILITY METHODS
  // ========================================
  
  /// Clear cached result (force fresh scan)
  void clearCache() {
    _logger.d("🗑️ Clearing cached detection result");
    _lastResult = null;
    _lastDetectionTime = null;
  }
  
  /// Get last detection result (may be cached)
  MitmDetectionResult? get lastResult => _lastResult;
  
  /// Time since last detection
  Duration? get timeSinceLastDetection {
    if (_lastDetectionTime == null) return null;
    return DateTime.now().difference(_lastDetectionTime!);
  }
  
  /// Get ARP table entries
  Future<List<ArpEntry>> getArpTable() async {
    try {
      final List<dynamic> response = await platform.invokeMethod('getArpTable');
      
      return response.map((entry) => ArpEntry(
        ipAddress: entry['ipAddress'],
        macAddress: entry['macAddress'],
        device: entry['device'],
      )).toList();
      
    } on PlatformException catch (e) {
      _logger.e("Error getting ARP table: ${e.message}");
      return [];
    }
  }
  
  /// Check DNS security only
  Future<DnsSecurityResult> checkDnsSecurity() async {
    try {
      final Map<dynamic, dynamic> response = await platform.invokeMethod('checkDnsSecurity');
      
      return DnsSecurityResult(
        threatDetected: response['threatDetected'] ?? false,
        threatLevel: response['threatLevel'] ?? 'Unknown',
        currentDnsServers: List<String>.from(response['currentDnsServers'] ?? []),
        dnsAreTrusted: response['dnsAreTrusted'] ?? false,
      );
      
    } on PlatformException catch (e) {
      _logger.e("Error checking DNS security: ${e.message}");
      return DnsSecurityResult(
        threatDetected: false,
        threatLevel: 'Unknown',
        currentDnsServers: [],
        dnsAreTrusted: false,
      );
    }
  }
  
  /// Check SSL security only
  Future<SslSecurityResult> checkSslSecurity() async {
    try {
      final Map<dynamic, dynamic> response = await platform.invokeMethod('checkSslSecurity');
      
      return SslSecurityResult(
        threatDetected: response['threatDetected'] ?? false,
        threatLevel: response['threatLevel'] ?? 'Unknown',
        selfSignedCount: response['selfSignedCount'] ?? 0,
        invalidCertCount: response['invalidCertCount'] ?? 0,
      );
      
    } on PlatformException catch (e) {
      _logger.e("Error checking SSL security: ${e.message}");
      return SslSecurityResult(
        threatDetected: false,
        threatLevel: 'Unknown',
        selfSignedCount: 0,
        invalidCertCount: 0,
      );
    }
  }
  
  void dispose() {
    stopContinuousMonitoring();
    _mitmDetectionController.close();
  }
}

// Data classes (unchanged from original)

class MitmDetectionResult {
  final bool mitmDetected;
  final DetectionType detectionType;
  final String reason;
  final int threatScore;
  final Map<String, dynamic>? networkAnalysis;
  final List<String>? suspiciousIps;
  final List<String>? duplicatedMacs;
  final bool? gatewayCompromised;
  final Map<String, dynamic>? details;

  MitmDetectionResult({
    required this.mitmDetected,
    required this.detectionType,
    required this.reason,
    this.threatScore = 0,
    this.networkAnalysis,
    this.suspiciousIps,
    this.duplicatedMacs,
    this.gatewayCompromised,
    this.details,
  });

  String get attackTypeName {
    switch (detectionType) {
      case DetectionType.networkAnomaly:
        return "Network Routing Attack";
      case DetectionType.arpSpoofing:
        return "ARP Spoofing Attack";
      case DetectionType.sslStripping:
        return "SSL Stripping Attack";
      case DetectionType.dnsHijacking:
        return "DNS Hijacking Attack";
      case DetectionType.packetAnalysis:
        return "Traffic Interception";
      default:
        return "Unknown Attack";
    }
  }

  String get userFriendlyDescription {
    if (!mitmDetected) {
      return "✅ Network Secure - No threats detected (Score: $threatScore/100)";
    }
    
    String severity = threatScore >= 70 ? "CRITICAL" : threatScore >= 50 ? "HIGH" : "MEDIUM";

    switch (detectionType) {
      case DetectionType.networkAnomaly:
        return "⚠️ $severity - Network Anomaly Detected";
      case DetectionType.arpSpoofing:
        return "⚠️ CRITICAL - ARP Spoofing Detected";
      case DetectionType.sslStripping:
        return "⚠️ HIGH - SSL Stripping Attack Detected";
      case DetectionType.dnsHijacking:
        return "⚠️ HIGH - DNS Hijacking Detected";
      case DetectionType.packetAnalysis:
        return "⚠️ MEDIUM - Suspicious Traffic Pattern Detected";
      default:
        return "⚠️ Security Threat Detected";
    }
  }

  String get severityLevel {
    if (!mitmDetected) return "Low";
    
    if (threatScore >= 70) return "Critical";
    if (threatScore >= 50) return "High";
    if (threatScore >= 30) return "Medium";
    return "Low";
  }

  double get detectionConfidence {
    if (!mitmDetected) return 1.0;
    
    if (threatScore >= 80) return 0.95;
    if (threatScore >= 60) return 0.85;
    if (threatScore >= 40) return 0.75;
    return 0.60;
  }
}

enum DetectionType {
  none,
  arpSpoofing,
  sslStripping,
  dnsHijacking,
  packetAnalysis,
  networkAnomaly,
}

class ArpEntry {
  final String ipAddress;
  final String macAddress;
  final String device;

  ArpEntry({
    required this.ipAddress,
    required this.macAddress,
    required this.device,
  });
}

class DnsSecurityResult {
  final bool threatDetected;
  final String threatLevel;
  final List<String> currentDnsServers;
  final bool dnsAreTrusted;

  DnsSecurityResult({
    required this.threatDetected,
    required this.threatLevel,
    required this.currentDnsServers,
    required this.dnsAreTrusted,
  });
}

class SslSecurityResult {
  final bool threatDetected;
  final String threatLevel;
  final int selfSignedCount;
  final int invalidCertCount;

  SslSecurityResult({
    required this.threatDetected,
    required this.threatLevel,
    required this.selfSignedCount,
    required this.invalidCertCount,
  });
}