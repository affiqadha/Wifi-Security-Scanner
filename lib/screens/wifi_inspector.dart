import '/models/wifi_access_point.dart';
import 'package:flutter/material.dart';

class WifiInspectorPage extends StatelessWidget {
  final WifiAccessPoint wifi;

  WifiInspectorPage({required this.wifi});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Wi-Fi Inspector')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SSID: ${wifi.ssid ?? 'Unknown SSID'}", style: TextStyle(fontSize: 20)),
            SizedBox(height: 10),
            Text("BSSID: ${wifi.bssid}", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Signal Strength: ${wifi.level} dBm", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Frequency: ${wifi.frequency} MHz", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Security: ${wifi.security ?? 'N/A'}", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

