// Enhanced MITM Detection Screen with VPN Protection Banner
// Improved technical details accuracy

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/real_mitm_detection_service.dart';

class MitmDetectionScreen extends StatefulWidget {
  const MitmDetectionScreen({Key? key}) : super(key: key);

  @override
  State<MitmDetectionScreen> createState() => _MitmDetectionScreenState();
}

class _MitmDetectionScreenState extends State<MitmDetectionScreen> with SingleTickerProviderStateMixin {
  final RealMitmDetectionService _detectionService = RealMitmDetectionService();
  static const platform = MethodChannel('vpn_detection'); // Add VPN detection channel
  
  StreamSubscription<MitmDetectionResult>? _subscription;
  MitmDetectionResult? _lastResult;
  bool _isScanning = false;
  bool _isVpnActive = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _vpnCheckTimer;
  
  @override
  void initState() {
    super.initState();
    _subscribeToDetectionStream();
    _checkVpnStatus();
    _startVpnMonitoring();
    
    // Setup pulse animation for scan button
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    _vpnCheckTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _checkVpnStatus() async {
    try {
      // Use your existing VPN detection plugin
      final bool vpnActive = await platform.invokeMethod('isVpnConnected');
      if (mounted) {
        setState(() {
          _isVpnActive = vpnActive;
        });
      }
    } catch (e) {
      // If VPN check fails, assume VPN is not active
      print('VPN check error: $e');
      if (mounted) {
        setState(() {
          _isVpnActive = false;
        });
      }
    }
  }
  
  void _startVpnMonitoring() {
    _vpnCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _checkVpnStatus();
      }
    });
  }
  
  void _subscribeToDetectionStream() {
    _subscription = _detectionService.detectionStream.listen((result) {
      if (mounted) {
        setState(() {
          _lastResult = result;
          _isScanning = false;
          
          if (result.mitmDetected) {
            HapticFeedback.heavyImpact();
          }
        });
      }
    });
  }
  
  Future<void> _startDetection() async {
    // Don't scan if VPN is active
    if (_isVpnActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot scan while VPN is active'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }
    
    setState(() {
      _isScanning = true;
    });
    
    await _detectionService.detectMitm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Scan'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // VPN Active Banner
          if (_isVpnActive) _buildVpnBanner(),
          
          // Main Content
          Expanded(
            child: _isVpnActive
                ? _buildVpnProtectedView()
                : (_lastResult == null
                    ? _buildInitialScanScreen()
                    : _buildResultsScreen()),
          ),
        ],
      ),
    );
  }
  
  // ==================== VPN BANNER ====================
  Widget _buildVpnBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.vpn_lock,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🛡️ VPN Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your connection is protected. MITM detection is disabled while VPN is active.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.check_circle,
                color: Colors.greenAccent.shade400,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _showVpnInfoDialog(),
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
            label: const Text(
              'Why is MITM detection disabled?',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
  
  // ==================== VPN PROTECTED VIEW ====================
  Widget _buildVpnProtectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.vpn_lock,
              size: 100,
              color: Colors.blue.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'MITM Detection Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your VPN is active and encrypting all traffic.\n\nMITM attacks cannot intercept encrypted VPN connections. Detection is paused while VPN is running.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.shade200,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user,
                    color: Colors.green.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Your connection is secure',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ==================== VPN INFO DIALOG ====================
  void _showVpnInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_lock, color: Colors.blue),
            SizedBox(width: 12),
            Text('VPN Protection'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How VPN Prevents MITM Attacks',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoPoint(
                Icons.lock,
                'End-to-End Encryption',
                'VPN encrypts all traffic before it leaves your device',
              ),
              _buildInfoPoint(
                Icons.visibility_off,
                'Hidden Traffic',
                'Attackers can only see encrypted data, not actual content',
              ),
              _buildInfoPoint(
                Icons.verified_user,
                'Secure Tunnel',
                'Creates a protected tunnel to VPN server, bypassing local threats',
              ),
              _buildInfoPoint(
                Icons.block,
                'MITM Protection',
                'Even if traffic is intercepted, it cannot be decrypted without your VPN key',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your connection is secure while VPN is active',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoPoint(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // ENHANCED INITIAL SCAN SCREEN
  Widget _buildInitialScanScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Hero Icon with Animation
            _buildHeroIcon(),
            
            const SizedBox(height: 32),
            
            // Main Title
            Text(
              _isScanning ? 'Scanning Network...' : 'Network Security Check',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Subtitle
            Text(
              _isScanning
                  ? 'Analyzing your network for threats'
                  : 'Protect yourself from attackers on public WiFi',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Scan Button with Animation
            _buildScanButton(),
            
            const SizedBox(height: 40),
            
            // What We Check Section
            _buildWhatWeCheckSection(),
            
            const SizedBox(height: 32),
            
            // Security Tips
            _buildSecurityTips(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeroIcon() {
    if (_isScanning) {
      return Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Scanning rings
            ...List.generate(3, (index) {
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: Duration(seconds: 2 + index),
                curve: Curves.easeOut,
                builder: (context, double value, child) {
                  return Container(
                    width: 160 * value,
                    height: 160 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3 * (1 - value)),
                        width: 2,
                      ),
                    ),
                  );
                },
                onEnd: () {
                  if (_isScanning) {
                    setState(() {});
                  }
                },
              );
            }),
            // Shield icon
            Icon(
              Icons.shield_outlined,
              size: 70,
              color: Colors.blue.shade700,
            ),
            // Progress indicator
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
              ),
            ),
          ],
        ),
      );
    }
    
    // Static shield when not scanning
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade400,
              Colors.green.shade600,
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.green.shade200,
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Icon(
          Icons.shield_rounded,
          size: 80,
          color: Colors.white,
        ),
      ),
    );
  }
  
  Widget _buildScanButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isScanning ? null : _startDetection,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          disabledBackgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: _isScanning ? 0 : 4,
          shadowColor: Colors.blue.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isScanning
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Scanning...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Start Security Scan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildWhatWeCheckSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist_rounded, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'What We Check',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildCheckItem(
              Icons.router,
              'Network Connection',
              'Analyzes gateway response times for suspicious delays',
            ),
            const SizedBox(height: 16),
            _buildCheckItem(
              Icons.language,
              'DNS Lookups',
              'Verifies website addresses aren\'t being redirected',
            ),
            const SizedBox(height: 16),
            _buildCheckItem(
              Icons.security,
              'SSL Certificates',
              'Checks for fake security certificates',
            ),
            const SizedBox(height: 16),
            _buildCheckItem(
              Icons.devices,
              'Device Discovery',
              'Scans for suspicious devices on the network',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCheckItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSecurityTips() {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Security Tips',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTipItem('Use VPN on public WiFi networks'),
            _buildTipItem('Avoid banking on untrusted networks'),
            _buildTipItem('Check for HTTPS on all websites'),
            _buildTipItem('Keep WiFense running for real-time protection'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTipItem(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.amber.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
  
  // RESULTS SCREEN (Your existing beautiful results page)
  Widget _buildResultsScreen() {
    final isThreatDetected = _lastResult!.mitmDetected;
    final threatScore = _lastResult!.threatScore;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isThreatDetected
              ? [Colors.red.shade50, Colors.white]
              : [Colors.green.shade50, Colors.white],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Status Icon
            _buildStatusIcon(isThreatDetected),
            
            const SizedBox(height: 24),
            
            // Status Title
            Text(
              isThreatDetected ? '⚠️ Threat Detected' : '✅ Network Secure',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isThreatDetected ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Threat Score
            Text(
              'Threat Score: $threatScore/100',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Risk Level Badge
            _buildRiskLevelBadge(threatScore),
            
            const SizedBox(height: 32),
            
            // Main Message
            _buildMainMessageCard(isThreatDetected),
            
            const SizedBox(height: 20),
            
            // Detection Details
            if (_lastResult!.mitmDetected)
              _buildThreatsCard(),
            
            const SizedBox(height: 20),
            
            // What to Do Next
            _buildActionCard(isThreatDetected),
            
            const SizedBox(height: 20),
            
            // Technical Details
            _buildTechnicalDetailsCard(),
            
            const SizedBox(height: 20),
            
            // Scan Again Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _startDetection,
                icon: const Icon(Icons.refresh, size: 24),
                label: const Text(
                  'Scan Again',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusIcon(bool isThreatDetected) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isThreatDetected
              ? [Colors.red.shade400, Colors.red.shade700]
              : [Colors.green.shade400, Colors.green.shade700],
        ),
        boxShadow: [
          BoxShadow(
            color: isThreatDetected
                ? Colors.red.shade200
                : Colors.green.shade200,
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        isThreatDetected ? Icons.warning_rounded : Icons.verified_user_rounded,
        size: 70,
        color: Colors.white,
      ),
    );
  }
  
  Widget _buildRiskLevelBadge(int threatScore) {
    String level;
    Color color;
    
    if (threatScore >= 60) {
      level = 'CRITICAL';
      color = Colors.red.shade700;
    } else if (threatScore >= 40) {
      level = 'HIGH';
      color = Colors.orange.shade700;
    } else if (threatScore >= 20) {
      level = 'MEDIUM';
      color = Colors.amber.shade700;
    } else {
      level = 'LOW';
      color = Colors.green.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildMainMessageCard(bool isThreatDetected) {
    return Card(
      elevation: 3,
      color: isThreatDetected ? Colors.red.shade50 : Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isThreatDetected ? Colors.red.shade200 : Colors.green.shade200,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isThreatDetected ? Icons.error_outline : Icons.check_circle_outline,
              size: 48,
              color: isThreatDetected ? Colors.red.shade700 : Colors.green.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              isThreatDetected
                  ? 'A potential Man-in-the-Middle attack has been detected on your network.'
                  : 'Your network appears to be secure. No threats detected.',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThreatsCard() {
    // Build threats list from various sources
    final threats = <String>[];
    
    // Add reason as primary threat
    if (_lastResult!.reason.isNotEmpty) {
      threats.add(_lastResult!.reason);
    }
    
    // Add suspicious IPs
    if (_lastResult!.suspiciousIps != null && _lastResult!.suspiciousIps!.isNotEmpty) {
      threats.add('Suspicious IPs detected: ${_lastResult!.suspiciousIps!.join(", ")}');
    }
    
    // Add duplicated MACs
    if (_lastResult!.duplicatedMacs != null && _lastResult!.duplicatedMacs!.isNotEmpty) {
      threats.add('Duplicate MAC addresses: ${_lastResult!.duplicatedMacs!.join(", ")}');
    }
    
    // Add gateway compromised
    if (_lastResult!.gatewayCompromised == true) {
      threats.add('Gateway appears compromised');
    }
    
    // If no threats found, add detection type
    if (threats.isEmpty) {
      threats.add(_lastResult!.attackTypeName);
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Detected Issues',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...threats.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildThreatItem(
                  '${entry.key + 1}',
                  entry.value,
                  Colors.orange.shade700,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionCard(bool isThreatDetected) {
    return Card(
      elevation: 2,
      color: isThreatDetected ? Colors.red.shade50 : Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isThreatDetected ? Icons.shield_outlined : Icons.tips_and_updates_outlined,
                  color: isThreatDetected ? Colors.red.shade700 : Colors.blue.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isThreatDetected ? 'Immediate Actions' : 'Stay Protected',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isThreatDetected) ...[
              _buildThreatItem('1', 'Disconnect from this network immediately', Colors.red.shade700),
              const SizedBox(height: 12),
              _buildThreatItem('2', 'Enable VPN before reconnecting', Colors.red.shade700),
              const SizedBox(height: 12),
              _buildThreatItem('3', 'Change passwords for sensitive accounts', Colors.red.shade700),
              const SizedBox(height: 12),
              _buildThreatItem('4', 'Report this network to authorities', Colors.red.shade700),
            ] else ...[
              _buildThreatItem('1', 'Continue regular monitoring', Colors.blue.shade700),
              const SizedBox(height: 12),
              _buildThreatItem('2', 'Use VPN on public networks', Colors.blue.shade700),
              const SizedBox(height: 12),
              _buildThreatItem('3', 'Keep WiFense running for protection', Colors.blue.shade700),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildThreatItem(String number, String title, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTechnicalDetailsCard() {
    return Card(
      elevation: 2,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.info_outline, color: Colors.grey.shade700),
          title: const Text(
            'Technical Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'For advanced users',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTechSection('Network Connection', Icons.router, _getNetworkTechDetails()),
                  const Divider(height: 32),
                  _buildTechSection('Website Lookups (DNS)', Icons.language, _getDnsTechDetails()),
                  const Divider(height: 32),
                  _buildTechSection('Security Certificates', Icons.security, _getSslTechDetails()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTechSection(String title, IconData icon, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: Colors.grey.shade600)),
              Expanded(
                child: Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  // ==================== IMPROVED TECHNICAL DETAILS ====================
  
  List<String> _getNetworkTechDetails() {
    final details = <String>[];
    
    if (_lastResult?.networkAnalysis != null) {
      final analysis = _lastResult!.networkAnalysis!;
      final avgLatency = analysis['avgLatency'] as double?;
      final variance = analysis['variance'] as double?;
      final threatScore = analysis['threatScore'] as int?;
      final suspiciousLatency = analysis['suspiciousLatency'] as bool? ?? false;
      final highVariance = analysis['highVariance'] as bool? ?? false;
      
      // Show threat score if detected
      if (threatScore != null && threatScore > 0) {
        details.add('Network Threat Score: $threatScore/100');
      }
      
      // Latency analysis
      if (avgLatency != null) {
        if (suspiciousLatency && avgLatency > 100) {
          details.add('⚠️ High latency: ${avgLatency.toInt()}ms (SUSPICIOUS)');
          details.add('   └─ Possible MITM delay');
        } else if (avgLatency > 50) {
          details.add('Moderate latency: ${avgLatency.toInt()}ms');
        } else {
          details.add('✓ Gateway response: ${avgLatency.toInt()}ms (normal)');
        }
      }
      
      // Variance analysis
      if (variance != null) {
        if (highVariance && variance > 30) {
          details.add('High variance: ${variance.toInt()}ms');
          details.add('   └─ Network congestion or instability');
        } else if (suspiciousLatency && variance < 20) {
          details.add('⚠️ Low variance: ${variance.toInt()}ms');
          details.add('   └─ Consistent delay pattern (MITM signature)');
        } else {
          details.add('Latency variance: ${variance.toInt()}ms');
        }
      }
      
      // Add specific threats
      if (_lastResult?.details != null) {
        final networkData = _lastResult!.details!['networkAnomaly'] as Map?;
        if (networkData != null && networkData['threats'] != null) {
          final threats = networkData['threats'] as List;
          for (var threat in threats) {
            final threatStr = threat.toString();
            if (threatStr.isNotEmpty && !details.contains(threatStr)) {
              details.add('⚠️ $threatStr');
            }
          }
        }
      }
      
      // Gateway status
      final completelyUnreachable = analysis['completelyUnreachable'] as bool? ?? false;
      if (completelyUnreachable) {
        details.add('🚨 Gateway completely unreachable');
        details.add('   └─ CRITICAL: Possible MITM or network failure');
      }
    }
    
    if (details.isEmpty) {
      details.add('✓ Connection appears normal');
    }
    
    return details;
  }

  List<String> _getDnsTechDetails() {
    final details = <String>[];
    
    if (_lastResult?.details != null) {
      final dnsData = _lastResult!.details!['dnsHijacking'] as Map?;
      
      if (dnsData != null) {
        // DNS threat score
        final dnsThreatScore = dnsData['dnsThreatScore'] as int? ?? 0;
        if (dnsThreatScore > 0) {
          details.add('DNS Threat Score: $dnsThreatScore/100');
        }
        
        // Hijacking detection
        final hijackingDetected = dnsData['hijackingDetected'] as bool? ?? false;
        if (hijackingDetected) {
          details.add('🚨 DNS HIJACKING DETECTED');
          details.add('   └─ Website addresses are being redirected');
        }
        
        // Success rate
        if (dnsData['successRate'] != null) {
          final rate = ((dnsData['successRate'] as double) * 100).toInt();
          final successful = dnsData['successfulQueries'] ?? 0;
          final total = dnsData['totalQueries'] ?? 0;
          
          if (rate < 100) {
            details.add('⚠️ DNS success rate: $rate% ($successful/$total)');
            details.add('   └─ Some lookups failed or were hijacked');
          } else {
            details.add('✓ DNS success rate: 100% ($successful/$total)');
          }
        }
        
        // DNS servers
        if (dnsData['currentDnsServers'] != null) {
          final servers = dnsData['currentDnsServers'] as List;
          if (servers.isNotEmpty) {
            details.add('DNS server: ${servers.join(", ")}');
          }
        }
        
        // Trusted status
        if (dnsData['dnsAreTrusted'] != null) {
          final trusted = dnsData['dnsAreTrusted'] as bool;
          if (trusted) {
            details.add('✓ Using trusted DNS (Google, Cloudflare, etc.)');
          } else {
            details.add('Using router DNS');
            details.add('   └─ Not inherently unsafe, but less secure');
          }
        }
        
        // Threat level
        if (dnsData['threatLevel'] != null) {
          final threatLevel = dnsData['threatLevel'] as String;
          if (threatLevel != 'Low') {
            details.add('Threat level: $threatLevel');
          }
        }
      }
    }
    
    if (details.isEmpty) {
      details.add('✓ All DNS lookups successful');
      details.add('✓ No hijacking detected');
    }
    
    return details;
  }
  
  List<String> _getSslTechDetails() {
    final details = <String>[];
    
    if (_lastResult?.details != null) {
      final sslData = _lastResult!.details!['sslStripping'] as Map?;
      
      if (sslData != null) {
        final detected = sslData['detected'] as bool? ?? false;
        
        // Main threat status
        if (detected) {
          details.add('🚨 SSL/TLS THREAT DETECTED');
        }
        
        // Self-signed certificates
        if (sslData['selfSignedCount'] != null) {
          final count = sslData['selfSignedCount'] as int;
          if (count > 0) {
            details.add('⚠️ Self-signed certificates: $count');
            details.add('   └─ Possible man-in-the-middle attack');
          } else {
            details.add('✓ Self-signed certificates: 0');
          }
        }
        
        // Invalid certificates
        if (sslData['invalidCertCount'] != null) {
          final count = sslData['invalidCertCount'] as int;
          if (count > 0) {
            details.add('⚠️ Invalid certificates: $count');
            details.add('   └─ Expired or tampered certificates');
          } else {
            details.add('✓ Invalid certificates: 0');
          }
        }
        
        // SSL Stripping
        if (sslData['strippingDetected'] == true) {
          details.add('🚨 SSL stripping detected');
          details.add('   └─ HTTPS downgraded to HTTP');
        } else {
          details.add('✓ No SSL stripping detected');
        }
        
        // HTTPS success rate
        if (sslData['httpsSuccessful'] != null && sslData['httpsTotal'] != null) {
          final successful = sslData['httpsSuccessful'] as int;
          final total = sslData['httpsTotal'] as int;
          final rate = total > 0 ? (successful * 100 ~/ total) : 100;
          
          if (rate < 100) {
            details.add('⚠️ HTTPS success: $rate% ($successful/$total)');
          } else {
            details.add('✓ HTTPS success: 100% ($successful/$total)');
          }
        }
        
        // Threat level
        if (sslData['threatLevel'] != null) {
          final threatLevel = sslData['threatLevel'] as String;
          if (threatLevel != 'Low') {
            details.add('Certificate threat level: $threatLevel');
          }
        }
      }
    }
    
    if (details.isEmpty) {
      details.add('✓ All certificates valid');
      details.add('✓ HTTPS connections secure');
    }
    
    return details;
  }
}