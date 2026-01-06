import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'dart:math' as math;

/// Utility functions for MITM detection
class MitmDetectionUtils {
  static final Logger _logger = Logger();
  
  /// Get the current WiFi gateway IP address
  static Future<String?> getGatewayIP() async {
    try {
      if (Platform.isAndroid) {
        final result = await Process.run('ip', ['route', 'show', 'default']);
        final output = result.stdout.toString().trim();
        final match = RegExp(r'default via (\d+\.\d+\.\d+\.\d+)').firstMatch(output);
        if (match != null) {
          return match.group(1);
        }
      } else if (Platform.isIOS) {
        // iOS implementation would be different and would rely on method channel
        const platform = MethodChannel('wifi_security/network_info');
        final result = await platform.invokeMethod('getGatewayIP');
        return result.toString();
      }
    } catch (e) {
      _logger.e("Failed to get gateway IP: $e");
    }
    return null;
  }
  
  /// Check if the SSL certificate of a website is valid
  static Future<bool> checkSSLCertificate(String url) async {
    try {
      final HttpClient client = HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          _logger.w("Invalid certificate for $host:$port");
          return false; // Don't accept bad certificates
        };
      
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.drain(); // Drain the response to properly close it
      
      return true; // If we reached here, certificate is valid
    } catch (e) {
      _logger.e("SSL certificate validation failed: $e");
      return false;
    }
  }
  
  /// Check DNS resolution for common domains
  static Future<Map<String, dynamic>> checkDnsResolution() async {
    const domains = [
      'google.com',
      'facebook.com',
      'amazon.com',
      'microsoft.com',
      'apple.com'
    ];
    
    final Map<String, String> results = {};
    bool anomalyDetected = false;
    
    for (final domain in domains) {
      try {
        final List<InternetAddress> addresses = await InternetAddress.lookup(domain);
        if (addresses.isNotEmpty) {
          final ip = addresses.first.address;
          results[domain] = ip;
          
          // Basic check for suspicious IP ranges
          // Note: This is a simplified check and should be expanded in a real implementation
          if (ip.startsWith('127.') || // Localhost
              ip.startsWith('192.168.') || // Private network
              ip.startsWith('10.') || // Private network
              !_isCommonPublicIP(ip)) {
            anomalyDetected = true;
          }
        }
      } catch (e) {
        _logger.e("DNS lookup failed for $domain: $e");
        results[domain] = 'lookup_failed';
        anomalyDetected = true;
      }
    }
    
    return {
      'dns_results': results,
      'anomaly_detected': anomalyDetected,
    };
  }
  
  /// Check if the IP appears to be a common public IP (very simplified check)
  static bool _isCommonPublicIP(String ip) {
    // This is a very simplified check - in a real implementation, 
    // you would check against known ranges of cloud providers, CDNs, etc.
    return !ip.startsWith('127.') && 
           !ip.startsWith('10.') && 
           !ip.startsWith('172.16.') && 
           !ip.startsWith('192.168.');
  }
  
  /// Test for HTTP downgrade attacks
  static Future<bool> testForHttpDowngrade() async {
    const secureUrls = [
      'https://www.google.com',
      'https://www.facebook.com',
      'https://www.amazon.com'
    ];
    
    for (final url in secureUrls) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        request.followRedirects = false; // Don't follow redirects automatically
        
        final response = await request.close();
        await response.drain(); // Drain the response to properly close it
        
        // Check if the response tries to redirect to HTTP
        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null && location.startsWith('http://')) {
            _logger.w("Detected redirect from HTTPS to HTTP for $url");
            return true; // Detected downgrade attempt
          }
        }
      } catch (e) {
        _logger.e("HTTP downgrade test failed for $url: $e");
      }
    }
    
    return false; // No downgrade detected
  }
  
  /// Check for abnormal latency to common domains
  static Future<Map<String, dynamic>> checkNetworkLatency() async {
    const domains = [
      'google.com',
      'cloudflare.com',
      'aws.amazon.com'
    ];
    
    final Map<String, double> latencies = {};
    double totalLatency = 0;
    int successfulPings = 0;
    
    for (final domain in domains) {
      try {
        final stopwatch = Stopwatch()..start();
        
        // Simple DNS lookup to measure latency
        await InternetAddress.lookup(domain);
        
        stopwatch.stop();
        final latency = stopwatch.elapsedMilliseconds.toDouble();
        latencies[domain] = latency;
        totalLatency += latency;
        successfulPings++;
      } catch (e) {
        _logger.e("Latency test failed for $domain: $e");
        latencies[domain] = -1; // Error indicator
      }
    }
    
    double averageLatency = successfulPings > 0 ? totalLatency / successfulPings : 0;
    
    // Calculate standard deviation
    double variance = 0;
    for (final domain in latencies.keys) {
      if (latencies[domain]! >= 0) {
        variance += pow(latencies[domain]! - averageLatency, 2);
      }
    }
    double standardDeviation = successfulPings > 0 ? sqrt(variance / successfulPings) : 0;
    
    return {
      'latencies': latencies,
      'average_latency': averageLatency,
      'standard_deviation': standardDeviation,
      'anomaly_detected': standardDeviation > 50.0 || averageLatency > 200.0, // Thresholds can be adjusted
    };
  }
  
  /// Helper method to calculate standard deviation
  static double sqrt(double value) {
    return value <= 0 ? 0 : math.sqrt(value);
  }
  
  /// Helper method to calculate power
  static double pow(double base, double exponent) {
    if (exponent == 2) return base * base;
    return math.pow(base, exponent).toDouble();
  }
}