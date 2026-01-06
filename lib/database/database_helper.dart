import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wifense_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // ✅ UPDATED: Incremented from 1 to 2 for new tables
      // Version 3: Added vendor_prefix column
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // ✅ NEW: Handle database upgrades
    );
  }

  // ✅ NEW: Handle database upgrades for existing users
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adding network fingerprinting tables in version 2
      await _createNetworkFingerprintTables(db);
      print("✅ Database upgraded from version $oldVersion to $newVersion");
    }
    
    if (oldVersion < 3) {
      // Adding vendor_prefix column in version 3
      try {
        await db.execute('ALTER TABLE network_fingerprints ADD COLUMN vendor_prefix TEXT');
        print("✅ Added vendor_prefix column to network_fingerprints");
      } catch (e) {
        print("⚠️ Column migration note: $e");
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textTypeNullable = 'TEXT';
    const intTypeNullable = 'INTEGER';

    // WiFi Scan History Table
    await db.execute('''
      CREATE TABLE wifi_scans (
        id $idType,
        timestamp $textType,
        total_networks $intType,
        threats_found $intType,
        high_risk_count $intType,
        medium_risk_count $intType,
        low_risk_count $intType
      )
    ''');

    // Individual Network Details Table
    await db.execute('''
      CREATE TABLE network_details (
        id $idType,
        scan_id $intType,
        ssid $textTypeNullable,
        bssid $textType,
        encryption_type $textType,
        signal_strength $intType,
        frequency $intType,
        risk_level $textType,
        is_threat $intTypeNullable,
        threat_type $textTypeNullable,
        timestamp $textType,
        FOREIGN KEY (scan_id) REFERENCES wifi_scans(id) ON DELETE CASCADE
      )
    ''');

    // Device Scan History Table
    await db.execute('''
      CREATE TABLE device_scans (
        id $idType,
        timestamp $textType,
        total_devices $intType,
        gateway_ip $textTypeNullable,
        gateway_mac $textTypeNullable
      )
    ''');

    // Individual Device Details Table
    await db.execute('''
      CREATE TABLE device_details (
        id $idType,
        scan_id $intType,
        ip_address $textType,
        mac_address $textType,
        vendor $textTypeNullable,
        timestamp $textType,
        FOREIGN KEY (scan_id) REFERENCES device_scans(id) ON DELETE CASCADE
      )
    ''');

    // MITM Detection History Table
    await db.execute('''
      CREATE TABLE mitm_scans (
        id $idType,
        timestamp $textType,
        mitm_detected $intType,
        detection_type $textTypeNullable,
        threat_level $textTypeNullable,
        reason $textTypeNullable,
        recommendations $textTypeNullable
      )
    ''');

    print("✅ Database tables created successfully");

    // ✅ NEW: Create fingerprinting tables for new installations
    await _createNetworkFingerprintTables(db);
  }

  // ✅ NEW: Create network fingerprinting tables
  Future<void> _createNetworkFingerprintTables(Database db) async {
    // Network fingerprints table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS network_fingerprints (
        network_id TEXT PRIMARY KEY,
        ssid TEXT NOT NULL,
        gateway_mac TEXT NOT NULL,
        gateway_ip TEXT NOT NULL,
        dns_servers TEXT NOT NULL,
        encryption_type TEXT NOT NULL,
        signal_strength INTEGER,
        subnet TEXT NOT NULL,
        first_seen TEXT NOT NULL,
        last_seen TEXT NOT NULL,
        trust_score INTEGER DEFAULT 50,
        is_trusted INTEGER DEFAULT 0,
        fingerprint_hash TEXT NOT NULL,
        vendor_prefix TEXT,
        UNIQUE(fingerprint_hash)
      )
    ''');

    // Fingerprint changes table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fingerprint_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        network_id TEXT NOT NULL,
        change_type TEXT NOT NULL,
        old_value TEXT,
        new_value TEXT,
        detected_at TEXT NOT NULL,
        severity TEXT NOT NULL,
        FOREIGN KEY (network_id) REFERENCES network_fingerprints (network_id)
      )
    ''');
    
    print("✅ Network fingerprint tables created");
  }

  // ============ WiFi Scan Methods ============

  Future<int> insertWifiScan(Map<String, dynamic> scan) async {
    final db = await database;
    return await db.insert('wifi_scans', scan);
  }

  Future<int> insertNetworkDetail(Map<String, dynamic> network) async {
    final db = await database;
    return await db.insert('network_details', network);
  }

  Future<List<Map<String, dynamic>>> getAllWifiScans() async {
    final db = await database;
    return await db.query(
      'wifi_scans',
      orderBy: 'timestamp DESC',
      limit: 50, // Last 50 scans
    );
  }

  Future<List<Map<String, dynamic>>> getNetworkDetailsForScan(int scanId) async {
    final db = await database;
    return await db.query(
      'network_details',
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  // ============ Device Scan Methods ============

  Future<int> insertDeviceScan(Map<String, dynamic> scan) async {
    final db = await database;
    return await db.insert('device_scans', scan);
  }

  Future<int> insertDeviceDetail(Map<String, dynamic> device) async {
    final db = await database;
    return await db.insert('device_details', device);
  }

  Future<List<Map<String, dynamic>>> getAllDeviceScans() async {
    final db = await database;
    return await db.query(
      'device_scans',
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  Future<List<Map<String, dynamic>>> getDeviceDetailsForScan(int scanId) async {
    final db = await database;
    return await db.query(
      'device_details',
      where: 'scan_id = ?',
      whereArgs: [scanId],
    );
  }

  // ============ MITM Scan Methods ============

  Future<int> insertMitmScan(Map<String, dynamic> scan) async {
    final db = await database;
    return await db.insert('mitm_scans', scan);
  }

  Future<List<Map<String, dynamic>>> getAllMitmScans() async {
    final db = await database;
    return await db.query(
      'mitm_scans',
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  // ============ Delete Methods ============

  Future<int> deleteWifiScan(int id) async {
    final db = await database;
    return await db.delete(
      'wifi_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDeviceScan(int id) async {
    final db = await database;
    return await db.delete(
      'device_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMitmScan(int id) async {
    final db = await database;
    return await db.delete(
      'mitm_scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============ Clear All Methods ============

  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('wifi_scans');
    await db.delete('network_details');
    await db.delete('device_scans');
    await db.delete('device_details');
    await db.delete('mitm_scans');
    // ✅ NEW: Clear fingerprinting data too
    await db.delete('network_fingerprints');
    await db.delete('fingerprint_changes');
    print("✅ All scan history cleared");
  }

  // ============ Statistics Methods ============

  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final wifiScansCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM wifi_scans'),
    ) ?? 0;

    final deviceScansCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM device_scans'),
    ) ?? 0;

    final mitmScansCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM mitm_scans'),
    ) ?? 0;

    final totalThreats = Sqflite.firstIntValue(
      await db.rawQuery('SELECT SUM(threats_found) FROM wifi_scans'),
    ) ?? 0;

    final mitmDetected = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM mitm_scans WHERE mitm_detected = 1'),
    ) ?? 0;

    // ✅ NEW: Add fingerprinting statistics
    final trustedNetworksCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM network_fingerprints WHERE is_trusted = 1'),
    ) ?? 0;

    final totalNetworksTracked = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM network_fingerprints'),
    ) ?? 0;

    final suspiciousChanges = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM fingerprint_changes WHERE severity IN ("critical", "high")'),
    ) ?? 0;

    return {
      'total_wifi_scans': wifiScansCount,
      'total_device_scans': deviceScansCount,
      'total_mitm_scans': mitmScansCount,
      'total_threats_found': totalThreats,
      'mitm_attacks_detected': mitmDetected,
      // ✅ NEW: Fingerprinting stats
      'trusted_networks': trustedNetworksCount,
      'networks_tracked': totalNetworksTracked,
      'suspicious_changes': suspiciousChanges,
    };
  }

  // Close database
  Future close() async {
    final db = await database;
    db.close();
  }
}