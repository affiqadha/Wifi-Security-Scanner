import 'package:flutter/material.dart';

// Reusable Button Widget
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  CustomButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,  // Use backgroundColor instead of primary
        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        textStyle: TextStyle(fontSize: 18),
      ),
    );
  }
}

// Wi-Fi Network Tile Widget
class NetworkTile extends StatelessWidget {
  final String networkName;

  NetworkTile({required this.networkName});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        networkName,
        style: TextStyle(fontSize: 16),
      ),
      trailing: Icon(Icons.signal_wifi_4_bar),
    );
  }
}
