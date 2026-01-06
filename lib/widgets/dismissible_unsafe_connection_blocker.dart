import 'package:flutter/material.dart';

class DismissibleUnsafeConnectionBlocker extends StatefulWidget {
  final String ssid;
  final String encryption;
  final VoidCallback onDismiss;
  final Function(String packageName) onVpnTap;

  const DismissibleUnsafeConnectionBlocker({
    Key? key,
    required this.ssid,
    required this.encryption,
    required this.onDismiss,
    required this.onVpnTap,
  }) : super(key: key);

  @override
  State<DismissibleUnsafeConnectionBlocker> createState() => _DismissibleUnsafeConnectionBlockerState();
}

class _DismissibleUnsafeConnectionBlockerState extends State<DismissibleUnsafeConnectionBlocker> {
  // ✅ Button is now always visible - no delay needed

  void _showDangerConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "⚠️ Are You Sure?",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "By continuing without VPN, you accept the following risks:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRiskItem("Passwords can be stolen"),
                  _buildRiskItem("Personal data can be intercepted"),
                  _buildRiskItem("Browsing activity monitored"),
                  _buildRiskItem("Vulnerable to hackers"),
                  _buildRiskItem("Accounts may be compromised"),
                ],
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade900, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This app is NOT responsible for any security incidents.",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Go Back", style: TextStyle(color: Colors.blue)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close confirmation
              widget.onDismiss(); // Dismiss main blocker
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text("I Accept the Risks"),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.close, color: Colors.red.shade700, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Colors.red.shade900,
              ),
              // ✅ Removed maxLines and ellipsis to allow natural text wrapping
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVpnButton(String name, String description, String packageName) {
    return InkWell(
      onTap: () => widget.onVpnTap(packageName),
      child: Container(
        padding: EdgeInsets.all(12),
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
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "UNSAFE CONNECTION DETECTED!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Network Info
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "You're connected to an unsecured WiFi network without VPN protection!",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.wifi, size: 20, color: Colors.grey.shade600),
                          SizedBox(width: 8),
                          Text("Network: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(widget.ssid)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.lock_open, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Encryption: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(widget.encryption)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.dangerous, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Risk Level: ", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text("HIGH", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Risks
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "⚠️ RISKS WITHOUT VPN:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildRiskItem("Passwords can be stolen"),
                      _buildRiskItem("Traffic can be monitored"),
                      _buildRiskItem("Data can be intercepted"),
                      _buildRiskItem("Man-in-the-middle attacks possible"),
                      _buildRiskItem("Personal information exposed"),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Solutions
                Text(
                  "🛡️ RECOMMENDED: ENABLE VPN",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                
                SizedBox(height: 16),
                
                // VPN Options
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.vpn_key, color: Colors.blue, size: 24),
                          SizedBox(width: 8),
                          Text(
                            "Free VPN Apps:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
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
                
                SizedBox(height: 24),
                
                // Manual disconnect option
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Or Disconnect Manually:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text("1. Open Control Centre", style: TextStyle(fontSize: 13)),
                      Text("2. Tap WiFi icon to turn off", style: TextStyle(fontSize: 13)),
                      Text("3. Use mobile data instead", style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),

                // ✅ IMPROVED: Make "Continue Without VPN" button more visible
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade700, size: 32),
                      SizedBox(height: 12),
                      Text(
                        "Don't have a VPN?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "You can continue at your own risk, but we strongly recommend using a VPN for your safety.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 16),
                      // ✅ NEW: Prominent button with better visibility
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showDangerConfirmation,
                          icon: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                          label: Text(
                            "Continue Without VPN",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.orange.shade700, width: 2),
                            backgroundColor: Colors.orange.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dangerous, color: Colors.red, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "Not Recommended - Use at your own risk",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}