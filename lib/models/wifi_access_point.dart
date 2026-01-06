class WifiAccessPoint {
  final String ssid;
  final String bssid;
  final int level;
  final int frequency;
  final String security;

  WifiAccessPoint({
    required this.ssid,
    required this.bssid,
    required this.level,
    required this.frequency,
    required this.security,
  });
}

class FakeWifiNetwork {
  final String ssid;
  final String bssid;
  final int signalLevel;
  final int frequency;
  final String capabilities;
  final bool isSecure;

  FakeWifiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalLevel,
    required this.frequency,
    required this.capabilities,
    required this.isSecure,
  });
}
