import 'package:flutter/material.dart';

class UnsafeConnectionBanner extends StatelessWidget {
  final String ssid;
  final String encryption;
  final VoidCallback onTapGetVpn;
  final VoidCallback onTapDetails;
  final VoidCallback? onDismiss; // ✅ NEW: Callback when banner is dismissed

  const UnsafeConnectionBanner({
    Key? key,
    required this.ssid,
    required this.encryption,
    required this.onTapGetVpn,
    required this.onTapDetails,
    this.onDismiss, // ✅ NEW: Optional dismiss callback
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Wrap with Dismissible to allow swipe-to-dismiss
    return Dismissible(
      key: Key('unsafe_banner_$ssid'), // Unique key for this network
      direction: DismissDirection.up, // Swipe up to dismiss
      onDismissed: (direction) {
        onDismiss?.call(); // Trigger dismiss callback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Banner dismissed. Reconnect to show again.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade700, Colors.red.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "⚠️ UNSAFE CONNECTION",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Connected to $ssid without VPN",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ NEW: Visible close button
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    onPressed: () {
                      onDismiss?.call(); // Trigger dismiss callback
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onTapGetVpn,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Get VPN",
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTapDetails,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // ✅ NEW: Swipe hint text
              SizedBox(height: 4),
              Text(
                "Swipe up to dismiss",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}