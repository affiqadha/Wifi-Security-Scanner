import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to WiFense',
      description: 'Your personal WiFi security guardian. Protect yourself from network threats on public WiFi networks.',
      icon: Icons.security,
      color: Colors.blue,
      image: 'assets/onboarding_welcome.png', // Optional illustration
    ),
    OnboardingPage(
      title: 'Real-Time Threat Detection',
      description: 'WiFense monitors your network in real-time for MITM attacks, ARP spoofing, DNS hijacking, and SSL stripping attempts.',
      icon: Icons.radar,
      color: Colors.red,
      image: 'assets/onboarding_detection.png',
    ),
    OnboardingPage(
      title: 'Network & Device Scanning',
      description: 'Scan connected devices, analyze network encryption, and identify potential security vulnerabilities.',
      icon: Icons.wifi_tethering,
      color: Colors.green,
      image: 'assets/onboarding_scan.png',
    ),
    OnboardingPage(
      title: 'VPN Recommendations',
      description: 'Get instant VPN recommendations when threats are detected to protect your connection immediately.',
      icon: Icons.vpn_lock,
      color: Colors.purple,
      image: 'assets/onboarding_vpn.png',
    ),
    OnboardingPage(
      title: 'Learn & Stay Safe',
      description: 'Access educational content about network security threats and best practices to protect yourself.',
      icon: Icons.school,
      color: Colors.orange,
      image: 'assets/onboarding_learn.png',
    ),
    OnboardingPage(
      title: 'Permissions Required',
      description: 'WiFense needs Location and Notification permissions to scan WiFi networks and alert you of threats.',
      icon: Icons.perm_device_information,
      color: Colors.teal,
      image: 'assets/onboarding_permissions.png',
      isPermissionPage: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _currentPage < _pages.length - 1 ? _skipOnboarding : null,
                  child: Text(
                    'SKIP',
                    style: TextStyle(
                      color: _currentPage < _pages.length - 1
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

            // Page content - ✅ FIXED: Wrapped in SingleChildScrollView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildPageIndicator(index == _currentPage),
              ),
            ),

            const SizedBox(height: 24),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('BACK'),
                    )
                  else
                    const SizedBox(width: 80),

                  // Next/Get Started button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      _currentPage < _pages.length - 1 ? 'NEXT' : 'GET STARTED',
                      style: const TextStyle(fontSize: 16),
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

  // ✅ FIXED: Wrapped Column in SingleChildScrollView to prevent overflow
  Widget _buildPage(OnboardingPage page) {
    return SingleChildScrollView(  // ✅ ADDED THIS
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),  // ✅ ADDED TOP PADDING
            
            // Icon or Image
            if (page.image != null)
              // For production, load actual images
              Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  page.icon,
                  size: 100,
                  color: page.color,
                ),
              )
            else
              Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: page.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  page.icon,
                  size: 100,
                  color: page.color,
                ),
              ),

            const SizedBox(height: 40),

            // Title
            Text(
              page.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              page.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Permission page specific content
            if (page.isPermissionPage) ...[
              const SizedBox(height: 32),
              _buildPermissionItem(
                Icons.location_on,
                'Location Access',
                'Required to scan WiFi networks (Android system requirement)',
              ),
              const SizedBox(height: 16),
              _buildPermissionItem(
                Icons.notifications,
                'Notifications',
                'Receive alerts when threats are detected',
              ),
            ],
            
            const SizedBox(height: 40),  // ✅ ADDED BOTTOM PADDING
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      _pages.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setOnboardingCompleted(true);
    await prefs.setFirstLaunch(false);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? image;
  final bool isPermissionPage;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.image,
    this.isPermissionPage = false,
  });
}