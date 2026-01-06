import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class WifiNetwork {
  final String ssid;
  final String bssid;
  final int signalLevel;
  final bool isSecure;
  final int frequency;
  final String capabilities;

  WifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalLevel,
    required this.isSecure,
    required this.frequency,
    required this.capabilities,
  });

  factory WifiNetwork.fromMap(Map<String, dynamic> map) {
    return WifiNetwork(
      ssid: map['ssid'] ?? 'Unknown',
      bssid: map['bssid'] ?? '00:00:00:00:00:00',
      signalLevel: map['signalLevel'] ?? 0,
      isSecure: map['isSecure'] ?? false,
      frequency: map['frequency'] ?? 0,
      capabilities: map['capabilities'] ?? "",
    );
  }
}

class WifiPlatformService {
  static const MethodChannel _channel = MethodChannel('wifi_security/network_info');

  // ✅ NEW: Scan throttling to prevent Android blocking
  DateTime? _lastScanTime;
  List<WifiNetwork>? _cachedNetworks;
  static const Duration _minScanInterval = Duration(seconds: 30); // Android throttle limit

  /// ✅ Request WiFi permissions using permission_handler
  Future<bool> requestPermissions() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// ✅ Call native channel to get scanned WiFi networks (with throttling)
  Future<List<WifiNetwork>> getWifiNetworks({bool forceRefresh = false}) async {
    try {
      // Check if we should use cached results (even with forceRefresh if too soon)
      if (_lastScanTime != null &&
          _cachedNetworks != null &&
          DateTime.now().difference(_lastScanTime!) < _minScanInterval) {

        if (forceRefresh) {
          print('⚠️ Scan requested too soon (${DateTime.now().difference(_lastScanTime!).inSeconds}s ago)');
          print('⏭️ Using cached WiFi scan results to avoid Android throttle');
        } else {
          print('⏭️ Using cached WiFi scan results (throttle protection)');
        }
        return _cachedNetworks!;
      }

      // Perform actual scan
      print('🔍 Starting WiFi scan...');
      final List<dynamic> result = await _channel.invokeMethod('getWifiNetworks');
      _cachedNetworks = result.map((network) => WifiNetwork.fromMap(Map<String, dynamic>.from(network))).toList();
      _lastScanTime = DateTime.now();

      print('✅ WiFi scan completed (${_cachedNetworks!.length} networks)');
      return _cachedNetworks!;
    } on PlatformException catch (e) {
      print('❌ Failed to get WiFi networks: ${e.message}');
      // Return cached results if available
      if (_cachedNetworks != null && _cachedNetworks!.isNotEmpty) {
        print('⏭️ Returning cached results (${_cachedNetworks!.length} networks) due to scan failure');
        return _cachedNetworks!;
      }
      print('❌ No cached results available - scan failed completely');
      return [];
    }
  }

  /// ✅ Connect to WiFi network
  Future<bool> connectToNetwork(String ssid, String password) async {
    try {
      final bool result = await _channel.invokeMethod('connectToNetwork', {
        'ssid': ssid,
        'password': password,
      });
      return result;
    } on PlatformException catch (e) {
      print('❌ Failed to connect to network: ${e.message}');
      return false;
    }
  }

  /// ✅ Disconnect from current WiFi network
  Future<bool> disconnectFromNetwork() async {
    try {
      final bool result = await _channel.invokeMethod('disconnectFromNetwork');
      return result;
    } on PlatformException catch (e) {
      print('❌ Failed to disconnect: ${e.message}');
      return false;
    }
  }

  /// ✅ Get currently connected network SSID
  Future<String?> getCurrentNetwork() async {
    try {
      final String? ssid = await _channel.invokeMethod('getCurrentNetwork');
      return ssid;
    } on PlatformException catch (e) {
      print('❌ Failed to get current network: ${e.message}');
      return null;
    }
  }

  /// ✅ NEW: Get full network information (for Evil Twin detection)
  Future<Map<String, dynamic>> getCurrentNetworkInfo() async {
    try {
      final dynamic result = await _channel.invokeMethod('getCurrentNetworkInfo');
      
      if (result == null) {
        return {
          'ssid': null,
          'bssid': '',
          'encryption': 'Unknown',
          'signalStrength': -100,
          'frequency': 0,
          'gatewayMac': '',
          'gatewayIp': '',
          'dnsServers': <String>[],
          'subnet': '',
        };
      }
      
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      print('❌ Failed to get network info: ${e.message}');
      return {
        'ssid': null,
        'bssid': '',
        'encryption': 'Unknown',
        'signalStrength': -100,
        'frequency': 0,
        'gatewayMac': '',
        'gatewayIp': '',
        'dnsServers': <String>[],
        'subnet': '',
      };
    }
  }
}