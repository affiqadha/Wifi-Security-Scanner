package com.example.android_wifi_scanner

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.util.Log
import java.net.InetAddress
import java.net.UnknownHostException

class DnsChecker(private val context: Context) {
    
    companion object {
        private const val TAG = "DnsChecker"
        
        // Known good DNS servers (expanded list)
        private val TRUSTED_DNS_SERVERS = setOf(
            "8.8.8.8",        // Google
            "8.8.4.4",        // Google Secondary
            "1.1.1.1",        // Cloudflare
            "1.0.0.1",        // Cloudflare Secondary
            "208.67.222.222", // OpenDNS
            "208.67.220.220"  // OpenDNS Secondary
        )
        
        // Common ISP DNS patterns (Malaysia and global)
        private val ISP_DNS_PATTERNS = listOf(
            "^10\\.",           // Private network
            "^172\\.(1[6-9]|2[0-9]|3[0-1])\\.",  // Private network
            "^192\\.168\\.",    // Private network
            "^203\\.80\\.",     // TM (Telekom Malaysia)
            "^202\\.188\\.",    // Maxis
            "^210\\.195\\.",    // TIME
            "^218\\.111\\.",    // Digi
            "^124\\.217\\.",    // Celcom
            "^61\\.6\\.",       // TM Streamyx
        )
        
        // Test domains - using multiple reliable domains
        private val TEST_DOMAINS = listOf(
            "google.com",
            "cloudflare.com", 
            "wikipedia.org",
            "github.com"
        )
    }
    
    // ========== ADDED: Track DNS success rate ==========
    private var lastSuccessfulQueries = 0
    private var lastTotalQueries = 0

    /**
     * Get the success rate of the last DNS check (0.0 to 1.0)
     */
    fun getLastSuccessRate(): Double {
        if (lastTotalQueries == 0) return 1.0 // No test yet, assume OK
        return lastSuccessfulQueries.toDouble() / lastTotalQueries.toDouble()
    }

    /**
     * Get current DNS servers from the system
     */
    fun getCurrentDnsServers(): List<String> {
        val dnsServers = mutableListOf<String>()
        
        try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val activeNetwork = connectivityManager.activeNetwork
            val linkProperties = connectivityManager.getLinkProperties(activeNetwork)
            
            linkProperties?.dnsServers?.forEach { inetAddress ->
                dnsServers.add(inetAddress.hostAddress ?: "")
            }
            
            Log.d(TAG, "Current DNS servers: $dnsServers")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting DNS servers: ${e.message}")
        }
        
        return dnsServers.filter { it.isNotEmpty() }
    }
    
    /**
     * Check if DNS server is from a known ISP
     */
    private fun isIspDns(dnsServer: String): Boolean {
        return ISP_DNS_PATTERNS.any { pattern ->
            dnsServer.matches(Regex(pattern))
        }
    }
    
    /**
     * Check if current DNS servers are trusted
     * Now accepts ISP DNS as potentially safe
     */
    fun areDnsServersTrusted(currentDns: List<String>): Boolean {
        if (currentDns.isEmpty()) {
            return false
        }
        
        // Check if DNS is in trusted public DNS list OR is ISP DNS
        return currentDns.any { dns -> 
            TRUSTED_DNS_SERVERS.contains(dns) || isIspDns(dns)
        }
    }
    
    /**
     * Improved DNS resolution test
     * Only flags as suspicious if resolution completely fails or returns obviously wrong IPs
     */
    fun testDnsResolution(): DnsTestResult {
        val suspiciousResolutions = mutableListOf<SuspiciousResolution>()
        var totalTests = 0
        var successfulTests = 0
        
        TEST_DOMAINS.forEach { domain ->
            totalTests++
            
            try {
                val addresses = InetAddress.getAllByName(domain)
                val resolvedIps = addresses.map { it.hostAddress ?: "" }
                
                Log.d(TAG, "✓ Resolved $domain to: $resolvedIps")
                
                // Check for obviously suspicious patterns
                val isSuspicious = resolvedIps.any { ip ->
                    // Flag if resolving to localhost, private IPs (except for local domains), or invalid IPs
                    ip.startsWith("127.") ||           // Localhost
                    ip.startsWith("0.0.0.") ||         // Invalid
                    ip == "0.0.0.0" ||                 // Blocked/invalid
                    (ip.startsWith("192.168.") && !domain.contains("local")) || // Private IP for public domain
                    (ip.startsWith("10.") && !domain.contains("local")) ||      // Private IP for public domain
                    ip.isEmpty()                        // Empty resolution
                }
                
                if (isSuspicious) {
                    suspiciousResolutions.add(
                        SuspiciousResolution(
                            domain = domain,
                            resolvedIps = resolvedIps,
                            expectedPrefixes = emptyList()
                        )
                    )
                    Log.w(TAG, "⚠️ Suspicious resolution for $domain: $resolvedIps")
                } else {
                    // Resolution looks legitimate
                    successfulTests++
                }
                
            } catch (e: UnknownHostException) {
                Log.w(TAG, "✗ Failed to resolve $domain: ${e.message}")
                // Count as failed - this is significant in MITM attacks
            } catch (e: Exception) {
                Log.e(TAG, "✗ Error resolving $domain: ${e.message}")
            }
        }
        
        // ========== STORE SUCCESS RATE ==========
        lastSuccessfulQueries = successfulTests
        lastTotalQueries = totalTests
        
        val successRate = if (totalTests > 0) {
            successfulTests.toDouble() / totalTests.toDouble()
        } else {
            1.0
        }
        
        Log.d(TAG, "DNS Resolution Results: $successfulTests/$totalTests successful (${(successRate * 100).toInt()}%)")
        
        // Only detect hijacking if multiple tests fail or show suspicious patterns
        val hijackingDetected = suspiciousResolutions.size >= 2 || 
                               (suspiciousResolutions.size > 0 && successfulTests == 0)
        
        return DnsTestResult(
            hijackingDetected = hijackingDetected,
            suspiciousResolutions = suspiciousResolutions,
            totalTests = totalTests,
            successfulTests = successfulTests
        )
    }
    
    /**
     * Comprehensive DNS security check with improved logic
     */
    fun performDnsSecurityCheck(): DnsSecurityResult {
        val currentDns = getCurrentDnsServers()
        val dnsAreTrusted = areDnsServersTrusted(currentDns)
        val testResult = testDnsResolution()
        
        // Only flag as threat if BOTH conditions are true:
        // 1. DNS servers are not trusted AND not ISP DNS
        // 2. DNS resolution test shows clear hijacking
        val hasUntrustedDns = !dnsAreTrusted && currentDns.isNotEmpty()
        val threatDetected = hasUntrustedDns && testResult.hijackingDetected
        
        val threatLevel = when {
            threatDetected && testResult.hijackingDetected -> "Critical"
            testResult.hijackingDetected -> "High" 
            hasUntrustedDns -> "Medium"
            currentDns.isEmpty() -> "Low"
            else -> "Low"
        }
        
        // More nuanced threat detection
        val actualThreatDetected = when {
            // Critical: DNS hijacking detected with untrusted DNS
            testResult.hijackingDetected && hasUntrustedDns -> true
            // High: Clear DNS hijacking even with trusted DNS (rare but serious)
            testResult.hijackingDetected && testResult.suspiciousResolutions.size >= 3 -> true
            // Otherwise: Probably safe
            else -> false
        }
        
        return DnsSecurityResult(
            threatDetected = actualThreatDetected,
            threatLevel = threatLevel,
            currentDnsServers = currentDns,
            dnsAreTrusted = dnsAreTrusted,
            testResult = testResult
        )
    }
    
    data class DnsTestResult(
        val hijackingDetected: Boolean,
        val suspiciousResolutions: List<SuspiciousResolution>,
        val totalTests: Int,
        val successfulTests: Int
    )
    
    data class SuspiciousResolution(
        val domain: String,
        val resolvedIps: List<String>,
        val expectedPrefixes: List<String>,
        val error: String? = null
    )
    
    data class DnsSecurityResult(
        val threatDetected: Boolean,
        val threatLevel: String,
        val currentDnsServers: List<String>,
        val dnsAreTrusted: Boolean,
        val testResult: DnsTestResult
    )
}