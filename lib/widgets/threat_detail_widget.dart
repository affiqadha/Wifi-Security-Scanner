import 'package:flutter/material.dart';
import '/services/real_mitm_detection_service.dart';
import 'dart:math' as math; 
import '/screens/education_center_screen.dart'; 

class ThreatDetailWidget extends StatelessWidget {
  final DetectionType detectionType;
  
  const ThreatDetailWidget({
    Key? key,
    required this.detectionType,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getAttackTitle(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 16),
            _buildAttackDiagram(context, isDarkMode),
            SizedBox(height: 16),
            ExpansionTile(
              title: Text(
                "How It Works",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              childrenPadding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
              children: [
                Text(
                  _getAttackExplanation(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text(
                "Real-World Examples",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              childrenPadding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _getRealWorldExamples().map((example) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.article, size: 16, color: _getAttackColor()),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            example,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
            ExpansionTile(
              title: Text(
                "Protection Methods",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleMedium?.color,
                ),
              ),
              childrenPadding: EdgeInsets.only(bottom: 16, left: 16, right: 16),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _getProtectionMethods().map((method) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            method,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EducationCenterScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.school),
                label: Text("Learn More in Education Center"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _getAttackColor(),
                  side: BorderSide(color: _getAttackColor()),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttackDiagram(BuildContext context, bool isDarkMode) {
    // Different diagrams based on the attack type
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return _buildARPSpoofingDiagram(context, isDarkMode);
      case DetectionType.sslStripping:
        return _buildSSLStrippingDiagram(context, isDarkMode);
      case DetectionType.dnsHijacking:
        return _buildDNSHijackingDiagram(context, isDarkMode);
      case DetectionType.packetAnalysis:
        return _buildPacketAnalysisDiagram(context, isDarkMode);
      default:
        return SizedBox.shrink();
    }
  }
  
  Widget _buildARPSpoofingDiagram(BuildContext context, bool isDarkMode) {
  return Container(
    height: 150,
    decoration: BoxDecoration(
      color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: ARPSpoofingAnimation(),
  );
}

Widget _buildSSLStrippingDiagram(BuildContext context, bool isDarkMode) {
  return Container(
    height: 150,
    decoration: BoxDecoration(
      color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: SSLStrippingAnimation(),
  );
}

Widget _buildDNSHijackingDiagram(BuildContext context, bool isDarkMode) {
  return Container(
    height: 150,
    decoration: BoxDecoration(
      color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DNSHijackingAnimation(),
  );
}

Widget _buildPacketAnalysisDiagram(BuildContext context, bool isDarkMode) {
  // Keep the original implementation or use a new animation
  return Container(
    height: 150,
    decoration: BoxDecoration(
      color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: CustomPaint(
      painter: PacketAnalysisDiagramPainter(
        isDarkMode: isDarkMode,
      ),
      size: Size.infinite,
    ),
  );
}
  
  String _getAttackTitle() {
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return "ARP Spoofing Attack";
      case DetectionType.sslStripping:
        return "SSL Stripping Attack";
      case DetectionType.dnsHijacking:
        return "DNS Hijacking Attack";
      case DetectionType.packetAnalysis:
        return "Traffic Interception";
      default:
        return "Unknown Attack";
    }
  }
  
  Color _getAttackColor() {
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return Colors.orange;
      case DetectionType.sslStripping:
        return Colors.deepPurple;
      case DetectionType.dnsHijacking:
        return Colors.teal;
      case DetectionType.packetAnalysis:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getAttackExplanation() {
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return "ARP Spoofing occurs when an attacker sends falsified ARP (Address Resolution Protocol) messages over a local area network. This results in the linking of an attacker's MAC address with the IP address of a legitimate computer or server on the network. Once the attacker's MAC address is connected to an authentic IP address, the attacker can intercept, modify, or stop data in transit.\n\nThe attack works because ARP does not include authentication mechanisms, so network devices accept all ARP responses, even those they didn't specifically request.";
      case DetectionType.sslStripping:
        return "SSL Stripping is an attack that downgrades a secure HTTPS connection to an unsecured HTTP connection, exposing sensitive data. When you visit a website using HTTPS, the attacker intercepts the connection and establishes two separate connections: an HTTPS connection with the website and an HTTP connection with you.\n\nThis attack exploits the fact that most users don't directly type 'https://' in the URL bar but instead rely on the website to redirect from HTTP to HTTPS. The attacker prevents this redirect, maintaining an unsecured connection with the victim while keeping a secure connection with the legitimate website.";
      case DetectionType.dnsHijacking:
        return "DNS Hijacking occurs when attackers compromise the DNS (Domain Name System) resolution process. DNS normally translates human-readable domain names (like example.com) into machine-readable IP addresses. In a DNS hijacking attack, the attacker modifies this translation process to redirect you to malicious websites.\n\nThe attack can happen through several methods: compromising the router's DNS settings, infecting your device with malware that changes DNS settings, compromising a DNS server, or manipulating the communication between your device and the DNS server.";
      case DetectionType.packetAnalysis:
        return "Traffic Interception attacks involve capturing and analyzing data packets as they travel across a network. This attack is detected by analyzing timing patterns and network behavior. When a MITM attacker intercepts traffic, they often must process it before forwarding it on, creating detectable delays or patterns.\n\nThe attack works by positioning a malicious actor between your device and the destination, allowing them to view all unencrypted data. Even with encryption, metadata about the connections can reveal valuable information. This attack is particularly dangerous on public WiFi networks.";
      default:
        return "The details of this attack type are not available.";
    }
  }
  
  List<String> _getRealWorldExamples() {
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return [
          "In 2019, researchers demonstrated ARP spoofing to hijack smart home devices, showing how an attacker could control IoT devices on the same network.",
          "The banking trojan 'Qakbot' uses ARP spoofing to intercept banking credentials on infected networks.",
          "Many corporate data breaches begin with lateral movement through networks using ARP spoofing techniques."
        ];
      case DetectionType.sslStripping:
        return [
          "In 2009, security researcher Moxie Marlinspike demonstrated SSL stripping at the Black Hat security conference, showing how easily HTTPS connections could be downgraded.",
          "The POODLE attack in 2014 exploited weaknesses to force SSL downgrades, affecting major websites.",
          "In 2017, researchers found multiple banking apps vulnerable to SSL stripping, potentially exposing users' financial data."
        ];
      case DetectionType.dnsHijacking:
        return [
          "In 2018, attackers launched 'DNSpionage', targeting government networks in the Middle East by redirecting legitimate domains to malicious servers.",
          "In 2019, the 'Sea Turtle' attack campaign used DNS hijacking to target at least 40 organizations across 13 countries.",
          "The Syrian Electronic Army hijacked the New York Times and Twitter domains in 2013 by attacking their DNS registrar."
        ];
      case DetectionType.packetAnalysis:
        return [
          "In 2018, researchers detected unusual network traffic that revealed the 'Dark Caracal' global espionage campaign targeting mobile devices.",
          "The Equifax breach in 2017 was eventually detected through anomalous network traffic patterns.",
          "In 2020, a major telecommunications provider identified an advanced persistent threat by detecting unusual packet timing between compromised machines."
        ];
      default:
        return ["No specific examples available for this attack type."];
    }
  }
  
  List<String> _getProtectionMethods() {
    switch (detectionType) {
      case DetectionType.arpSpoofing:
        return [
          "Use a Virtual Private Network (VPN) to encrypt your traffic",
          "Enable packet filtering on your router if available",
          "Use static ARP entries for critical devices like your gateway",
          "Implement network monitoring tools that can detect ARP anomalies",
          "Keep your device's operating system and security software updated"
        ];
      case DetectionType.sslStripping:
        return [
          "Always verify that websites use HTTPS (look for the lock icon)",
          "Install browser extensions like HTTPS Everywhere",
          "Be cautious when connecting to public WiFi networks",
          "Use a VPN for an extra layer of encryption",
          "Enable HSTS on your own websites if you manage them"
        ];
      case DetectionType.dnsHijacking:
        return [
          "Use secure DNS providers like Cloudflare (1.1.1.1) or Google (8.8.8.8)",
          "Enable DNS over HTTPS (DoH) or DNS over TLS (DoT) in your browser",
          "Regularly check your DNS settings for unexpected changes",
          "Use DNSSEC-validating resolvers when possible",
          "Secure your router with a strong password and keep its firmware updated"
        ];
      case DetectionType.packetAnalysis:
        return [
          "Use end-to-end encrypted messaging and file-sharing applications",
          "Avoid sending sensitive information over untrusted networks",
          "Enable encryption for all your online activities (email, browsing, etc.)",
          "Use a VPN to encrypt your internet traffic",
          "Regularly scan your devices for malware and security vulnerabilities"
        ];
      default:
        return ["General security practices recommended."];
    }
  }
}

class ARPSpoofingDiagramPainter extends CustomPainter {
  final bool isDarkMode;
  
  ARPSpoofingDiagramPainter({required this.isDarkMode});
  
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
    final dashedLinePaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Position devices
    final userPos = Offset(size.width * 0.2, size.height * 0.5);
    final routerPos = Offset(size.width * 0.8, size.height * 0.5);
    final attackerPos = Offset(size.width * 0.5, size.height * 0.2);
    
    // Draw devices
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(routerPos, 15, routerPaint);
    canvas.drawCircle(attackerPos, 15, attackerPaint);
    
    // Draw lines
    canvas.drawLine(userPos, routerPos, linePaint);
    
    // Draw dashed line for attack path
    _drawDashedLine(canvas, userPos, attackerPos, dashedLinePaint);
    _drawDashedLine(canvas, attackerPos, routerPos, dashedLinePaint);
    
    // Add text labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 25), textColor);
    _drawText(canvas, 'Router', routerPos.translate(0, 25), textColor);
    _drawText(canvas, 'Attacker', attackerPos.translate(0, 25), textColor);
    
    // Add ARP info text
    final arpInfoPos = Offset(size.width * 0.5, size.height * 0.8);
    _drawText(canvas, 'ARP: "I am 192.168.1.1"', arpInfoPos, Colors.red);
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
  
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5;
    const dashSpace = 3;
    
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    
    final steps = dist / (dashWidth + dashSpace);
    final stepX = dx / steps;
    final stepY = dy / steps;
    
    var currentX = start.dx;
    var currentY = start.dy;
    
    for (var i = 0; i < steps; i++) {
      canvas.drawLine(
        Offset(currentX, currentY),
        Offset(currentX + stepX * dashWidth / (dashWidth + dashSpace), 
               currentY + stepY * dashWidth / (dashWidth + dashSpace)),
        paint,
      );
      
      currentX += stepX;
      currentY += stepY;
    }
  }
  
  @override
  bool shouldRepaint(ARPSpoofingDiagramPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}

class SSLStrippingDiagramPainter extends CustomPainter {
  final bool isDarkMode;
  
  SSLStrippingDiagramPainter({required this.isDarkMode});
  
  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Draw devices
    final userPaint = Paint()..color = Colors.blue;
    final serverPaint = Paint()..color = Colors.green;
    final attackerPaint = Paint()..color = Colors.red;
    final securePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final insecurePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    // Position elements
    final userPos = Offset(size.width * 0.15, size.height * 0.5);
    final serverPos = Offset(size.width * 0.85, size.height * 0.5);
    final attackerPos = Offset(size.width * 0.5, size.height * 0.5);
    
    // Draw elements
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(serverPos, 15, serverPaint);
    canvas.drawCircle(attackerPos, 15, attackerPaint);
    
    // Draw connections
    canvas.drawLine(userPos, attackerPos, insecurePaint);
    canvas.drawLine(attackerPos, serverPos, securePaint);
    
    // Draw labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 25), textColor);
    _drawText(canvas, 'Website', serverPos.translate(0, 25), textColor);
    _drawText(canvas, 'Attacker', attackerPos.translate(0, 25), textColor);
    
    // Connection labels
    _drawText(canvas, 'HTTP (Insecure)', Offset(size.width * 0.32, size.height * 0.3), Colors.red);
    _drawText(canvas, 'HTTPS (Secure)', Offset(size.width * 0.67, size.height * 0.3), Colors.green);
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
  bool shouldRepaint(SSLStrippingDiagramPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}

class DNSHijackingDiagramPainter extends CustomPainter {
  final bool isDarkMode;
  
  DNSHijackingDiagramPainter({required this.isDarkMode});
  
  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Draw devices
    final userPaint = Paint()..color = Colors.blue;
    final dnsServerPaint = Paint()..color = Colors.green;
    final fakeDnsPaint = Paint()..color = Colors.red;
    final realWebsitePaint = Paint()..color = Colors.green;
    final fakeWebsitePaint = Paint()..color = Colors.red;
    final arrowPaint = Paint()
      ..color = isDarkMode ? Colors.white70 : Colors.black54
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final redirectPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    // Positions
    final userPos = Offset(size.width * 0.2, size.height * 0.5);
    final dnsServerPos = Offset(size.width * 0.5, size.height * 0.3);
    final fakeDnsPos = Offset(size.width * 0.5, size.height * 0.7);
    final realWebsitePos = Offset(size.width * 0.8, size.height * 0.3);
    final fakeWebsitePos = Offset(size.width * 0.8, size.height * 0.7);
    
    // Draw elements
    canvas.drawCircle(userPos, 15, userPaint);
    canvas.drawCircle(dnsServerPos, 15, dnsServerPaint);
    canvas.drawCircle(fakeDnsPos, 15, fakeDnsPaint);
    canvas.drawCircle(realWebsitePos, 15, realWebsitePaint);
    canvas.drawCircle(fakeWebsitePos, 15, fakeWebsitePaint);
    
    // Draw connections
    _drawArrow(canvas, userPos, dnsServerPos, arrowPaint);
    _drawArrow(canvas, userPos, fakeDnsPos, redirectPaint);
    _drawArrow(canvas, dnsServerPos, realWebsitePos, arrowPaint);
    _drawArrow(canvas, fakeDnsPos, fakeWebsitePos, redirectPaint);
    
    // Labels
    _drawText(canvas, 'Your Device', userPos.translate(0, 30), textColor);
    _drawText(canvas, 'Real DNS', dnsServerPos.translate(0, -25), Colors.green);
    _drawText(canvas, 'Fake DNS', fakeDnsPos.translate(0, 25), Colors.red);
    _drawText(canvas, 'Real Website', realWebsitePos.translate(0, -25), Colors.green);
    _drawText(canvas, 'Fake Website', fakeWebsitePos.translate(0, 25), Colors.red);
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
  bool shouldRepaint(DNSHijackingDiagramPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}

class PacketAnalysisDiagramPainter extends CustomPainter {
  final bool isDarkMode;
  
  PacketAnalysisDiagramPainter({required this.isDarkMode});
  
  @override
  void paint(Canvas canvas, Size size) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Draw network flow
    final normalLinePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2;
    final slowLinePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    final packetPaint = Paint()
      ..color = Colors.blue;
    
    // Draw baseline
    final baselineY = size.height * 0.5;
    canvas.drawLine(
      Offset(20, baselineY),
      Offset(size.width - 20, baselineY),
      Paint()..color = isDarkMode ? Colors.white30 : Colors.black12,
    );
    
    // Draw normal traffic
    for (var i = 0; i < 5; i++) {
      final x = 30 + i * 30.0;
      final y = baselineY - 10;
      canvas.drawCircle(Offset(x, y), 5, packetPaint);
    }
    
    // Draw intercepted traffic
    for (var i = 0; i < 5; i++) {
      final x = size.width / 2 + 30 + i * 50.0;
      final y = baselineY - 10;
      canvas.drawCircle(Offset(x, y), 5, packetPaint);
    }
    
    // Draw labels
    _drawText(canvas, 'Normal Traffic', Offset(size.width * 0.25, size.height * 0.2), Colors.green);
    _drawText(canvas, 'Delayed Traffic', Offset(size.width * 0.75, size.height * 0.2), Colors.red);
    
    // Draw timing indicators
    _drawVerticalLine(canvas, 30, baselineY + 10, 30, Colors.green);
    _drawVerticalLine(canvas, 60, baselineY + 10, 30, Colors.green);
    _drawVerticalLine(canvas, 90, baselineY + 10, 30, Colors.green);
    _drawVerticalLine(canvas, 120, baselineY + 10, 30, Colors.green);
    
    _drawVerticalLine(canvas, size.width / 2 + 30, baselineY + 10, 30, Colors.red);
    _drawVerticalLine(canvas, size.width / 2 + 80, baselineY + 10, 30, Colors.red);
    _drawVerticalLine(canvas, size.width / 2 + 130, baselineY + 10, 30, Colors.red);
    _drawVerticalLine(canvas, size.width / 2 + 180, baselineY + 10, 30, Colors.red);
    
    // Draw explanation
    _drawText(canvas, 'Regular intervals', Offset(size.width * 0.25, size.height * 0.8), textColor);
    _drawText(canvas, 'Irregular delays', Offset(size.width * 0.75, size.height * 0.8), textColor);
  }
  
  void _drawVerticalLine(Canvas canvas, double x, double topY, double height, Color color) {
    canvas.drawLine(
      Offset(x, topY),
      Offset(x, topY + height),
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
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
  bool shouldRepaint(PacketAnalysisDiagramPainter oldDelegate) {
    return oldDelegate.isDarkMode != isDarkMode;
  }
}