import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '/theme/theme_manager.dart';
import '../services/firebase_auth_service.dart'; // ✅ ADD: Firebase Auth import

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Settings state
  bool _backgroundMonitoring = true;
  bool _notifications = true;
  bool _soundAlerts = false;
  bool _vibrationAlerts = true;
  int _scanFrequency = 15; // minutes
  bool _autoScan = false;
  bool _vpnRecommendations = true;
  bool _saveHistory = true;
  int _historyRetention = 30; // days
  String _threatSensitivity = 'medium';
  bool _showEducationalTips = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundMonitoring = _prefs.getBool('background_monitoring') ?? true;
      _notifications = _prefs.getBool('notifications') ?? true;
      _soundAlerts = _prefs.getBool('sound_alerts') ?? false;
      _vibrationAlerts = _prefs.getBool('vibration_alerts') ?? true;
      // Clamp scan frequency between 5 and 60 minutes to prevent assertion errors
      _scanFrequency = (_prefs.getInt('scan_frequency') ?? 15).clamp(5, 60);
      _autoScan = _prefs.getBool('auto_scan') ?? false;
      _vpnRecommendations = _prefs.getBool('vpn_recommendations') ?? true;
      _saveHistory = _prefs.getBool('save_history') ?? true;
      // Clamp history retention between 7 and 90 days to prevent assertion errors
      _historyRetention = (_prefs.getInt('history_retention') ?? 30).clamp(7, 90);
      _threatSensitivity = _prefs.getString('threat_sensitivity') ?? 'medium';
      _showEducationalTips = _prefs.getBool('show_educational_tips') ?? true;
      _darkMode = _prefs.getBool('dark_mode') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
  }

  // ✅ NEW: Logout function
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        await FirebaseAuthService().logout();
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Navigate to login and clear all routes
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('SCANNING'),
          _buildSwitchTile(
            'Background Monitoring',
            'Monitor network security in the background',
            _backgroundMonitoring,
            (value) {
              setState(() => _backgroundMonitoring = value);
              _savePreference('background_monitoring', value);
            },
            Icons.radar,
          ),
          _buildSwitchTile(
            'Auto-Scan on Connect',
            'Automatically scan when connecting to new networks',
            _autoScan,
            (value) {
              setState(() => _autoScan = value);
              _savePreference('auto_scan', value);
            },
            Icons.autorenew,
          ),
          _buildSliderTile(
            'Scan Frequency',
            'Check network every $_scanFrequency minutes',
            _scanFrequency.toDouble(),
            5,
            60,
            (value) {
              setState(() => _scanFrequency = value.round());
              _savePreference('scan_frequency', _scanFrequency);
            },
            Icons.timer,
            enabled: _backgroundMonitoring,
          ),
          
          const Divider(),
          _buildSectionHeader('NOTIFICATIONS'),
          _buildSwitchTile(
            'Enable Notifications',
            'Receive alerts about security threats',
            _notifications,
            (value) {
              setState(() => _notifications = value);
              _savePreference('notifications', value);
            },
            Icons.notifications_active,
          ),
          _buildSwitchTile(
            'Sound Alerts',
            'Play sound for critical threats',
            _soundAlerts,
            (value) {
              setState(() => _soundAlerts = value);
              _savePreference('sound_alerts', value);
            },
            Icons.volume_up,
            enabled: _notifications,
          ),
          _buildSwitchTile(
            'Vibration',
            'Vibrate on threat detection',
            _vibrationAlerts,
            (value) {
              setState(() => _vibrationAlerts = value);
              _savePreference('vibration_alerts', value);
            },
            Icons.vibration,
            enabled: _notifications,
          ),

          const Divider(),
          _buildSectionHeader('SECURITY'),
          _buildDropdownTile(
            'Threat Sensitivity',
            'Detection sensitivity level',
            _threatSensitivity,
            ['low', 'medium', 'high'],
            (value) {
              setState(() => _threatSensitivity = value ?? 'medium');
              _savePreference('threat_sensitivity', _threatSensitivity);
            },
            Icons.security,
          ),
          _buildSwitchTile(
            'VPN Recommendations',
            'Show VPN suggestions when threats detected',
            _vpnRecommendations,
            (value) {
              setState(() => _vpnRecommendations = value);
              _savePreference('vpn_recommendations', value);
            },
            Icons.vpn_key,
          ),

          const Divider(),
          _buildSectionHeader('DATA & HISTORY'),
          _buildSwitchTile(
            'Save Scan History',
            'Store scan results for future reference',
            _saveHistory,
            (value) {
              setState(() => _saveHistory = value);
              _savePreference('save_history', value);
            },
            Icons.history,
          ),
          _buildSliderTile(
            'History Retention',
            'Keep history for $_historyRetention days',
            _historyRetention.toDouble(),
            7,
            90,
            (value) {
              setState(() => _historyRetention = value.round());
              _savePreference('history_retention', _historyRetention);
            },
            Icons.calendar_today,
            enabled: _saveHistory,
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('Clear All History'),
            subtitle: const Text('Delete all saved scan results'),
            onTap: () => _showClearHistoryDialog(),
          ),

          const Divider(),
          _buildSectionHeader('APPEARANCE'),
          _buildSwitchTile(
            'Dark Mode',
            'Use dark theme',
            _darkMode,
            (value) {
              setState(() => _darkMode = value);
              _savePreference('dark_mode', value);
              Provider.of<ThemeManager>(context, listen: false).toggleTheme();
            },
            Icons.dark_mode,
          ),

          const Divider(),
          _buildSectionHeader('EDUCATIONAL'),
          _buildSwitchTile(
            'Show Tips',
            'Display educational security tips',
            _showEducationalTips,
            (value) {
              setState(() => _showEducationalTips = value);
              _savePreference('show_educational_tips', value);
            },
            Icons.tips_and_updates,
          ),

          const Divider(),
          _buildSectionHeader('ABOUT'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to terms
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Report Bug'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Open bug report
            },
          ),

          // ✅ NEW: Logout section at the bottom
          const Divider(),
          _buildSectionHeader('ACCOUNT'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Sign out of your account'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
            onTap: _handleLogout,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    IconData icon, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: enabled ? null : Colors.grey),
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : Colors.grey),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: enabled ? null : Colors.grey),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      enabled: enabled,
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged,
    IconData icon, {
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: enabled ? null : Colors.grey),
      title: Text(
        title,
        style: TextStyle(color: enabled ? null : Colors.grey),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: TextStyle(color: enabled ? null : Colors.grey),
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) / 5).round(),
            label: value.round().toString(),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    Function(String?) onChanged,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option.toUpperCase()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _showClearHistoryDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all scan results and history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: Implement database clearing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('History cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}