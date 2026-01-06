import 'dart:io';
import 'dart:async';
import 'mac_vendor_service.dart';

class DeviceScannerService {
  Future<List<Map<String, String>>> scanNetwork() async {
    final devices = <Map<String, String>>[];
    final Set<String> seenIPs = {};

    try {
      // Get local IP
      final interfaces = await NetworkInterface.list();
      
      // Find WiFi interface more reliably
      NetworkInterface? wifiInterface;
      for (var interface in interfaces) {
        // Check for common WiFi interface names
        if (interface.name.toLowerCase().contains('wlan') || 
            interface.name.toLowerCase().contains('wifi') || 
            interface.name == 'en0' ||
            interface.name.startsWith('wl')) {
          wifiInterface = interface;
          break;
        }
      }
      
      // Fallback to first non-loopback interface with IPv4
      wifiInterface ??= interfaces.firstWhere(
        (e) => !e.name.contains('lo') && 
               e.addresses.any((addr) => addr.type == InternetAddressType.IPv4),
        orElse: () => interfaces.first,
      );

      final localIP = wifiInterface.addresses
          .firstWhere(
            (addr) => addr.type == InternetAddressType.IPv4,
            orElse: () => wifiInterface!.addresses.first,
          )
          .address;
      
      final subnet = localIP.substring(0, localIP.lastIndexOf('.'));
      print("🔍 Scanning subnet: $subnet.*");
      print("📱 Your device IP: $localIP");

      // ✅ STEP 1: Quick ping common IPs (router, common devices)
      print("🎯 Pinging common device IPs...");
      final commonIPs = [1, 254, 2, 100, 101, 102, 103, 10, 20, 30, 50];
      await _quickPing(subnet, commonIPs);
      
      // ✅ STEP 2: Try to read ARP table (may work on some devices)
      print("📋 Attempting to read ARP table...");
      final arpDevices = await _tryReadArpTable();
      
      if (arpDevices.isNotEmpty) {
        print("✅ ARP table accessible! Found ${arpDevices.length} entries");
        for (var entry in arpDevices.entries) {
          if (!seenIPs.contains(entry.key)) {
            seenIPs.add(entry.key);
            await _addDevice(entry.key, entry.value, devices);
          }
        }
      } else {
        print("⚠️ ARP table not accessible (requires root on Android 11+)");
        print("🔄 Falling back to active ping scan...");
        
        // ✅ STEP 3: Full subnet ping sweep (fallback for non-root)
        final activeIPs = await _fullSubnetScan(subnet, localIP);
        print("✅ Found ${activeIPs.length} active IPs via ping");
        
        for (var ip in activeIPs) {
          if (!seenIPs.contains(ip)) {
            seenIPs.add(ip);
            // Use placeholder MAC since we can't read ARP
            final placeholderMac = _generatePlaceholderMac(ip);
            await _addDevice(ip, placeholderMac, devices, isPlaceholder: true);
          }
        }
      }
      
      // ✅ STEP 4: Always add current device
      if (!seenIPs.contains(localIP)) {
        print("📱 Adding your device: $localIP");
        await _addDevice(localIP, "XX:XX:XX:XX:XX:XX", devices, 
                        vendor: "Your Device", isPlaceholder: true);
      }

      print("✅ Scan complete! Found ${devices.length} devices");
      
      // Sort by IP
      devices.sort((a, b) {
        final aOctets = a['ip']!.split('.').map(int.parse).toList();
        final bOctets = b['ip']!.split('.').map(int.parse).toList();
        return aOctets.last.compareTo(bOctets.last);
      });
      
    } catch (e) {
      print("❌ Scan error: $e");
    }

    return devices;
  }

  // Quick ping for common IPs
  Future<void> _quickPing(String subnet, List<int> hostNumbers) async {
    final futures = <Future>[];
    for (var i in hostNumbers) {
      futures.add(_pingIP('$subnet.$i'));
    }
    await Future.wait(futures);
  }

  // Try to read ARP table (works on rooted devices or older Android)
  Future<Map<String, String>> _tryReadArpTable() async {
    final arpDevices = <String, String>{};
    
    try {
      // Try multiple ARP commands
      final commands = [
        ['cat', '/proc/net/arp'],
        ['ip', 'neigh'],
        ['arp', '-a'],
      ];

      for (var cmd in commands) {
        try {
          final result = await Process.run(cmd[0], cmd.sublist(1))
              .timeout(Duration(seconds: 2));
          
          if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
            final lines = result.stdout.toString().split('\n');
            
            for (var line in lines) {
              // Try to match IP and MAC
              final match = RegExp(
                r'(\d+\.\d+\.\d+\.\d+)\s+.*?\s+(([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2})',
              ).firstMatch(line);
              
              if (match != null) {
                final ip = match.group(1)!;
                final mac = match.group(2)!.toUpperCase().replaceAll('-', ':');
                
                if (_isValidMac(mac)) {
                  arpDevices[ip] = mac;
                }
              }
            }
            
            if (arpDevices.isNotEmpty) break;
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      print("⚠️ ARP table read failed: $e");
    }
    
    return arpDevices;
  }

  // Full subnet scan using ping
  Future<Set<String>> _fullSubnetScan(String subnet, String localIP) async {
    final activeIPs = <String>{};
    final futures = <Future>[];
    
    print("🔄 Scanning 254 IPs...");
    
    // Ping all IPs in batches
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      
      futures.add(
        _pingIP(ip).then((isActive) {
          if (isActive) {
            activeIPs.add(ip);
            print("✓ $ip is active");
          }
        })
      );
      
      // Process in batches of 50
      if (futures.length >= 50) {
        await Future.wait(futures);
        futures.clear();
        await Future.delayed(Duration(milliseconds: 100));
      }
    }
    
    // Wait for remaining
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    
    return activeIPs;
  }

  // Ping a single IP
  Future<bool> _pingIP(String ip) async {
    try {
      final result = await Process.run(
        'ping',
        ['-c', '1', '-W', '1', ip],
      ).timeout(Duration(seconds: 2));
      
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  // Add device to list
  Future<void> _addDevice(
    String ip, 
    String mac, 
    List<Map<String, String>> devices,
    {String? vendor, bool isPlaceholder = false}
  ) async {
    if (vendor == null) {
      try {
        if (!isPlaceholder && _isValidMac(mac)) {
          final rawVendor = await MacVendorService.lookupVendor(mac)
              .timeout(Duration(seconds: 2), onTimeout: () => "Unknown");
          vendor = MacVendorService.getFriendlyVendorName(rawVendor);
        } else {
          vendor = "Active Device";
        }
      } catch (e) {
        vendor = "Unknown Device";
      }
    }
    
    devices.add({
      "ip": ip,
      "mac": mac,
      "vendor": vendor,
    });
  }

  // Validate MAC address
  bool _isValidMac(String mac) {
    return RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$').hasMatch(mac) &&
           mac != '00:00:00:00:00:00' &&
           !mac.startsWith('XX:');
  }

  // Generate placeholder MAC for devices where ARP is unavailable
  String _generatePlaceholderMac(String ip) {
    final lastOctet = ip.split('.').last;
    return 'XX:XX:XX:XX:XX:${lastOctet.padLeft(2, '0')}';
  }
}