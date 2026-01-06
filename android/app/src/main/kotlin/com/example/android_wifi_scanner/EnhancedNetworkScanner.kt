package com.example.android_wifi_scanner

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.*
import java.io.IOException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import kotlin.math.pow
import kotlin.math.sqrt
import kotlin.system.measureTimeMillis

/**
 * Enhanced NetworkScanner with MITM detection capabilities
 * Includes latency-based detection for ARP spoofing
 * 
 * IMPROVED: Better detection of ARP-only attacks (no DNS/SSL manipulation)
 */
class EnhancedNetworkScanner(private val context: Context) {
    
    companion object {
        private const val TAG = "EnhancedNetworkScanner"
        private const val PING_TIMEOUT = 1000
        
        // ADJUSTED THRESHOLDS for better ARP spoofing detection
        private const val SUSPICIOUS_LATENCY_MS = 100.0  // Lowered from 200 (ARP spoofing adds 50-150ms)
        private const val HIGH_LATENCY_MS = 150.0  // NEW: Threshold for very high latency
        private const val LATENCY_STD_DEV_THRESHOLD = 40.0  // NEW: Standard deviation threshold
    }
    
    private val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    
    data class NetworkDevice(
        val ipAddress: String,
        val hostname: String?,
        val isReachable: Boolean,
        val latency: Double?  // in milliseconds
    )
    
    data class GatewayAnalysis(
        val gatewayIp: String,
        val avgLatency: Double,
        val maxLatency: Double,
        val minLatency: Double,
        val stdDev: Double,  // Standard deviation
        val suspiciousLatency: Boolean,
        val highVariance: Boolean,
        val completelyUnreachable: Boolean = false,
        val partialFailure: Boolean = false  // NEW: Some pings fail
    )
    
    data class NetworkThreatAnalysis(
        val threatDetected: Boolean,
        val threatScore: Int,  // 0-100
        val threats: List<String>,
        val gatewayAnalysis: GatewayAnalysis?,
        val deviceCount: Int
    )
    
    /**
     * Comprehensive network scan with MITM detection
     * IMPROVED: Better scoring for ARP spoofing scenarios
     */
    suspend fun performComprehensiveScan(): NetworkThreatAnalysis = withContext(Dispatchers.IO) {
        val threats = mutableListOf<String>()
        var threatScore = 0
        
        // 1. Scan network for devices
        val devices = scanNetwork()
        Log.d(TAG, "Found ${devices.size} devices on network")
        
        // 2. Analyze gateway behavior (critical for MITM detection)
        val gatewayAnalysis = analyzeGateway()
        
        if (gatewayAnalysis != null) {
            // CRITICAL: Gateway completely unreachable
            if (gatewayAnalysis.completelyUnreachable) {
                threats.add("Gateway completely unreachable")
                threatScore += 60  
                Log.e(TAG, "🚨 CRITICAL: Gateway is completely unreachable - likely MITM!")
            }
            // NEW: Partial failure (some pings work, some don't)
            else if (gatewayAnalysis.partialFailure) {
                threats.add("Intermittent gateway connectivity")
                threatScore += 40
                Log.w(TAG, "⚠️ Gateway partially unreachable - possible MITM")
            }
            // High latency indicates possible MITM
            else if (gatewayAnalysis.avgLatency > HIGH_LATENCY_MS) {
                threats.add("Very high gateway latency (${gatewayAnalysis.avgLatency.toInt()}ms)")
                threatScore += 35  // Increased from 30
                Log.w(TAG, "⚠️ Very high gateway latency: ${gatewayAnalysis.avgLatency}ms")
            }
            else if (gatewayAnalysis.suspiciousLatency) {
                threats.add("High gateway latency (${gatewayAnalysis.avgLatency.toInt()}ms)")
                threatScore += 25  // Increased from 20
                Log.w(TAG, "⚠️ Suspicious gateway latency: ${gatewayAnalysis.avgLatency}ms")
            }
            
            // High variance indicates possible packet manipulation
            if (gatewayAnalysis.highVariance) {
                threats.add("Inconsistent network performance")
                threatScore += 20  // Increased from 10
                Log.w(TAG, "⚠️ High latency variance detected (StdDev: ${gatewayAnalysis.stdDev.toInt()}ms)")
            }
            
            // Combined indicators are more serious
            if (gatewayAnalysis.suspiciousLatency && gatewayAnalysis.highVariance) {
                threats.add("Gateway behavior consistent with MITM attack")
                threatScore += 15  // Additional points for combination
            }
        } else {
            // Gateway analysis completely failed
            threats.add("Unable to analyze gateway")
            threatScore += 30
        }
        
        // Check for routing anomalies
        if (detectRoutingAnomaly()) {
            threats.add("Routing anomaly detected")
            threatScore += 20
        }
        
        // Cap at 100
        threatScore = threatScore.coerceIn(0, 100)
        
        Log.d(TAG, "🎯 Final threat score: $threatScore/100")
        if (threats.isNotEmpty()) {
            Log.d(TAG, "📊 ${if (threatScore >= 50) "High variance - network congestion detected" else "Network appears normal"}")
        }
        
        NetworkThreatAnalysis(
            threatDetected = threatScore >= 50,
            threatScore = threatScore,
            threats = threats,
            gatewayAnalysis = gatewayAnalysis,
            deviceCount = devices.size
        )
    }
    
    private suspend fun scanNetwork(): List<NetworkDevice> = withContext(Dispatchers.IO) {
        val devices = mutableListOf<NetworkDevice>()
        val gatewayIp = getGatewayIp() ?: return@withContext devices
        
        val subnet = gatewayIp.substringBeforeLast(".")
        Log.d(TAG, "Scanning subnet: $subnet")
        
        val jobs = (1..254).map { i ->
            async {
                val ip = "$subnet.$i"
                try {
                    val addr = InetAddress.getByName(ip)
                    if (addr.isReachable(500)) {
                        val hostname = try { addr.hostName } catch (e: Exception) { null }
                        NetworkDevice(ip, hostname, true, null)
                    } else null
                } catch (e: Exception) {
                    null
                }
            }
        }
        
        devices.addAll(jobs.awaitAll().filterNotNull())
        Log.d(TAG, "Network scan completed: ${devices.size} devices found")
        devices
    }
    
    private fun getGatewayIp(): String? {
        try {
            val dhcpInfo = wifiManager.dhcpInfo
            val gateway = dhcpInfo.gateway
            
            return String.format(
                "%d.%d.%d.%d",
                (gateway and 0xff),
                (gateway shr 8 and 0xff),
                (gateway shr 16 and 0xff),
                (gateway shr 24 and 0xff)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get gateway IP: ${e.message}")
            return null
        }
    }
    
    /**
     * Analyze gateway behavior for MITM indicators
     * IMPROVED: Better ping failure handling and statistics
     */
    private suspend fun analyzeGateway(): GatewayAnalysis? = withContext(Dispatchers.IO) {
        val gatewayIp = getGatewayIp() ?: return@withContext null
        
        Log.d(TAG, "Analyzing gateway: $gatewayIp")
        
        // Warm-up phase: Wake up WiFi chip with 5 pings
        Log.d(TAG, "Performing warmup pings to wake WiFi chip...")
        var chipAwake = false
        for (i in 1..5) {
            try {
                val latency = measureLatency(gatewayIp)
                Log.d(TAG, "Gateway warmup ping $i: ${latency}ms")
                if (latency < 2000) {  // Reasonable latency
                    chipAwake = true
                    Log.d(TAG, "✅ WiFi chip awake after $i ping(s)")
                    break
                }
            } catch (e: Exception) {
                Log.d(TAG, "Gateway warmup ping $i failed (WiFi chip still sleeping): ${e.message}")
            }
        }
        
        if (!chipAwake) {
            Log.w(TAG, "! WiFi chip may still be in power-saving mode, continuing anyway...")
        }
        
        // Actual measurement phase: 15 pings
        val pingResults = (1..15).mapNotNull { i ->
            try {
                val latency = measureLatency(gatewayIp)
                Log.d(TAG, "Gateway ping $i: ${latency}ms")
                latency
            } catch (e: Exception) {
                Log.w(TAG, "Gateway ping $i failed: ${e.message}")
                null
            }
        }
        
        // Calculate success rate
        val successRate = pingResults.size / 15.0
        val partialFailure = successRate < 0.8 && successRate > 0  // 20-100% failure
        
        if (successRate < 0.5) {
            Log.w(TAG, "! Only ${pingResults.size} pings collected, using all data")
        }
        
        // CRITICAL: Complete gateway failure
        if (pingResults.isEmpty()) {
            Log.w(TAG, "🚨 All gateway pings failed - CRITICAL MITM indicator!")
            return@withContext GatewayAnalysis(
                gatewayIp = gatewayIp,
                avgLatency = 0.0,
                maxLatency = 0.0,
                minLatency = 0.0,
                stdDev = 0.0,
                suspiciousLatency = false,
                highVariance = false,
                completelyUnreachable = true,
                partialFailure = false
            )
        }
        
        // Filter outliers (values > 2 standard deviations from mean)
        val mean = pingResults.average()
        val stdDev = sqrt(pingResults.map { (it - mean).pow(2) }.average())
        val filtered = pingResults.filter { kotlin.math.abs(it - mean) <= 2 * stdDev }
        
        if (filtered.size < pingResults.size) {
            Log.d(TAG, "Filtered ${pingResults.size - filtered.size} outliers from latency data")
        }
        
        // Use filtered data for analysis
        val finalResults = if (filtered.size >= 3) filtered else pingResults
        
        val avgLatency = finalResults.average()
        val maxLatency = finalResults.maxOrNull() ?: 0.0
        val minLatency = finalResults.minOrNull() ?: 0.0
        
        // Calculate standard deviation for variance detection
        val finalStdDev = sqrt(finalResults.map { (it - avgLatency).pow(2) }.average())
        
        // MITM attacks typically:
        // 1. Add 50-150ms of overhead (attacker machine processing)
        // 2. Show high variance (inconsistent forwarding times)
        val suspiciousLatency = avgLatency > SUSPICIOUS_LATENCY_MS
        val highVariance = finalStdDev > LATENCY_STD_DEV_THRESHOLD
        
        Log.d(TAG, "Gateway analysis - Avg: ${avgLatency}ms, StdDev: ${finalStdDev}ms, Max: ${maxLatency}ms")
        
        if (highVariance) {
            Log.w(TAG, "! High latency variance detected")
        }
        
        GatewayAnalysis(
            gatewayIp = gatewayIp,
            avgLatency = avgLatency,
            maxLatency = maxLatency,
            minLatency = minLatency,
            stdDev = finalStdDev,
            suspiciousLatency = suspiciousLatency,
            highVariance = highVariance,
            completelyUnreachable = false,
            partialFailure = partialFailure
        )
    }
    
    /**
     * Measure latency to a host using TCP SYN (more reliable than ICMP)
     */
    private fun measureLatency(ipAddress: String, port: Int = 80): Double {
        return measureTimeMillis {
            try {
                val socket = Socket()
                socket.connect(InetSocketAddress(ipAddress, port), PING_TIMEOUT)
                socket.close()
            } catch (e: IOException) {
                // Try port 443 if 80 fails
                if (port == 80) {
                    val socket = Socket()
                    socket.connect(InetSocketAddress(ipAddress, 443), PING_TIMEOUT)
                    socket.close()
                } else {
                    throw e
                }
            }
        }.toDouble()
    }
    
    /**
     * Detect routing anomalies using traceroute-like approach
     */
    private suspend fun detectRoutingAnomaly(): Boolean = withContext(Dispatchers.IO) {
        try {
            val gatewayIp = getGatewayIp() ?: return@withContext false
            val testHost = "8.8.8.8"  // Google DNS
            
            // Ping gateway
            val gatewayLatency = measureLatency(gatewayIp)
            
            // Ping external host
            val externalLatency = measureLatency(testHost)
            
            // In MITM, gateway latency might be HIGHER than external
            // (because attacker machine is slow)
            if (gatewayLatency > externalLatency * 0.8) {
                Log.w(TAG, "⚠️ Gateway latency ($gatewayLatency) unusually high vs external ($externalLatency)")
                return@withContext true
            }
            
            return@withContext false
        } catch (e: Exception) {
            Log.e(TAG, "Error in routing anomaly detection: ${e.message}")
            return@withContext false
        }
    }
}