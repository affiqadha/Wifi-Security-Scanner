import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class NetworkFingerprint {
  final String networkId; // BSSID
  final String ssid;
  final String gatewayMac;
  final String gatewayIp;
  final List<String> dnsServers;
  final String encryptionType;
  final int signalStrength;
  final String subnet;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int trustScore; // 0-100
  final int isTrusted;
  final String fingerprintHash;
  final String? vendorPrefix; // ✅ NEW: MAC vendor identification

  NetworkFingerprint({
    required this.networkId,
    required this.ssid,
    required this.gatewayMac,
    required this.gatewayIp,
    required this.dnsServers,
    required this.encryptionType,
    required this.signalStrength,
    required this.subnet,
    required this.firstSeen,
    required this.lastSeen,
    required this.trustScore,
    required this.isTrusted,
    required this.fingerprintHash,
    this.vendorPrefix, // ✅ NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'network_id': networkId,
      'ssid': ssid,
      'gateway_mac': gatewayMac,
      'gateway_ip': gatewayIp,
      'dns_servers': dnsServers.join(','),
      'encryption_type': encryptionType,
      'signal_strength': signalStrength,
      'subnet': subnet,
      'first_seen': firstSeen.toIso8601String(),
      'last_seen': lastSeen.toIso8601String(),
      'trust_score': trustScore,
      'is_trusted': isTrusted,
      'fingerprint_hash': fingerprintHash,
      'vendor_prefix': vendorPrefix, // ✅ NEW
    };
  }

  factory NetworkFingerprint.fromMap(Map<String, dynamic> map) {
    return NetworkFingerprint(
      networkId: map['network_id'],
      ssid: map['ssid'],
      gatewayMac: map['gateway_mac'],
      gatewayIp: map['gateway_ip'],
      dnsServers: (map['dns_servers'] as String).split(','),
      encryptionType: map['encryption_type'],
      signalStrength: map['signal_strength'],
      subnet: map['subnet'],
      firstSeen: DateTime.parse(map['first_seen']),
      lastSeen: DateTime.parse(map['last_seen']),
      trustScore: map['trust_score'],
      isTrusted: map['is_trusted'],
      fingerprintHash: map['fingerprint_hash'],
      vendorPrefix: map['vendor_prefix'], // ✅ NEW
    );
  }

  // Generate unique fingerprint hash
  static String generateHash({
    required String bssid,
    required String gatewayMac,
    required String gatewayIp,
    required List<String> dnsServers,
  }) {
    final data = '$bssid|$gatewayMac|$gatewayIp|${dnsServers.join(',')}';
    return sha256.convert(utf8.encode(data)).toString();
  }
}

class NetworkFingerprintingService {
  static final NetworkFingerprintingService _instance = NetworkFingerprintingService._internal();
  factory NetworkFingerprintingService() => _instance;
  NetworkFingerprintingService._internal();

  Database? _database;

  // ✅ NEW: Known mesh network manufacturers
  static final Set<String> meshNetworkVendors = {
    'd4:6e:0e', // TP-Link (common mesh)
    '50:c7:bf', // TP-Link
    'f4:f2:6d', // TP-Link
    '2c:30:33', // Google WiFi/Nest
    '00:1a:11', // Google
    'f0:9f:c2', // Ubiquiti (UniFi mesh)
    '74:83:c2', // Ubiquiti
    '44:d9:e7', // Amazon eero
    'f8:bb:bf', // Amazon eero
    'ac:3e:b1', // Netgear Orbi
    '20:e5:2a', // Netgear Orbi
    'c4:41:1e', // Linksys Velop
    '14:91:82', // Linksys
    '00:24:6c', // Asus AiMesh
    '04:d4:c4', // Asus
  };

  Future<void> initialize(Database database) async {
    _database = database;
    await _createTables();
  }

  Future<void> _createTables() async {
    await _database?.execute('''
      CREATE TABLE IF NOT EXISTS network_fingerprints (
        network_id TEXT PRIMARY KEY,
        ssid TEXT NOT NULL,
        gateway_mac TEXT NOT NULL,
        gateway_ip TEXT NOT NULL,
        dns_servers TEXT NOT NULL,
        encryption_type TEXT NOT NULL,
        signal_strength INTEGER NOT NULL,
        subnet TEXT NOT NULL,
        first_seen TEXT NOT NULL,
        last_seen TEXT NOT NULL,
        trust_score INTEGER NOT NULL DEFAULT 50,
        is_trusted INTEGER NOT NULL DEFAULT 0,
        fingerprint_hash TEXT NOT NULL,
        vendor_prefix TEXT
      )
    ''');

    await _database?.execute('''
      CREATE TABLE IF NOT EXISTS network_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        network_id TEXT NOT NULL,
        change_type TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        severity TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        FOREIGN KEY (network_id) REFERENCES network_fingerprints (network_id)
      )
    ''');

    // ✅ NEW: Table for tracking mesh network groups
    await _database?.execute('''
      CREATE TABLE IF NOT EXISTS mesh_network_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ssid TEXT NOT NULL,
        vendor_prefix TEXT NOT NULL,
        bssid_list TEXT NOT NULL,
        is_legitimate_mesh INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // ✅ NEW: Extract vendor prefix from MAC address
  String getVendorPrefix(String macAddress) {
    // MAC format: XX:XX:XX:YY:YY:YY
    // Vendor prefix is first 3 octets (XX:XX:XX)
    final parts = macAddress.split(':');
    if (parts.length >= 3) {
      return '${parts[0]}:${parts[1]}:${parts[2]}'.toLowerCase();
    }
    return '';
  }

  // ✅ NEW: Check if MAC belongs to known mesh vendor
  bool isKnownMeshVendor(String macAddress) {
    final prefix = getVendorPrefix(macAddress);
    return meshNetworkVendors.contains(prefix);
  }

  // ✅ NEW: Check if two MACs are from same vendor
  bool isSameVendor(String mac1, String mac2) {
    final prefix1 = getVendorPrefix(mac1);
    final prefix2 = getVendorPrefix(mac2);
    return prefix1 == prefix2 && prefix1.isNotEmpty;
  }

  // ✅ NEW: Detect if this is a legitimate mesh network
  Future<bool> isLegitimeMeshNetwork({
    required String ssid,
    required String oldMac,
    required String newMac,
  }) async {
    // Check 1: Are both MACs from the same vendor?
    if (!isSameVendor(oldMac, newMac)) {
      print('❌ Different vendors: $oldMac vs $newMac');
      return false; // Different vendors = likely Evil Twin
    }

    // Check 2: Is this a known mesh vendor?
    final isKnownMesh = isKnownMeshVendor(oldMac) && isKnownMeshVendor(newMac);
    
    // Check 3: Have we seen multiple BSSIDs for this SSID before?
    final meshGroup = await _getMeshGroup(ssid);
    
    if (meshGroup != null) {
      // We've seen this mesh network before
      final bssids = (meshGroup['bssid_list'] as String).split(',');
      
      // Add new BSSID to the group
      if (!bssids.contains(newMac)) {
        bssids.add(newMac);
        await _updateMeshGroup(ssid, bssids);
      }
      
      print('✅ Legitimate mesh network: $ssid (${bssids.length} APs)');
      return true;
    }

    // Check 4: If same vendor and known mesh manufacturer, consider it mesh
    if (isKnownMesh) {
      // Create new mesh group
      await _createMeshGroup(ssid, oldMac, newMac);
      print('✅ New mesh network detected: $ssid');
      return true;
    }

    print('⚠️ Unknown network pattern for: $ssid');
    return false;
  }

  // ✅ NEW: Get mesh network group
  Future<Map<String, dynamic>?> _getMeshGroup(String ssid) async {
    final result = await _database?.query(
      'mesh_network_groups',
      where: 'ssid = ?',
      whereArgs: [ssid],
      limit: 1,
    );
    
    if (result != null && result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  // ✅ NEW: Create mesh network group
  Future<void> _createMeshGroup(String ssid, String mac1, String mac2) async {
    final vendorPrefix = getVendorPrefix(mac1);
    final bssidList = '$mac1,$mac2';
    
    await _database?.insert('mesh_network_groups', {
      'ssid': ssid,
      'vendor_prefix': vendorPrefix,
      'bssid_list': bssidList,
      'is_legitimate_mesh': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ✅ NEW: Update mesh network group
  Future<void> _updateMeshGroup(String ssid, List<String> bssids) async {
    await _database?.update(
      'mesh_network_groups',
      {
        'bssid_list': bssids.join(','),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'ssid = ?',
      whereArgs: [ssid],
    );
  }

  // ✅ ENHANCED: Check for changes with mesh network awareness
  Future<Map<String, dynamic>> checkForChanges({
    required String bssid,
    required String ssid,
    required String gatewayMac,
    required String gatewayIp,
    required List<String> dnsServers,
    required String encryptionType,
    required String subnet,
  }) async {
    final stored = await getFingerprint(bssid);

    if (stored == null) {
      return {
        'isNew': true,
        'hasChanges': false,
        'changes': <String>[],
        'severity': 'info',
      };
    }

    final changes = <String>[];
    String severity = 'low';
    int threatScore = 0;  

    // ✅ CHECK 1: Gateway MAC (with mesh detection)
    if (stored.gatewayMac != gatewayMac) {
      final isMesh = await isLegitimeMeshNetwork(
        ssid: ssid,
        oldMac: stored.gatewayMac,
        newMac: gatewayMac,
      );

      if (isMesh) {
        changes.add('Connected to different mesh AP: ${stored.gatewayMac} → $gatewayMac');
        severity = 'info';
        await _logChange(bssid, 'mesh_roaming', stored.gatewayMac, gatewayMac, 'info');
      } else {
        changes.add('Gateway MAC changed: ${stored.gatewayMac} → $gatewayMac');
        changes.add('Manufacturer changed: ${getVendorPrefix(stored.gatewayMac)} → ${getVendorPrefix(gatewayMac)}');
        threatScore += 40;  // High threat
        await _logChange(bssid, 'gateway_mac', stored.gatewayMac, gatewayMac, 'critical');
      }
    }

    // ✅ CHECK 2: Gateway IP
    if (stored.gatewayIp != gatewayIp) {
      changes.add('Gateway IP changed: ${stored.gatewayIp} → $gatewayIp');
      threatScore += 30;
      await _logChange(bssid, 'gateway_ip', stored.gatewayIp, gatewayIp, 'high');
    }

    // ✅ CHECK 3: DNS servers
    if (!_listsEqual(stored.dnsServers, dnsServers)) {
      changes.add('DNS servers changed: ${stored.dnsServers.join(', ')} → ${dnsServers.join(', ')}');
      threatScore += 25;
      await _logChange(bssid, 'dns_servers', stored.dnsServers.join(','), dnsServers.join(','), 'high');
    }

    // ✅ CHECK 4: Encryption (with downgrade detection)
    if (stored.encryptionType != encryptionType) {
      final isDowngrade = _isEncryptionDowngrade(stored.encryptionType, encryptionType);
      
      if (isDowngrade) {
        changes.add('⚠️ SECURITY DOWNGRADE: ${stored.encryptionType} → $encryptionType');
        threatScore += 35;  // Critical for downgrade
        await _logChange(bssid, 'encryption_downgrade', stored.encryptionType, encryptionType, 'critical');
      } else {
        changes.add('Encryption changed: ${stored.encryptionType} → $encryptionType');
        threatScore += 15;
        await _logChange(bssid, 'encryption_type', stored.encryptionType, encryptionType, 'high');
      }
    }

    // ✅ CHECK 5: Subnet
    if (stored.subnet != subnet) {
      changes.add('Subnet changed: ${stored.subnet} → $subnet');
      threatScore += 20;
      await _logChange(bssid, 'subnet', stored.subnet, subnet, 'medium');
    }

    // ✅ CALCULATE FINAL SEVERITY based on threat score
    if (threatScore >= 50) {
      severity = 'critical';  // Evil Twin detected!
    } else if (threatScore >= 30) {
      severity = 'high';
    } else if (threatScore >= 15) {
      severity = 'medium';
    } else if (threatScore > 0) {
      severity = 'low';
    }

    print('🎯 Threat Score: $threatScore/100 → Severity: $severity');

    return {
      'isNew': false,
      'hasChanges': changes.isNotEmpty,
      'changes': changes,
      'severity': severity,
      'threatScore': threatScore,  // ✅ NEW: Include score in result
    };
  }

  bool _isEncryptionDowngrade(String oldEncryption, String newEncryption) {
    // Security ranking (higher = more secure)
    final securityLevels = {
      'WPA3': 4,
      'WPA2': 3,
      'WPA': 2,
      'WEP': 1,
      'Open': 0,
      'None': 0,
    };
    
    final oldLevel = securityLevels[oldEncryption] ?? 0;
    final newLevel = securityLevels[newEncryption] ?? 0;
    
    // Downgrade = moved to lower security
    return newLevel < oldLevel;
  }

  Future<void> updateTrustScore(String bssid, int delta) async {
    final current = await getFingerprint(bssid);
    if (current == null) return;

    final newScore = (current.trustScore + delta).clamp(0, 100);
    
    await _database?.update(
      'network_fingerprints',
      {
        'trust_score': newScore,
        'last_seen': DateTime.now().toIso8601String(),
      },
      where: 'network_id = ?',
      whereArgs: [bssid],
    );
  }

  Future<NetworkFingerprint?> getFingerprint(String bssid) async {
    final result = await _database?.query(
      'network_fingerprints',
      where: 'network_id = ?',
      whereArgs: [bssid],
      limit: 1,
    );
    
    if (result != null && result.isNotEmpty) {
      return NetworkFingerprint.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveFingerprint(NetworkFingerprint fingerprint) async {
    await _database?.insert(
      'network_fingerprints',
      fingerprint.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<NetworkFingerprint> createFingerprint({
    required String bssid,
    required String ssid,
    required String gatewayMac,
    required String gatewayIp,
    required List<String> dnsServers,
    required String encryptionType,
    required int signalStrength,
    required String subnet,
  }) async {
    final now = DateTime.now();
    final hash = NetworkFingerprint.generateHash(
      bssid: bssid,
      gatewayMac: gatewayMac,
      gatewayIp: gatewayIp,
      dnsServers: dnsServers,
    );

    return NetworkFingerprint(
      networkId: bssid,
      ssid: ssid,
      gatewayMac: gatewayMac,
      gatewayIp: gatewayIp,
      dnsServers: dnsServers,
      encryptionType: encryptionType,
      signalStrength: signalStrength,
      subnet: subnet,
      firstSeen: now,
      lastSeen: now,
      trustScore: 50,
      isTrusted: 0,
      fingerprintHash: hash,
      vendorPrefix: getVendorPrefix(gatewayMac), // ✅ NEW
    );
  }

  Future<void> _logChange(
    String bssid,
    String changeType,
    String oldValue,
    String newValue,
    String severity,
  ) async {
    await _database?.insert('network_changes', {
      'network_id': bssid,
      'change_type': changeType,
      'old_value': oldValue,
      'new_value': newValue,
      'severity': severity,
      'detected_at': DateTime.now().toIso8601String(),
    });
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> markAsTrusted(String bssid, bool trusted) async {
    await _database?.update(
      'network_fingerprints',
      {'is_trusted': trusted ? 1 : 0},
      where: 'network_id = ?',
      whereArgs: [bssid],
    );
  }

  Future<List<NetworkFingerprint>> getAllFingerprints() async {
    final result = await _database?.query('network_fingerprints');
    if (result == null || result.isEmpty) return [];
    
    return result.map((map) => NetworkFingerprint.fromMap(map)).toList();
  }

  Future<void> deleteFingerprint(String bssid) async {
    await _database?.delete(
      'network_fingerprints',
      where: 'network_id = ?',
      whereArgs: [bssid],
    );
  }

  // ✅ Get trusted networks
  Future<List<NetworkFingerprint>> getTrustedNetworks() async {
    final result = await _database?.query(
      'network_fingerprints',
      where: 'is_trusted = ?',
      whereArgs: [1],
      orderBy: 'trust_score DESC',
    );
    
    if (result == null || result.isEmpty) return [];
    return result.map((map) => NetworkFingerprint.fromMap(map)).toList();
  }

  // ✅ Get suspicious networks
  Future<List<NetworkFingerprint>> getSuspiciousNetworks() async {
    final result = await _database?.query(
      'network_fingerprints',
      where: 'trust_score < ? AND is_trusted = ?',
      whereArgs: [50, 0],
      orderBy: 'trust_score ASC',
    );
    
    if (result == null || result.isEmpty) return [];
    return result.map((map) => NetworkFingerprint.fromMap(map)).toList();
  }

  // ✅ Get change history for a network
  Future<List<Map<String, dynamic>>> getChangeHistory(String bssid) async {
    final result = await _database?.query(
      'network_changes',
      where: 'network_id = ?',
      whereArgs: [bssid],
      orderBy: 'detected_at DESC',
      limit: 50,
    );
    
    return result ?? [];
  }

  // ✅ Set network as trusted/untrusted
  Future<void> setTrustedNetwork(String bssid, bool trusted) async {
    await _database?.update(
      'network_fingerprints',
      {
        'is_trusted': trusted ? 1 : 0,
        'trust_score': trusted ? 100 : 50, // Reset score appropriately
      },
      where: 'network_id = ?',
      whereArgs: [bssid],
    );
  }
}