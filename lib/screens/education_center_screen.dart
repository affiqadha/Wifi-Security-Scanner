import 'package:flutter/material.dart';
import '/theme/background_pattern.dart';
import 'dart:math' as math;

class EducationCenterScreen extends StatefulWidget {
  @override
  _EducationCenterScreenState createState() => _EducationCenterScreenState();
}

class _EducationCenterScreenState extends State<EducationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("WiFi Security Education"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: "Attack Types"),
            Tab(text: "Animations"),
          ],
        ),
      ),
      body: BackgroundPattern(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAttackTypesTab(isDarkMode),
            _buildAnimationsTab(isDarkMode),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttackTypesTab(bool isDarkMode) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildAttackTypeCard(
          title: "Man-in-the-Middle (MITM) Attacks",
          description: "MITM attacks occur when an attacker secretly relays and possibly alters communication between two parties who believe they are directly communicating with each other.",
          icon: Icons.person_add_disabled,
          color: Colors.red,
          isDarkMode: isDarkMode,
          examples: [
            "In 2017, Equifax was breached through a MITM attack, exposing data of 147 million people.",
            "In 2020, researchers found MITM vulnerabilities in multiple banking apps that could be exploited on public WiFi."
          ],
          prevention: [
            "Always verify website certificates",
            "Use a VPN on public networks",
            "Look for HTTPS in your browser's address bar",
            "Avoid sensitive transactions on public WiFi"
          ]
        ),
        SizedBox(height: 16),
        _buildAttackTypeCard(
          title: "ARP Spoofing",
          description: "ARP spoofing is a type of attack where a malicious actor sends falsified ARP messages over a local network, resulting in the linking of an attacker's MAC address with the IP address of a legitimate computer or server.",
          icon: Icons.swap_horiz,
          color: Colors.orange,
          isDarkMode: isDarkMode,
          examples: [
            "In 2019, researchers demonstrated how ARP spoofing could be used to compromise an entire office network through a single vulnerable IoT device.",
            "Many modern banking trojans use ARP spoofing to intercept financial transactions on local networks."
          ],
          prevention: [
            "Use static ARP entries for critical devices",
            "Implement packet filtering",
            "Use VPNs to encrypt traffic",
            "Utilize ARP spoofing detection tools"
          ]
        ),
        SizedBox(height: 16),
        _buildAttackTypeCard(
          title: "SSL Stripping",
          description: "SSL stripping downgrades HTTPS connections to unsecured HTTP, allowing an attacker to access and modify data that would otherwise be protected by encryption.",
          icon: Icons.https_outlined,
          color: Colors.deepPurple,
          isDarkMode: isDarkMode,
          examples: [
            "The POODLE attack in 2014 exploited SSL vulnerabilities to downgrade connections.",
            "In 2018, security researchers found multiple banking apps vulnerable to SSL stripping attacks."
          ],
          prevention: [
            "Use HSTS (HTTP Strict Transport Security)",
            "Install HTTPS Everywhere browser extension",
            "Manually check for HTTPS in the URL",
            "Never proceed past certificate warnings"
          ]
        ),
        SizedBox(height: 16),
        _buildAttackTypeCard(
          title: "DNS Hijacking",
          description: "DNS hijacking redirects users to fake websites by manipulating Domain Name System queries, potentially leading to phishing, malware distribution, or censorship.",
          icon: Icons.dns,
          color: Colors.teal,
          isDarkMode: isDarkMode,
          examples: [
            "In 2018, a massive DNS hijacking campaign called 'DNSpionage' targeted government and telecommunications organizations.",
            "In 2019, Sea Turtle campaign used DNS hijacking to target at least 40 organizations in 13 countries."
          ],
          prevention: [
            "Use secure DNS providers like Cloudflare (1.1.1.1) or Google (8.8.8.8)",
            "Enable DNS over HTTPS (DoH) or DNS over TLS (DoT)",
            "Utilize DNSSEC where possible",
            "Regularly check your DNS settings"
          ]
        ),
      ],
    );
  }
  
  Widget _buildAttackTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required List<String> examples,
    required List<String> prevention,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: color,
          ),
        ),
        child: ExpansionTile(
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 16),
            _buildExpandableSection(
              title: "Real-World Examples",
              content: examples,
              icon: Icons.history_edu,
              color: color,
            ),
            SizedBox(height: 12),
            _buildExpandableSection(
              title: "Prevention Methods",
              content: prevention,
              icon: Icons.security,
              color: color,
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Navigate to detailed page for this attack type
                },
                icon: Icon(Icons.article_outlined),
                label: Text("Read Full Article"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExpandableSection({
    required String title,
    required List<String> content,
    required IconData icon,
    required Color color,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleSmall?.color,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, size: 16, color: color),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimationsTab(bool isDarkMode) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildAnimationCard(
          title: "How MITM Attacks Work",
          description: "MITM attackers position themselves between you and the website or service you're trying to access.",
          animationWidget: MITMAttackAnimation(),
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 16),
        _buildAnimationCard(
          title: "ARP Spoofing Explained",
          description: "ARP Spoofing tricks devices into sending data to the attacker instead of the intended recipient.",
          animationWidget: ARPSpoofingAnimation(),
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 16),
        _buildAnimationCard(
          title: "SSL Stripping in Action",
          description: "SSL Stripping downgrades your secure HTTPS connection to an insecure HTTP connection.",
          animationWidget: SSLStrippingAnimation(),
          isDarkMode: isDarkMode,
        ),
        SizedBox(height: 16),
        _buildAnimationCard(
          title: "DNS Hijacking Visualized",
          description: "DNS Hijacking redirects you to a malicious website instead of the one you intended to visit.",
          animationWidget: DNSHijackingAnimation(),
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }
  
  Widget _buildAnimationCard({
    required String title,
    required String description,
    required Widget animationWidget,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: animationWidget,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animation Widgets

class MITMAttackAnimation extends StatefulWidget {
  @override
  _MITMAttackAnimationState createState() => _MITMAttackAnimationState();
}

class _MITMAttackAnimationState extends State<MITMAttackAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _packetAnimation;
  late Animation<double> _attackerAppearAnimation;
  late Animation<double> _divertedPacketAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    // Initial packet movement (user to website)
    _packetAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.3, curve: Curves.easeInOut),
      ),
    );

    // Attacker appears
    _attackerAppearAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.4, curve: Curves.easeIn),
      ),
    );

    // Diverted packet movement (through attacker)
    _divertedPacketAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MITMAnimationPainter(
            packetProgress: _packetAnimation.value,
            attackerAppear: _attackerAppearAnimation.value,
            divertedPacketProgress: _divertedPacketAnimation.value,
            isDarkMode: isDarkMode,
          ),
          child: Container(),
        );
      },
    );
  }
}

class MITMAnimationPainter extends CustomPainter {
  final double packetProgress;
  final double attackerAppear;
  final double divertedPacketProgress;
  final bool isDarkMode;

  MITMAnimationPainter({
    required this.packetProgress,
    required this.attackerAppear,
    required this.divertedPacketProgress,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final userPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    final websitePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    final attackerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    final packetPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;
    
    final linePaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final textPaint = Paint()
      ..color = isDarkMode ? Colors.white : Colors.black;
    
    // Draw users and website
    final userCenter = Offset(size.width * 0.15, size.height * 0.5);
    final websiteCenter = Offset(size.width * 0.85, size.height * 0.5);
    
    // Draw user
    canvas.drawCircle(userCenter, 20, userPaint);
    
    // Draw website
    canvas.drawCircle(websiteCenter, 20, websitePaint);
    
    // Draw attacker (appears based on animation)
    if (attackerAppear > 0) {
      final attackerCenter = Offset(size.width * 0.5, size.height * 0.3);
      canvas.drawCircle(attackerCenter, 20 * attackerAppear, attackerPaint);
      
      // Draw text labels
      final textStyle = TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontSize: 12,
      );
      
      final textSpan = TextSpan(
        text: 'Attacker',
        style: textStyle,
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(attackerCenter.dx - textPainter.width / 2, attackerCenter.dy + 25),
      );
      
      // Draw diverted packet path lines
      if (divertedPacketProgress > 0) {
        // Draw line from user to attacker
        if (divertedPacketProgress <= 0.5) {
          final progress = divertedPacketProgress * 2; // Scale to 0-1 range
          final startPoint = userCenter;
          final endPoint = attackerCenter;
          final currentPoint = Offset(
            startPoint.dx + (endPoint.dx - startPoint.dx) * progress,
            startPoint.dy + (endPoint.dy - startPoint.dy) * progress,
          );
          
          canvas.drawLine(startPoint, currentPoint, linePaint);
          canvas.drawCircle(currentPoint, 5, packetPaint);
        } else {
          // Draw complete line from user to attacker
          canvas.drawLine(userCenter, attackerCenter, linePaint);
          
          // Draw line from attacker to website
          final progress = (divertedPacketProgress - 0.5) * 2; // Scale to 0-1 range
          final startPoint = attackerCenter;
          final endPoint = websiteCenter;
          final currentPoint = Offset(
            startPoint.dx + (endPoint.dx - startPoint.dx) * progress,
            startPoint.dy + (endPoint.dy - startPoint.dy) * progress,
          );
          
          canvas.drawLine(startPoint, currentPoint, linePaint);
          canvas.drawCircle(currentPoint, 5, packetPaint);
        }
      }
    } else {
      // Draw direct packet path before attack
      final startPoint = userCenter;
      final endPoint = websiteCenter;
      final currentPoint = Offset(
        startPoint.dx + (endPoint.dx - startPoint.dx) * packetProgress,
        startPoint.dy + (endPoint.dy - startPoint.dy) * packetProgress,
      );
      
      canvas.drawLine(startPoint, currentPoint, linePaint);
      canvas.drawCircle(currentPoint, 5, packetPaint);
    }
    
    // Draw text labels
    final userTextStyle = TextStyle(
      color: isDarkMode ? Colors.white : Colors.black,
      fontSize: 12,
    );
    
    final userTextSpan = TextSpan(
      text: 'You',
      style: userTextStyle,
    );
    
    final userTextPainter = TextPainter(
      text: userTextSpan,
      textDirection: TextDirection.ltr,
    );
    
    userTextPainter.layout();
    userTextPainter.paint(
      canvas,
      Offset(userCenter.dx - userTextPainter.width / 2, userCenter.dy + 25),
    );
    
    final websiteTextSpan = TextSpan(
      text: 'Website',
      style: userTextStyle,
    );
    
    final websiteTextPainter = TextPainter(
      text: websiteTextSpan,
      textDirection: TextDirection.ltr,
    );
    
    websiteTextPainter.layout();
    websiteTextPainter.paint(
      canvas,
      Offset(websiteCenter.dx - websiteTextPainter.width / 2, websiteCenter.dy + 25),
    );
  }

  @override
  bool shouldRepaint(MITMAnimationPainter oldDelegate) {
    return oldDelegate.packetProgress != packetProgress ||
           oldDelegate.attackerAppear != attackerAppear ||
           oldDelegate.divertedPacketProgress != divertedPacketProgress;
  }
}

// Similar animation classes for other attack types
class ARPSpoofingAnimation extends StatefulWidget {
  @override
  _ARPSpoofingAnimationState createState() => _ARPSpoofingAnimationState();
}

class _ARPSpoofingAnimationState extends State<ARPSpoofingAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _normalPacketAnimation;
  late Animation<double> _attackerAppearAnimation;
  late Animation<double> _arpSpoofAnimation;
  late Animation<double> _redirectedPacketAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    // Initial normal packet path
    _normalPacketAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );

    // Attacker appears
    _attackerAppearAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.3, curve: Curves.easeIn),
      ),
    );

    // ARP spoof message
    _arpSpoofAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Redirected packet animation
    _redirectedPacketAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ARPSpoofingAnimationPainter(
            normalPacketProgress: _normalPacketAnimation.value,
            attackerAppear: _attackerAppearAnimation.value,
            arpSpoofProgress: _arpSpoofAnimation.value,
            redirectedPacketProgress: _redirectedPacketAnimation.value,
            isDarkMode: isDarkMode,
          ),
          child: Container(),
        );
      },
    );
  }
}

class ARPSpoofingAnimationPainter extends CustomPainter {
  final double normalPacketProgress;
  final double attackerAppear;
  final double arpSpoofProgress;
  final double redirectedPacketProgress;
  final bool isDarkMode;

  ARPSpoofingAnimationPainter({
    required this.normalPacketProgress,
    required this.attackerAppear,
    required this.arpSpoofProgress,
    required this.redirectedPacketProgress,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final lineColor = isDarkMode ? Colors.white70 : Colors.black54;
    
    // Draw devices
    final userPaint = Paint()..color = Colors.blue;
    final routerPaint = Paint()..color = Colors.green;
    final attackerPaint = Paint()..color = Colors.red;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final packetPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;
    
    // Position devices
    final userPos = Offset(size.width * 0.2, size.height * 0.5);
    final routerPos = Offset(size.width * 0.8, size.height * 0.5);
    final attackerPos = Offset(size.width * 0.5, size.height * 0.2);
    
    // Draw original connection line
    canvas.drawLine(userPos, routerPos, linePaint);
    
    // Draw devices
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(routerPos, 15, routerPaint);
    
    // Draw attacker (appears based on animation)
    if (attackerAppear > 0) {
      // Draw attacker with fade-in effect
      final attackerOpacity = Paint()
        ..color = Colors.red.withOpacity(attackerAppear)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(attackerPos, 15, attackerOpacity);
    }
    
    // Draw normal packet movement
    if (normalPacketProgress < 1) {
      final currentPoint = Offset(
        userPos.dx + (routerPos.dx - userPos.dx) * normalPacketProgress,
        userPos.dy + (routerPos.dy - userPos.dy) * normalPacketProgress,
      );
      canvas.drawCircle(currentPoint, 5, packetPaint);
    }
    
    // Draw ARP spoof message
    if (arpSpoofProgress > 0 && attackerAppear == 1) {
      // Draw ARP message from attacker
      final messageStartPos = attackerPos;
      final messageEndPos = userPos;
      final messageProgress = arpSpoofProgress;
      
      final currentPoint = Offset(
        messageStartPos.dx + (messageEndPos.dx - messageStartPos.dx) * messageProgress,
        messageStartPos.dy + (messageEndPos.dy - messageStartPos.dy) * messageProgress,
      );
      
      // Draw ARP spoof message text if completed
      if (arpSpoofProgress == 1) {
        _drawText(canvas, 'ARP: "I am the router"', 
          Offset((attackerPos.dx + userPos.dx) / 2, (attackerPos.dy + userPos.dy) / 2 - 15), 
          Colors.red);
      }
      
      // Draw message packet
      final messagePaint = Paint()..color = Colors.orange;
      canvas.drawCircle(currentPoint, 5, messagePaint);
    }
    
    // Draw redirected packet movement
    if (redirectedPacketProgress > 0 && arpSpoofProgress == 1) {
      if (redirectedPacketProgress <= 0.5) {
        // From user to attacker
        final progress = redirectedPacketProgress * 2; // Scale to 0-1 for first half
        final currentPoint = Offset(
          userPos.dx + (attackerPos.dx - userPos.dx) * progress,
          userPos.dy + (attackerPos.dy - userPos.dy) * progress,
        );
        
        canvas.drawCircle(currentPoint, 5, packetPaint);
        
        // Draw line to show redirection
        final redirectLinePaint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
        
        canvas.drawLine(userPos, attackerPos, redirectLinePaint);
      } else {
        // From attacker to router
        final progress = (redirectedPacketProgress - 0.5) * 2; // Scale 0.5-1 to 0-1 for second half
        final currentPoint = Offset(
          attackerPos.dx + (routerPos.dx - attackerPos.dx) * progress,
          attackerPos.dy + (routerPos.dy - attackerPos.dy) * progress,
        );
        
        // Draw full line from user to attacker
        final redirectLinePaint = Paint()
          ..color = Colors.red.withOpacity(0.5)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke;
          
        canvas.drawLine(userPos, attackerPos, redirectLinePaint);
        
        // Draw second part of path from attacker to router
        canvas.drawLine(attackerPos, routerPos, redirectLinePaint);
        canvas.drawCircle(currentPoint, 5, packetPaint);
      }
    }
    
    // Draw labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 30), textColor);
    _drawText(canvas, 'Router', routerPos.translate(0, 30), textColor);
    if (attackerAppear > 0) {
      _drawText(canvas, 'Attacker', attackerPos.translate(0, -25), 
        Colors.red.withOpacity(attackerAppear));
    }
  }
  
  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 12,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }
  
  @override
  bool shouldRepaint(ARPSpoofingAnimationPainter oldDelegate) {
    return oldDelegate.normalPacketProgress != normalPacketProgress ||
           oldDelegate.attackerAppear != attackerAppear ||
           oldDelegate.arpSpoofProgress != arpSpoofProgress ||
           oldDelegate.redirectedPacketProgress != redirectedPacketProgress ||
           oldDelegate.isDarkMode != isDarkMode;
  }
}

class SSLStrippingAnimation extends StatefulWidget {
  @override
  _SSLStrippingAnimationState createState() => _SSLStrippingAnimationState();
}

class _SSLStrippingAnimationState extends State<SSLStrippingAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _normalConnectionAnimation;
  late Animation<double> _attackerAppearAnimation;
  late Animation<double> _insecureConnectionAnimation;
  late Animation<double> _secureConnectionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();

    // Initial secure connection animation
    _normalConnectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );

    // Attacker appears
    _attackerAppearAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.3, curve: Curves.easeIn),
      ),
    );

    // Insecure connection (from user to attacker)
    _insecureConnectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.6, curve: Curves.easeInOut),
      ),
    );

    // Secure connection (from attacker to server)
    _secureConnectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.6, 0.9, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SSLStrippingAnimationPainter(
            normalConnectionProgress: _normalConnectionAnimation.value,
            attackerAppear: _attackerAppearAnimation.value,
            insecureConnectionProgress: _insecureConnectionAnimation.value,
            secureConnectionProgress: _secureConnectionAnimation.value,
            isDarkMode: isDarkMode,
          ),
          child: Container(),
        );
      },
    );
  }
}

class SSLStrippingAnimationPainter extends CustomPainter {
  final double normalConnectionProgress;
  final double attackerAppear;
  final double insecureConnectionProgress;
  final double secureConnectionProgress;
  final bool isDarkMode;

  SSLStrippingAnimationPainter({
    required this.normalConnectionProgress,
    required this.attackerAppear,
    required this.insecureConnectionProgress,
    required this.secureConnectionProgress,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Position elements
    final userPos = Offset(size.width * 0.15, size.height * 0.5);
    final serverPos = Offset(size.width * 0.85, size.height * 0.5);
    final attackerPos = Offset(size.width * 0.5, size.height * 0.5);
    
    // Create paints
    final userPaint = Paint()..color = Colors.blue;
    final serverPaint = Paint()..color = Colors.green;
    final attackerPaint = Paint()..color = Colors.red.withOpacity(attackerAppear);
    final securePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final insecurePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final packetSecurePaint = Paint()..color = Colors.green;
    final packetInsecurePaint = Paint()..color = Colors.red;
    
    // Initial connect phase - direct secure connection
    if (normalConnectionProgress <= 1 && attackerAppear < 0.5) {
      // Draw secure line
      canvas.drawLine(userPos, serverPos, securePaint);
      
      // Draw packet movement
      final packetPos = Offset(
        userPos.dx + (serverPos.dx - userPos.dx) * normalConnectionProgress,
        userPos.dy + (serverPos.dy - userPos.dy) * normalConnectionProgress,
      );
      
      canvas.drawCircle(packetPos, 5, packetSecurePaint);
      
      // Draw lock icon at the packet
      _drawLockIcon(canvas, packetPos, size.width * 0.02);
    }
    
    // Draw attacker appearing
    if (attackerAppear > 0) {
      // Draw attacker
      canvas.drawCircle(attackerPos, 15, attackerPaint);
      
      // Draw text label for attacker with fade-in
      final textSpan = TextSpan(
        text: 'Attacker',
        style: TextStyle(
          color: Colors.red.withOpacity(attackerAppear),
          fontSize: 12,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(attackerPos.dx - textPainter.width / 2, attackerPos.dy + 20),
      );
    }
    
    // Insecure connection phase (user to attacker)
    if (insecureConnectionProgress > 0 && attackerAppear >= 1) {
      // Draw insecure line
      canvas.drawLine(userPos, attackerPos, insecurePaint);
      
      // Draw secure line from attacker to server
      canvas.drawLine(attackerPos, serverPos, securePaint);
      
      // Draw packet movement
      final packetPos = Offset(
        userPos.dx + (attackerPos.dx - userPos.dx) * insecureConnectionProgress,
        userPos.dy + (attackerPos.dy - userPos.dy) * insecureConnectionProgress,
      );
      
      canvas.drawCircle(packetPos, 5, packetInsecurePaint);
      
      // If complete, show interception indicator
      if (insecureConnectionProgress >= 0.95) {
        _drawText(canvas, "HTTP (no lock)", 
          Offset((userPos.dx + attackerPos.dx) / 2, userPos.dy - 25), 
          Colors.red);
      }
    }
    
    // Secure connection phase (attacker to server)
    if (secureConnectionProgress > 0 && insecureConnectionProgress >= 0.95) {
      // Draw packet movement
      final packetPos = Offset(
        attackerPos.dx + (serverPos.dx - attackerPos.dx) * secureConnectionProgress,
        attackerPos.dy + (serverPos.dy - attackerPos.dy) * secureConnectionProgress,
      );
      
      canvas.drawCircle(packetPos, 5, packetSecurePaint);
      
      // Draw lock icon at the packet
      _drawLockIcon(canvas, packetPos, size.width * 0.02);
      
      // If complete, show secure connection indicator
      if (secureConnectionProgress >= 0.95) {
        _drawText(canvas, "HTTPS (with lock)", 
          Offset((attackerPos.dx + serverPos.dx) / 2, serverPos.dy - 25), 
          Colors.green);
      }
    }
    
    // Draw devices
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(serverPos, 15, serverPaint);
    
    // Draw labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 30), textColor);
    _drawText(canvas, 'Website', serverPos.translate(0, 30), textColor);
  }
  
  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 12,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }
  
  void _drawLockIcon(Canvas canvas, Offset center, double size) {
    final lockBodyPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;
    
    final lockShacklePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.3;
    
    // Draw lock body
    final lockBodyRect = Rect.fromCenter(
      center: center.translate(0, size * 0.5),
      width: size * 1.5,
      height: size * 1.5,
    );
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(lockBodyRect, Radius.circular(size * 0.3)),
      lockBodyPaint,
    );
    
    // Draw lock shackle
    final path = Path()
      ..moveTo(center.dx - size * 0.5, center.dy)
      ..lineTo(center.dx - size * 0.5, center.dy - size * 0.7)
      ..arcTo(
        Rect.fromCircle(center: center.translate(0, center.dy - size * 0.7), radius: size * 0.5),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(center.dx + size * 0.5, center.dy);
    
    canvas.drawPath(path, lockShacklePaint);
  }
  
  @override
  bool shouldRepaint(SSLStrippingAnimationPainter oldDelegate) {
    return oldDelegate.normalConnectionProgress != normalConnectionProgress ||
           oldDelegate.attackerAppear != attackerAppear ||
           oldDelegate.insecureConnectionProgress != insecureConnectionProgress ||
           oldDelegate.secureConnectionProgress != secureConnectionProgress ||
           oldDelegate.isDarkMode != isDarkMode;
  }
}

class DNSHijackingAnimation extends StatefulWidget {
  @override
  _DNSHijackingAnimationState createState() => _DNSHijackingAnimationState();
}

class _DNSHijackingAnimationState extends State<DNSHijackingAnimation> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _initialQueryAnimation;
  late Animation<double> _fakeDnsAppearAnimation;
  late Animation<double> _dnsRedirectAnimation;
  late Animation<double> _fakeWebsiteRedirectAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat();

    // Initial DNS query
    _initialQueryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.2, curve: Curves.easeInOut),
      ),
    );

    // Fake DNS appears
    _fakeDnsAppearAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.2, 0.3, curve: Curves.easeIn),
      ),
    );

    // DNS query gets redirected
    _dnsRedirectAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.3, 0.6, curve: Curves.easeInOut),
      ),
    );

    // Redirect to fake website
    _fakeWebsiteRedirectAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.6, 0.9, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: DNSHijackingAnimationPainter(
            initialQueryProgress: _initialQueryAnimation.value,
            fakeDnsAppear: _fakeDnsAppearAnimation.value,
            dnsRedirectProgress: _dnsRedirectAnimation.value,
            fakeWebsiteRedirectProgress: _fakeWebsiteRedirectAnimation.value,
            isDarkMode: isDarkMode,
          ),
          child: Container(),
        );
      },
    );
  }
}

class DNSHijackingAnimationPainter extends CustomPainter {
  final double initialQueryProgress;
  final double fakeDnsAppear;
  final double dnsRedirectProgress;
  final double fakeWebsiteRedirectProgress;
  final bool isDarkMode;

  DNSHijackingAnimationPainter({
    required this.initialQueryProgress,
    required this.fakeDnsAppear,
    required this.dnsRedirectProgress,
    required this.fakeWebsiteRedirectProgress,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Positions
    final userPos = Offset(size.width * 0.2, size.height * 0.5);
    final dnsServerPos = Offset(size.width * 0.5, size.height * 0.3);
    final fakeDnsPos = Offset(size.width * 0.5, size.height * 0.7);
    final realWebsitePos = Offset(size.width * 0.8, size.height * 0.3);
    final fakeWebsitePos = Offset(size.width * 0.8, size.height * 0.7);
    
    // Colors
    final userPaint = Paint()..color = Colors.blue;
    final dnsServerPaint = Paint()..color = Colors.green;
    final fakeDnsPaint = Paint()..color = Colors.red.withOpacity(fakeDnsAppear);
    final realWebsitePaint = Paint()..color = Colors.green;
    final fakeWebsitePaint = Paint()..color = Colors.red.withOpacity(fakeDnsAppear);
    final queryPaint = Paint()..color = Colors.orange;
    final redirectPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final normalPaint = Paint()
      ..color = isDarkMode ? Colors.white70 : Colors.black54
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Draw legitimate components
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(dnsServerPos, 15, dnsServerPaint);
    canvas.drawCircle(realWebsitePos, 15, realWebsitePaint);
    
    // Draw fake components with fade-in
    if (fakeDnsAppear > 0) {
      canvas.drawCircle(fakeDnsPos, 15, fakeDnsPaint);
      canvas.drawCircle(fakeWebsitePos, 15, fakeWebsitePaint);
    }
    
    // Initial DNS query phase
    if (initialQueryProgress <= 1 && fakeDnsAppear < 0.5) {
      final queryPos = Offset(
        userPos.dx + (dnsServerPos.dx - userPos.dx) * initialQueryProgress,
        userPos.dy + (dnsServerPos.dy - userPos.dy) * initialQueryProgress,
      );
      
      canvas.drawLine(userPos, queryPos, normalPaint);
      canvas.drawCircle(queryPos, 5, queryPaint);
      
      if (initialQueryProgress > 0.8) {
        _drawText(canvas, "DNS Query: 'example.com'", 
          Offset((userPos.dx + dnsServerPos.dx) / 2, (userPos.dy + dnsServerPos.dy) / 2 - 15), 
          Colors.orange);
      }
      
      // Draw response from DNS server to real website if query completed
      if (initialQueryProgress == 1) {
        // Draw line from DNS to real website
        canvas.drawLine(dnsServerPos, realWebsitePos, normalPaint);
        
        // Draw arrow from DNS to user with website IP
        _drawArrow(canvas, dnsServerPos, userPos, normalPaint);
        _drawText(canvas, "Response: IP 93.184.216.34", 
          Offset((userPos.dx + dnsServerPos.dx) / 2, (userPos.dy + dnsServerPos.dy) / 2 + 15), 
          Colors.green);
      }
    }
    
    // DNS Redirect phase
    if (dnsRedirectProgress > 0 && fakeDnsAppear >= 1) {
      // Draw fake DNS connection
      _drawArrow(canvas, userPos, fakeDnsPos, redirectPaint);
      
      // Show DNS query being redirected to fake DNS
      final queryPos = Offset(
        userPos.dx + (fakeDnsPos.dx - userPos.dx) * dnsRedirectProgress,
        userPos.dy + (fakeDnsPos.dy - userPos.dy) * dnsRedirectProgress,
      );
      
      canvas.drawCircle(queryPos, 5, queryPaint);
      
      if (dnsRedirectProgress > 0.8) {
        _drawText(canvas, "DNS Query: 'example.com'", 
          Offset((userPos.dx + fakeDnsPos.dx) / 2, (userPos.dy + fakeDnsPos.dy) / 2 - 15), 
          Colors.orange);
      }
      
      // If redirect complete, show connection to fake website
      if (dnsRedirectProgress >= 0.95) {
        // Draw line from fake DNS to fake website
        canvas.drawLine(fakeDnsPos, fakeWebsitePos, redirectPaint);
        
        // Draw arrow from fake DNS to user with fake website IP
        _drawArrow(canvas, fakeDnsPos, userPos, redirectPaint);
        _drawText(canvas, "Malicious Response: IP 192.168.1.100", 
          Offset((userPos.dx + fakeDnsPos.dx) / 2, (userPos.dy + fakeDnsPos.dy) / 2 + 15), 
          Colors.red);
      }
    }
    
    // Fake website redirection phase
    if (fakeWebsiteRedirectProgress > 0 && dnsRedirectProgress >= 0.95) {
      // Draw connection from user to fake website
      _drawArrow(canvas, userPos, fakeWebsitePos, redirectPaint);
      
      // Show user request going to fake website
      final requestPos = Offset(
        userPos.dx + (fakeWebsitePos.dx - userPos.dx) * fakeWebsiteRedirectProgress,
        userPos.dy + (fakeWebsitePos.dy - userPos.dy) * fakeWebsiteRedirectProgress,
      );
      
      canvas.drawCircle(requestPos, 5, userPaint);
      
      if (fakeWebsiteRedirectProgress > 0.8) {
        _drawText(canvas, "User connects to fake site", 
          Offset((userPos.dx + fakeWebsitePos.dx) / 2, (userPos.dy + fakeWebsitePos.dy) / 2 - 15), 
          Colors.red);
      }
    }
    
    // Draw labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 30), textColor);
    _drawText(canvas, 'Real DNS', dnsServerPos.translate(0, -25), Colors.green);
    _drawText(canvas, 'Real Website', realWebsitePos.translate(0, -25), Colors.green);
    
    if (fakeDnsAppear > 0) {
      _drawText(canvas, 'Fake DNS', fakeDnsPos.translate(0, 25), 
        Colors.red.withOpacity(fakeDnsAppear));
      _drawText(canvas, 'Fake Website', fakeWebsitePos.translate(0, 25), 
        Colors.red.withOpacity(fakeDnsAppear));
    }
  }
  
  void _drawText(Canvas canvas, String text, Offset position, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 12,
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy),
    );
  }
  
  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    // Draw line
    canvas.drawLine(start, end, paint);
    
    // Draw arrowhead
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    
    final arrowSize = 10.0;
    
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * math.cos(angle - math.pi / 6),
        end.dy - arrowSize * math.sin(angle - math.pi / 6)
      )
      ..lineTo(
        end.dx - arrowSize * math.cos(angle + math.pi / 6),
        end.dy - arrowSize * math.sin(angle + math.pi / 6)
      )
      ..close();
    
    canvas.drawPath(arrowPath, Paint()..color = paint.color);
  }
  
  @override
  bool shouldRepaint(DNSHijackingAnimationPainter oldDelegate) {
    return oldDelegate.initialQueryProgress != initialQueryProgress ||
           oldDelegate.fakeDnsAppear != fakeDnsAppear ||
           oldDelegate.dnsRedirectProgress != dnsRedirectProgress ||
           oldDelegate.fakeWebsiteRedirectProgress != fakeWebsiteRedirectProgress ||
           oldDelegate.isDarkMode != isDarkMode;
  }
}