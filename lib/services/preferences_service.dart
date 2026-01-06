import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  PreferencesService._();

  static Future<PreferencesService> getInstance() async {
    _instance ??= PreferencesService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Scanning preferences
  bool get backgroundMonitoring => _prefs?.getBool('background_monitoring') ?? true;
  bool get autoScan => _prefs?.getBool('auto_scan') ?? false;
  int get scanFrequency => _prefs?.getInt('scan_frequency') ?? 15;
  bool get autoScanOnConnect {
    return _prefs?.getBool('auto_scan_on_connect') ?? false;
  }

  Future<void> setAutoScanOnConnect(bool value) async {
    await _prefs?.setBool('auto_scan_on_connect', value);
  }
  Future<void> setBackgroundMonitoring(bool value) async {
    await _prefs?.setBool('background_monitoring', value);
  }

  Future<void> setAutoScan(bool value) async {
    await _prefs?.setBool('auto_scan', value);
  }

  Future<void> setScanFrequency(int minutes) async {
    await _prefs?.setInt('scan_frequency', minutes);
  }

  // Notification preferences
  bool get notificationsEnabled => _prefs?.getBool('notifications') ?? true;
  bool get soundAlerts => _prefs?.getBool('sound_alerts') ?? false;
  bool get vibrationAlerts => _prefs?.getBool('vibration_alerts') ?? true;

  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs?.setBool('notifications', value);
  }

  Future<void> setSoundAlerts(bool value) async {
    await _prefs?.setBool('sound_alerts', value);
  }

  Future<void> setVibrationAlerts(bool value) async {
    await _prefs?.setBool('vibration_alerts', value);
  }

  // Security preferences
  String get threatSensitivity => _prefs?.getString('threat_sensitivity') ?? 'medium';
  bool get vpnRecommendations => _prefs?.getBool('vpn_recommendations') ?? true;

  Future<void> setThreatSensitivity(String level) async {
    await _prefs?.setString('threat_sensitivity', level);
  }

  Future<void> setVpnRecommendations(bool value) async {
    await _prefs?.setBool('vpn_recommendations', value);
  }

  // History preferences
  bool get saveHistory => _prefs?.getBool('save_history') ?? true;
  int get historyRetention => _prefs?.getInt('history_retention') ?? 30;

  Future<void> setSaveHistory(bool value) async {
    await _prefs?.setBool('save_history', value);
  }

  Future<void> setHistoryRetention(int days) async {
    await _prefs?.setInt('history_retention', days);
  }

  // Appearance preferences
  bool get darkMode => _prefs?.getBool('dark_mode') ?? false;

  Future<void> setDarkMode(bool value) async {
    await _prefs?.setBool('dark_mode', value);
  }

  // Educational preferences
  bool get showEducationalTips => _prefs?.getBool('show_educational_tips') ?? true;

  Future<void> setShowEducationalTips(bool value) async {
    await _prefs?.setBool('show_educational_tips', value);
  }

  // Onboarding
  bool get hasCompletedOnboarding => _prefs?.getBool('onboarding_completed') ?? false;

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs?.setBool('onboarding_completed', value);
  }

  // First launch tracking
  bool get isFirstLaunch => _prefs?.getBool('first_launch') ?? true;

  Future<void> setFirstLaunch(bool value) async {
    await _prefs?.setBool('first_launch', value);
  }

  // Threat sensitivity thresholds
  Map<String, double> getThreatThresholds() {
    switch (threatSensitivity) {
      case 'low':
        return {
          'arp_spoofing': 0.8,
          'dns_hijacking': 0.8,
          'ssl_strip': 0.8,
        };
      case 'high':
        return {
          'arp_spoofing': 0.3,
          'dns_hijacking': 0.3,
          'ssl_strip': 0.3,
        };
      case 'medium':
      default:
        return {
          'arp_spoofing': 0.5,
          'dns_hijacking': 0.5,
          'ssl_strip': 0.5,
        };
    }
  }

  // Reset all preferences
  Future<void> resetToDefaults() async {
    await _prefs?.clear();
  }
}
