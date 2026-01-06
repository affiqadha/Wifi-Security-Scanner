package com.example.android_wifi_scanner

import android.util.Log

/**
 * Debug helper to log detailed MITM detection results
 * Updated to support HybridNetworkScanner
 */
object MitmDebugLogger {
    private const val TAG = "MITMDebug"
    
    fun logDetectionResults(
        networkThreat: HybridNetworkScanner.MitmThreatResult,
        currentDevices: List<HybridNetworkScanner.Device>,
        dnsResult: DnsChecker.DnsSecurityResult,
        sslResult: CertificateValidator.SslSecurityResult
    ) {
        Log.d(TAG, "========== MITM DETECTION DEBUG ==========")
        
        // Network Scan Results
        Log.d(TAG, "--- NETWORK SCAN CHECK ---")
        Log.d(TAG, "Detection Method: ${networkThreat.detectionMethod}")
        Log.d(TAG, "Threat Detected: ${networkThreat.threatDetected}")
        Log.d(TAG, "Device Count: ${networkThreat.deviceCount}")
        
        if (networkThreat.threats.isNotEmpty()) {
            Log.w(TAG, "Network Threats:")
            networkThreat.threats.forEach { threat ->
                Log.w(TAG, "  - $threat")
            }
        }
        
        Log.d(TAG, "Devices Found:")
        currentDevices.forEach { device ->
            val macInfo = device.macAddress ?: "unavailable"
            val hostnameInfo = device.hostname ?: "unknown"
            Log.d(TAG, "  ${device.ipAddress} | MAC: $macInfo | Host: $hostnameInfo | Method: ${device.detectionMethod}")
        }
        
        // DNS Results
        Log.d(TAG, "--- DNS SECURITY CHECK ---")
        Log.d(TAG, "Threat Detected: ${dnsResult.threatDetected}")
        Log.d(TAG, "Threat Level: ${dnsResult.threatLevel}")
        Log.d(TAG, "DNS Servers: ${dnsResult.currentDnsServers}")
        Log.d(TAG, "DNS Trusted: ${dnsResult.dnsAreTrusted}")
        Log.d(TAG, "Hijacking Detected: ${dnsResult.testResult.hijackingDetected}")
        Log.d(TAG, "Successful DNS Tests: ${dnsResult.testResult.successfulTests}/${dnsResult.testResult.totalTests}")
        
        if (dnsResult.testResult.suspiciousResolutions.isNotEmpty()) {
            dnsResult.testResult.suspiciousResolutions.forEach { suspicious ->
                Log.w(TAG, "Suspicious DNS: ${suspicious.domain} -> ${suspicious.resolvedIps}")
            }
        }
        
        // SSL Results
        Log.d(TAG, "--- SSL SECURITY CHECK ---")
        Log.d(TAG, "Threat Detected: ${sslResult.threatDetected}")
        Log.d(TAG, "Threat Level: ${sslResult.threatLevel}")
        Log.d(TAG, "Self-Signed Certs: ${sslResult.selfSignedCount}")
        Log.d(TAG, "Invalid Certs: ${sslResult.invalidCertCount}")
        Log.d(TAG, "SSL Stripping: ${sslResult.strippingResult.strippingDetected}")
        Log.d(TAG, "HTTPS Successful: ${sslResult.strippingResult.httpsSuccessful}/${sslResult.strippingResult.totalTests}")
        
        if (sslResult.strippingResult.suspiciousConnections.isNotEmpty()) {
            sslResult.strippingResult.suspiciousConnections.forEach { url ->
                Log.w(TAG, "Suspicious SSL Connection: $url")
            }
        }
        
        sslResult.certificateResults.forEach { certResult ->
            Log.d(TAG, "Certificate Check: ${certResult.url}")
            Log.d(TAG, "  Valid: ${certResult.isValid}")
            Log.d(TAG, "  Self-Signed: ${certResult.isSelfSigned}")
            Log.d(TAG, "  Expired: ${certResult.isExpired}")
            if (certResult.error != null) {
                Log.w(TAG, "  Error: ${certResult.error}")
            }
        }
        
        // Final verdict
        Log.d(TAG, "--- FINAL VERDICT ---")
        val mitmDetected = networkThreat.threatDetected ||
                          dnsResult.threatDetected || 
                          sslResult.threatDetected
        
        Log.d(TAG, "MITM DETECTED: $mitmDetected")
        
        if (mitmDetected) {
            Log.w(TAG, "THREAT TRIGGERED BY:")
            if (networkThreat.threatDetected) Log.w(TAG, "  - Network Anomaly")
            if (dnsResult.threatDetected) Log.w(TAG, "  - DNS Hijacking")
            if (sslResult.threatDetected) Log.w(TAG, "  - SSL/Certificate Issue")
        }
        
        Log.d(TAG, "=========================================")
    }
}