package com.example.android_wifi_scanner

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.net.InetAddress

class NetworkSecurityPlugin : FlutterPlugin, MethodCallHandler {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private lateinit var hybridScanner: HybridNetworkScanner
    private lateinit var dnsChecker: DnsChecker
    private lateinit var certificateValidator: CertificateValidator
    
    private var previousDevices: List<HybridNetworkScanner.Device>? = null
    
    companion object {
        private const val CHANNEL_NAME = "wifi_security/mitm"
        private const val TAG = "NetworkSecurityPlugin"
        
        // ✅ DETECTION THRESHOLDS
        private const val DETECTION_THRESHOLD = 50  // Normal MITM detection threshold
        private const val NETWORK_DOWN_THRESHOLD = 90  // Score above this = network outage, not attack
    }
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        
        hybridScanner = HybridNetworkScanner(context)
        dnsChecker = DnsChecker(context)
        certificateValidator = CertificateValidator()
        
        Log.d(TAG, "NetworkSecurityPlugin attached with HybridNetworkScanner")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "detectMitm" -> {
                detectMitm(result)
            }
            "scanArpTable" -> {
                scanArpTable(result)
            }
            "scanNetwork" -> {
                scanNetwork(result)
            }
            "checkDnsSecurity" -> {
                checkDnsSecurity(result)
            }
            "checkSslSecurity" -> {
                checkSslSecurity(result)
            }
            "performFullScan" -> {
                performFullScan(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Main MITM detection method - combines all checks
     */
    private fun detectMitm(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "Starting comprehensive MITM detection...")
                
                // 1. Network Device Scan (Hybrid: ARP or Network Scan)
                val currentDevices = hybridScanner.scanNetwork()
                val networkThreat = hybridScanner.detectMitmThreats(currentDevices, previousDevices)
                previousDevices = currentDevices
                
                Log.d(TAG, "Network scan completed using: ${networkThreat.detectionMethod}")
                Log.d(TAG, "Found ${currentDevices.size} devices on network")
                
                // 2. DNS Security Check
                val dnsResult = dnsChecker.performDnsSecurityCheck()
                
                // 3. SSL Security Check
                val sslResult = certificateValidator.performSslSecurityCheck()
                
                // ========== DNS THREAT SCORING ==========
                var dnsThreatScore = 0
                val dnsSuccessRate = dnsChecker.getLastSuccessRate()
                
                when {
                    dnsSuccessRate == 0.0 -> {
                        dnsThreatScore = 50
                        Log.w(TAG, "🚨 CRITICAL: Complete DNS failure (0/${dnsResult.testResult.totalTests} succeeded)")
                    }
                    dnsSuccessRate < 0.5 -> {
                        dnsThreatScore = 35
                        Log.w(TAG, "⚠️ HIGH: Majority DNS queries failed (${(dnsSuccessRate * 100).toInt()}% success rate)")
                    }
                    dnsSuccessRate < 0.75 -> {
                        dnsThreatScore = 20
                        Log.w(TAG, "⚠️ MEDIUM: Some DNS queries failed (${(dnsSuccessRate * 100).toInt()}% success rate)")
                    }
                    else -> {
                        Log.d(TAG, "✓ DNS queries successful (${(dnsSuccessRate * 100).toInt()}% success rate)")
                    }
                }
                
                // Bonus points if DNS is untrusted AND queries are failing
                if (!dnsResult.dnsAreTrusted && dnsSuccessRate < 1.0) {
                    dnsThreatScore += 15
                    Log.w(TAG, "⚠️ Additional threat: Untrusted DNS + queries failing")
                }
                
                // ========== COMBINE SCORES ==========
                val networkScanScore = networkThreat.threatScore
                val combinedScore = (networkScanScore + dnsThreatScore).coerceIn(0, 100)
                
                Log.d(TAG, "📊 Threat Scoring:")
                Log.d(TAG, "   Network Scan Score: $networkScanScore/100")
                Log.d(TAG, "   DNS Threat Score: $dnsThreatScore/100")
                Log.d(TAG, "   Combined Score: $combinedScore/100")
                Log.d(TAG, "   Detection Threshold: $DETECTION_THRESHOLD")
                Log.d(TAG, "   Network Down Threshold: $NETWORK_DOWN_THRESHOLD")
                
                // ========== CHECK FOR NETWORK DOWN (NOT AN ATTACK) ==========
                val isNetworkDown = combinedScore >= NETWORK_DOWN_THRESHOLD && 
                                   dnsSuccessRate == 0.0 && 
                                   networkScanScore >= 60
                
                if (isNetworkDown) {
                    Log.w(TAG, "⚠️ Network appears DOWN (score: $combinedScore) - NOT treating as MITM attack")
                    Log.w(TAG, "   This is likely a temporary connectivity issue, not a security threat")
                }
                
                // ========== DETERMINE OVERALL THREAT ==========
                // ✅ FIXED: Exclude network down scenarios from MITM detection
                val mitmDetected = !isNetworkDown && (
                                 (combinedScore >= DETECTION_THRESHOLD && combinedScore < NETWORK_DOWN_THRESHOLD) ||
                                 networkThreat.threatDetected || 
                                 (dnsSuccessRate > 0.0 && dnsSuccessRate < 0.5 && !dnsResult.dnsAreTrusted) ||
                                 dnsResult.testResult.hijackingDetected ||
                                 sslResult.threatDetected
                )
                
                // ========== DETERMINE PRIMARY DETECTION TYPE ==========
                val detectionType = when {
                    isNetworkDown -> "networkDown"  // ✅ NEW: Network down, not attack
                    dnsResult.testResult.hijackingDetected -> "dnsHijacking"
                    networkThreat.threatDetected || (combinedScore >= DETECTION_THRESHOLD && combinedScore < NETWORK_DOWN_THRESHOLD) -> "networkAnomaly"
                    sslResult.selfSignedCount > 0 -> "sslStripping"
                    else -> "none"
                }
                
                // Debug logging
                MitmDebugLogger.logDetectionResults(
                    networkThreat = networkThreat,
                    currentDevices = currentDevices,
                    dnsResult = dnsResult,
                    sslResult = sslResult
                )
                
                // Build response
                val response = hashMapOf<String, Any>(
                    "mitmDetected" to mitmDetected,
                    "detectionType" to detectionType,
                    "timestamp" to System.currentTimeMillis(),
                    "threatScore" to combinedScore,
                    "isNetworkDown" to isNetworkDown,  // ✅ NEW: Flag for network down
                    
                    // Network Details
                    "networkAnomaly" to hashMapOf(
                        "detected" to (networkThreat.threatDetected || (combinedScore >= DETECTION_THRESHOLD && combinedScore < NETWORK_DOWN_THRESHOLD)),
                        "deviceCount" to networkThreat.deviceCount,
                        "threats" to networkThreat.threats,
                        "detectionMethod" to networkThreat.detectionMethod.name,
                        "threatScore" to networkScanScore,
                        "gatewayAnalysis" to networkThreat.gatewayAnalysis,
                        "devices" to currentDevices.map { device ->
                            mapOf(
                                "ip" to device.ipAddress,
                                "mac" to (device.macAddress ?: "unavailable"),
                                "hostname" to (device.hostname ?: "unknown"),
                                "detectionMethod" to device.detectionMethod.name
                            )
                        }
                    ),
                    
                    // Keep arpSpoofing for backward compatibility
                    "arpSpoofing" to hashMapOf(
                        "detected" to false,
                        "duplicateMacCount" to 0,
                        "changedMacCount" to 0,
                        "duplicateMacs" to emptyList<Map<String, Any>>(),
                        "changedMacs" to emptyList<Map<String, Any>>(),
                        "gatewayCompromised" to false,
                        "gatewayIp" to (hybridScanner.getGatewayIp() ?: "unknown"),
                        "gatewayMac" to "unavailable",
                        "note" to "ARP scanning replaced with hybrid network scanning"
                    ),
                    
                    // DNS Details
                    "dnsHijacking" to hashMapOf(
                        "detected" to dnsResult.threatDetected,
                        "threatLevel" to dnsResult.threatLevel,
                        "currentDnsServers" to dnsResult.currentDnsServers,
                        "dnsAreTrusted" to dnsResult.dnsAreTrusted,
                        "successRate" to dnsSuccessRate,
                        "successfulQueries" to dnsResult.testResult.successfulTests,
                        "totalQueries" to dnsResult.testResult.totalTests,
                        "dnsThreatScore" to dnsThreatScore,
                        "suspiciousResolutions" to dnsResult.testResult.suspiciousResolutions.map {
                            mapOf(
                                "domain" to it.domain,
                                "resolvedIps" to it.resolvedIps,
                                "error" to (it.error ?: "")
                            )
                        }
                    ),
                    
                    // SSL Details
                    "sslStripping" to hashMapOf(
                        "detected" to sslResult.threatDetected,
                        "threatLevel" to sslResult.threatLevel,
                        "selfSignedCount" to sslResult.selfSignedCount,
                        "invalidCertCount" to sslResult.invalidCertCount,
                        "strippingDetected" to sslResult.strippingResult.strippingDetected,
                        "suspiciousConnections" to sslResult.strippingResult.suspiciousConnections
                    ),
                    
                    // Reason
                    "reason" to buildReasonString(
                        networkThreat = networkThreat,
                        dnsResult = dnsResult,
                        sslResult = sslResult,
                        dnsSuccessRate = dnsSuccessRate,
                        combinedScore = combinedScore,
                        isNetworkDown = isNetworkDown
                    )
                )
                
                withContext(Dispatchers.Main) {
                    result.success(response)
                    if (isNetworkDown) {
                        Log.d(TAG, "MITM detection completed: ⚠️ Network DOWN (Score: $combinedScore) - Not an attack")
                    } else {
                        Log.d(TAG, "MITM detection completed: ${if (mitmDetected) "⚠️ THREAT DETECTED (Score: $combinedScore)" else "✅ No threats"}")
                    }
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Error during MITM detection: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    result.error("DETECTION_ERROR", e.message, null)
                }
            }
        }
    }
    
    /**
     * Build human-readable reason string
     */
    private fun buildReasonString(
        networkThreat: HybridNetworkScanner.MitmThreatResult,
        dnsResult: DnsChecker.DnsSecurityResult,
        sslResult: CertificateValidator.SslSecurityResult,
        dnsSuccessRate: Double,
        combinedScore: Int,
        isNetworkDown: Boolean
    ): String {
        // ✅ NEW: Network down has its own message
        if (isNetworkDown) {
            return "Network appears to be down or temporarily unavailable. This is NOT a security threat - likely WiFi power saving or temporary connectivity issue. (Score: $combinedScore/100)"
        }
        
        val reasons = mutableListOf<String>()
        
        // DNS FAILURE REASONS (PRIORITY)
        when {
            dnsSuccessRate == 0.0 && !isNetworkDown -> {
                reasons.add("Complete DNS failure - all queries blocked/hijacked (${dnsResult.testResult.successfulTests}/${dnsResult.testResult.totalTests} successful)")
            }
            dnsSuccessRate < 0.5 -> {
                reasons.add("Majority of DNS queries failed (${dnsResult.testResult.successfulTests}/${dnsResult.testResult.totalTests} successful)")
            }
            dnsSuccessRate < 0.75 -> {
                reasons.add("Some DNS queries failed (${dnsResult.testResult.successfulTests}/${dnsResult.testResult.totalTests} successful)")
            }
        }
        
        // Network threats
        if (networkThreat.threatDetected) {
            reasons.addAll(networkThreat.threats)
        }
        
        // DNS hijacking patterns
        if (dnsResult.testResult.hijackingDetected) {
            reasons.add("DNS resolution showing suspicious patterns")
        }
        if (!dnsResult.dnsAreTrusted && dnsSuccessRate < 1.0 && dnsSuccessRate > 0.0) {
            reasons.add("Untrusted DNS servers with failing queries")
        }
        
        // SSL threats
        if (sslResult.selfSignedCount > 0) {
            reasons.add("${sslResult.selfSignedCount} self-signed certificate(s) detected")
        }
        if (sslResult.strippingResult.strippingDetected) {
            reasons.add("Possible SSL stripping attack")
        }
        
        return if (reasons.isEmpty()) {
            "No threats detected. Network appears secure. (Score: $combinedScore/100)"
        } else {
            reasons.joinToString("; ")
        }
    }
    
    /**
     * Scan ARP table only (backward compatibility)
     */
    private fun scanArpTable(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val devices = hybridScanner.scanNetwork()
                val response = devices.map { device ->
                    mapOf(
                        "ip" to device.ipAddress,
                        "mac" to (device.macAddress ?: "unavailable"),
                        "device" to (device.hostname ?: "unknown")
                    )
                }
                
                withContext(Dispatchers.Main) {
                    result.success(response)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
        }
    }
    
    /**
     * Scan network devices using hybrid scanner
     */
    private fun scanNetwork(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val devices = hybridScanner.scanNetwork()
                val response = devices.map { device ->
                    mapOf(
                        "ip" to device.ipAddress,
                        "mac" to (device.macAddress ?: "unavailable"),
                        "hostname" to (device.hostname ?: "unknown"),
                        "detectionMethod" to device.detectionMethod.name
                    )
                }
                
                withContext(Dispatchers.Main) {
                    result.success(response)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }
        }
    }
    
    /**
     * Check DNS security only
     */
    private fun checkDnsSecurity(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val dnsResult = dnsChecker.performDnsSecurityCheck()
                
                val response = hashMapOf(
                    "threatDetected" to dnsResult.threatDetected,
                    "threatLevel" to dnsResult.threatLevel,
                    "currentDnsServers" to dnsResult.currentDnsServers,
                    "dnsAreTrusted" to dnsResult.dnsAreTrusted
                )
                
                withContext(Dispatchers.Main) {
                    result.success(response)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DNS_CHECK_ERROR", e.message, null)
                }
            }
        }
    }
    
    /**
     * Check SSL security only
     */
    private fun checkSslSecurity(result: Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val sslResult = certificateValidator.performSslSecurityCheck()
                
                val response = hashMapOf(
                    "threatDetected" to sslResult.threatDetected,
                    "threatLevel" to sslResult.threatLevel,
                    "selfSignedCount" to sslResult.selfSignedCount,
                    "invalidCertCount" to sslResult.invalidCertCount
                )
                
                withContext(Dispatchers.Main) {
                    result.success(response)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("SSL_CHECK_ERROR", e.message, null)
                }
            }
        }
    }
    
    /**
     * Perform full security scan
     */
    private fun performFullScan(result: Result) {
        detectMitm(result)
    }
}