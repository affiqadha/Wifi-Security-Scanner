import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class VpnService {
  static const MethodChannel _channel = MethodChannel('vpn_detection');

  /// Check if VPN is currently active/connected
  Future<bool> isVpnConnected() async {
    try {
      final bool isConnected = await _channel.invokeMethod('isVpnConnected');
      return isConnected;
    } catch (e) {
      print('Error checking VPN status: $e');
      return false;
    }
  }

  /// ✅ NEW: Alias for isVpnConnected (for compatibility)
  Future<bool> isVpnActive() async {
    return await isVpnConnected();
  }

  /// Open Play Store to download a VPN app
  Future<void> openVpnInPlayStore(String packageName) async {
    final url = 'https://play.google.com/store/apps/details?id=$packageName';
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch Play Store';
      }
    } catch (e) {
      print('Error opening Play Store: $e');
      rethrow;
    }
  }

  /// Recommended VPN apps with their package names
  static const Map<String, Map<String, String>> recommendedVpns = {
    'ProtonVPN': {
      'package': 'ch.protonvpn.android',
      'description': 'Free & Secure',
    },
    'Windscribe VPN': {
      'package': 'com.windscribe.vpn',
      'description': '10GB Free Monthly',
    },
    'NordVPN': {
      'package': 'com.nordvpn.android',
      'description': 'Premium Security',
    },
    'ExpressVPN': {
      'package': 'com.expressvpn.vpn',
      'description': 'Fast & Reliable',
    },
    'Surfshark': {
      'package': 'com.surfshark.vpnclient.android',
      'description': 'Unlimited Devices',
    },
  };
}