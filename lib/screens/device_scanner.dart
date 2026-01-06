import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '/theme/background_pattern.dart';
import '/services/location_helper.dart';
import '/services/device_scanner_services.dart';  // ✅ NEW IMPORT
import '/database/database_helper.dart';

class DeviceScannerScreen extends StatefulWidget {
  @override
  _DeviceScannerScreenState createState() => _DeviceScannerScreenState();
}

class _DeviceScannerScreenState extends State<DeviceScannerScreen> {
  List<Map<String, String>> connectedDevices = [];
  String? wifiGateway;
  String? localIP;
  bool isScanning = false;
  String debugInfo = "";
  int scannedCount = 0;
  int totalToScan = 254;

  @override
  void initState() {
    super.initState();
    getNetworkInfo();
  }

  Future<void> _saveScanToDatabase(List<Map<String, String>> devices) async {
    try {
      final db = DatabaseHelper.instance;
      final timestamp = DateTime.now().toIso8601String();
      
      // Find gateway
      String? gatewayIp;
      String? gatewayMac;
      for (var device in devices) {
        if (device['ip']!.endsWith('.1') || device['ip']!.endsWith('.254')) {
          gatewayIp = device['ip'];
          gatewayMac = device['mac'];
          break;
        }
      }
      
      // Insert main scan record
      final scanId = await db.insertDeviceScan({
        'timestamp': timestamp,
        'total_devices': devices.length,
        'gateway_ip': gatewayIp,
        'gateway_mac': gatewayMac,
      });
      
      // Insert individual devices
      for (var device in devices) {
        await db.insertDeviceDetail({
          'scan_id': scanId,
          'ip_address': device['ip']!,
          'mac_address': device['mac']!,
          'vendor': device['vendor'],
          'timestamp': timestamp,
        });
      }
      
      print('✅ Saved ${devices.length} devices to database');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Device scan saved'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      print('❌ Error saving device scan: $e');
    }
  }

  Future<void> getNetworkInfo() async {
    try {
      final info = NetworkInfo();
      String? gateway = await info.getWifiGatewayIP();
      String? ip = await info.getWifiIP();

      if (mounted) {
        setState(() {
          wifiGateway = gateway;
          localIP = ip;
          if (gateway != null && ip != null) {
            debugInfo = "Network: ${gateway.substring(0, gateway.lastIndexOf('.'))}.*\nYour IP: $ip\n";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          debugInfo = "Error getting network info: $e\n";
        });
      }
    }
  }

  Future<bool> checkPermissions() async {
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) return false;
    }

    if (Platform.isAndroid) {
      var networkStatus = await Permission.nearbyWifiDevices.status;
      if (!networkStatus.isGranted) {
        networkStatus = await Permission.nearbyWifiDevices.request();
      }
    }

    return true;
  }

  // ✅ NEW SIMPLIFIED SCAN METHOD - DOESN'T FREEZE!
  Future<void> scanNetwork() async {
    if (isScanning) return;

    if (mounted) {
      setState(() {
        connectedDevices.clear();
        isScanning = true;
        scannedCount = 0;
        debugInfo = "🔍 Starting device scan...\n";
      });
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      if (mounted) {
        setState(() {
          debugInfo += "❌ Permission denied.\n";
          isScanning = false;
        });
      }
      return;
    }

    if (!await checkLocationService(context)) {
      if (mounted) {
        setState(() {
          debugInfo += "❌ Location services are disabled.\n";
          isScanning = false;
        });
      }
      return;
    }

    try {
      // Use the NEW scanner service
      final scanner = DeviceScannerService();
      
      if (mounted) {
        setState(() {
          debugInfo += "📡 Scanning subnet for active devices...\n";
          debugInfo += "⏳ This may take 30-60 seconds (pinging 254 IPs)...\n";
          debugInfo += "💡 App may appear slow but it's working!\n\n";
        });
      }
      
      // Run scan - this happens in background with await
      final devices = await scanner.scanNetwork();
      
      if (mounted) {
        setState(() {
          connectedDevices = devices;
          debugInfo += "\n✅ Scan complete! Found ${devices.length} device(s).\n";
        });
        
        // Save to database
        if (connectedDevices.isNotEmpty) {
          setState(() {
            debugInfo += "💾 Saving to database...\n";
          });
          await _saveScanToDatabase(connectedDevices);
          setState(() {
            debugInfo += "✅ Saved to history!\n";
          });
        } else {
          setState(() {
            debugInfo += "⚠️ No devices found. Try scanning again.\n";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          debugInfo += "❌ Scan error: $e\n";
        });
      }
    } finally {
      if (mounted) {
        setState(() => isScanning = false);
      }
    }
  }

  String _getDeviceType(String vendor, bool isRouter) {
    if (isRouter) return "Router / Gateway";
    if (vendor.contains("Your Device")) return "Your Device";
    if (vendor.contains("Active Device")) return "Network Device";
    
    final lower = vendor.toLowerCase();
    
    if (lower.contains('apple')) return "Apple Device";
    if (lower.contains('samsung')) return "Samsung Device";
    if (lower.contains('huawei')) return "Huawei Device";
    if (lower.contains('xiaomi')) return "Xiaomi Device";
    if (lower.contains('google')) return "Google Device";
    if (lower.contains('intel')) return "Computer";
    if (lower.contains('asus')) return "Computer / Router";
    if (lower.contains('tp-link')) return "Network Device";
    if (lower.contains('cisco')) return "Network Device";
    if (lower.contains('unknown')) return "Unknown Device";
    
    return "$vendor Device";
  }

  IconData _getDeviceIcon(String vendor, bool isRouter) {
    if (isRouter) return Icons.router;
    if (vendor.contains("Your Device")) return Icons.smartphone;
    
    final lower = vendor.toLowerCase();
    
    if (lower.contains('apple')) return Icons.phone_iphone;
    if (lower.contains('samsung')) return Icons.smartphone;
    if (lower.contains('google')) return Icons.phone_android;
    if (lower.contains('intel') || lower.contains('asus')) return Icons.computer;
    if (lower.contains('tp-link') || lower.contains('cisco')) return Icons.router;
    
    return Icons.devices;
  }

  Color _getDeviceColor(String vendor, bool isRouter) {
    if (isRouter) return const Color(0xFF4361EE);
    if (vendor.contains("Your Device")) return const Color(0xFF10B981);
    
    final lower = vendor.toLowerCase();
    
    if (lower.contains('apple')) return const Color(0xFF000000);
    if (lower.contains('samsung')) return const Color(0xFF1428A0);
    if (lower.contains('google')) return const Color(0xFF4285F4);
    
    return const Color(0xFF7209B7);
  }

  String _formatMacAddress(String mac) {
    return mac.toUpperCase().replaceAll('-', ':');
  }

  Widget _buildInfoRow(IconData icon, String label, String value, BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
        ),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return BackgroundPattern(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Connected Devices"),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scan Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: isScanning ? null : scanNetwork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4361EE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isScanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        const Icon(Icons.search),
                      const SizedBox(width: 8),
                      Text(
                        isScanning ? "Scanning..." : "Scan Network",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              // Network Info
              if (localIP != null || wifiGateway != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (wifiGateway != null)
                        Text(
                          "Network: ${wifiGateway!.substring(0, wifiGateway!.lastIndexOf('.'))}.*",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      if (localIP != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Your IP: $localIP",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Device List or Empty State
              Expanded(
                child: connectedDevices.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isScanning ? Icons.radar : Icons.devices_other,
                                size: 80,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isScanning 
                                    ? "Scanning network..."
                                    : "No devices found",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isScanning
                                    ? "Please wait 30-60 seconds..."
                                    : "Tap 'Scan Network' to discover devices",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              
                              // Debug Info
                              if (debugInfo.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(maxHeight: 300),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDarkMode 
                                          ? Colors.white.withOpacity(0.1) 
                                          : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      debugInfo,
                                      style: TextStyle(
                                        fontFamily: 'monospace', 
                                        fontSize: 11,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: connectedDevices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final device = connectedDevices[index];
                          final isRouter = device['ip'] == wifiGateway || 
                                          device['ip']!.endsWith('.1') || 
                                          device['ip']!.endsWith('.254');
                          final vendor = device['vendor'] ?? 'Unknown';
                          final deviceType = _getDeviceType(vendor, isRouter);
                          final deviceIcon = _getDeviceIcon(vendor, isRouter);
                          final iconBgColor = _getDeviceColor(vendor, isRouter);
                          
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: iconBgColor.withOpacity(0.3),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    iconBgColor.withOpacity(isDarkMode ? 0.08 : 0.04),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Device Icon
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: iconBgColor.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: iconBgColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        deviceIcon,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Device Information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            deviceType,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).textTheme.titleLarge?.color,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          
                                          if (vendor != 'Unknown' && 
                                              !vendor.contains('Active') && 
                                              !vendor.contains('Your Device'))
                                            Text(
                                              vendor,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: iconBgColor,
                                              ),
                                            ),
                                          
                                          const SizedBox(height: 8),
                                          
                                          _buildInfoRow(
                                            Icons.location_on,
                                            "IP",
                                            device['ip'] ?? 'Unknown',
                                            context,
                                          ),
                                          const SizedBox(height: 4),
                                          _buildInfoRow(
                                            Icons.fingerprint,
                                            "MAC",
                                            _formatMacAddress(device['mac'] ?? 'Unknown'),
                                            context,
                                          ),
                                          
                                          if (isRouter) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF4361EE).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(0xFF4361EE).withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                "Network Gateway",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF4361EE),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    
                                    // Status Indicator
                                    Column(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(0.3),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Online",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}