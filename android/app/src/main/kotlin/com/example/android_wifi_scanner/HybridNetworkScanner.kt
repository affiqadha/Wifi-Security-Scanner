package com.example.android_wifi_scanner

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*

/**
 * Hybrid scanner that combines ARP scanning and active network scanning
 * - Tries ARP table first (fast, accurate)
 * - Falls back to network scanning if ARP unavailable (Android 10+)
 * 
 * UPDATED: Compatible with improved EnhancedNetworkScanner
 */
class HybridNetworkScanner(private val context: Context) {
    
    companion object {
        private const val TAG = "HybridNetworkScanner"
    }
    
    private val arpScanner = ArpScanner(context)
    private val networkScanner = NetworkScanner(context)
    private val enhancedScanner = EnhancedNetworkScanner(context)

    data class Device(
        val ipAddress: String,
        val macAddress: String?,  // Null if MAC unavailable
        val hostname: String?,
        val detectionMethod: DetectionMethod,
    )
    
    enum class DetectionMethod {
        ARP_TABLE,      // From /proc/net/arp (fast, has MAC)
        NETWORK_SCAN    // From active ping (slower, no MAC)
    }
    
    /**
     * Scan the network using best available method
     */
    suspend fun scanNetwork(): List<Device> = withContext(Dispatchers.IO) {
        Log.d(TAG, "Starting hybrid network scan...")
        
        // Try ARP table first (fast and has MAC addresses)
        val arpDevices = tryArpScan()
        
        if (arpDevices.isNotEmpty()) {
            Log.d(TAG, "✓ ARP scan successful: ${arpDevices.size} devices")
            return@withContext arpDevices
        }
        
        // Fallback to active network scan
        Log.d(TAG, "→ ARP unavailable, using network scan...")
        val networkDevices = tryNetworkScan()
        
        Log.d(TAG, "✓ Network scan completed: ${networkDevices.size} devices")
        networkDevices
    }
    
    /**
     * Detect MITM threats using all available methods
     */
    suspend fun detectMitmThreats(
        currentDevices: List<Device>,
        previousDevices: List<Device>?
    ): MitmThreatResult = withContext(Dispatchers.IO) {

        // Get enhanced analysis
        val enhancedAnalysis = enhancedScanner.performComprehensiveScan()

        val threats = mutableListOf<String>()
        var threatScore = enhancedAnalysis.threatScore  // Use enhanced threat score

        // Add threats from enhanced analysis
        threats.addAll(enhancedAnalysis.threats)

        // If we have MAC addresses (from ARP), check for duplicates
        val devicesWithMac = currentDevices.filter { it.macAddress != null }
        if (devicesWithMac.isNotEmpty()) {
            val duplicateMacs = findDuplicateMacs(devicesWithMac)
            if (duplicateMacs.isNotEmpty()) {
                threats.add("Duplicate MAC addresses detected (ARP spoofing)")
                threatScore += 40  // ARP spoofing is critical
                Log.w(TAG, "⚠️ ARP Spoofing detected: ${duplicateMacs.size} duplicate MACs")
            }
        }

        // Check for sudden new devices
        if (previousDevices != null) {
            val previousIps = previousDevices.map { it.ipAddress }.toSet()
            val newDevices = currentDevices.filter { it.ipAddress !in previousIps }

            if (newDevices.size > 3) {
                threats.add("Unusual number of new devices (${newDevices.size})")
                threatScore += 15
                Log.w(TAG, "⚠️ Suspicious: ${newDevices.size} new devices appeared")
            }
        }

        MitmThreatResult(
            threatDetected = threatScore >= 40,  // Adjust threshold as needed
            threats = threats,
            deviceCount = currentDevices.size,
            detectionMethod = if (devicesWithMac.isNotEmpty())
                DetectionMethod.ARP_TABLE else DetectionMethod.NETWORK_SCAN,
            threatScore = threatScore,
            gatewayAnalysis = enhancedAnalysis.gatewayAnalysis?.let {
                mapOf(
                    "avgLatency" to it.avgLatency,
                    "maxLatency" to it.maxLatency,
                    "stdDev" to it.stdDev,  // FIXED: Changed from 'variance' to 'stdDev'
                    "suspicious" to it.suspiciousLatency,
                    "highVariance" to it.highVariance,
                    "completelyUnreachable" to it.completelyUnreachable,
                    "partialFailure" to it.partialFailure  // NEW field
                )
            }
        )
    }

    /**
     * Try to scan using ARP table
     */
    private fun tryArpScan(): List<Device> {
        return try {
            val arpEntries = arpScanner.scanArpTable()
            
            // Check if ARP is available
            if (arpEntries.isEmpty()) {
                val testResult = arpScanner.detectArpSpoofing(arpEntries, null)
                if (testResult.permissionDenied) {
                    // Permission denied, return empty to trigger fallback
                    return emptyList()
                }
            }
            
            arpEntries.map { entry ->
                Device(
                    ipAddress = entry.ipAddress,
                    macAddress = entry.macAddress,
                    hostname = null,  // Could do reverse DNS lookup here
                    detectionMethod = DetectionMethod.ARP_TABLE
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "ARP scan failed: ${e.message}")
            emptyList()
        }
    }
    
    /**
     * Scan using active network probing
     */
    private suspend fun tryNetworkScan(): List<Device> {
        return try {
            val networkDevices = networkScanner.scanNetwork()
            
            networkDevices.map { device ->
                Device(
                    ipAddress = device.ipAddress,
                    macAddress = null,  // Can't get MAC without ARP
                    hostname = device.hostname,
                    detectionMethod = DetectionMethod.NETWORK_SCAN
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network scan failed: ${e.message}")
            emptyList()
        }
    }
    
    
    /**
     * Find duplicate MAC addresses
     */
    private fun findDuplicateMacs(devices: List<Device>): List<DuplicateMac> {
        val macToIps = mutableMapOf<String, MutableList<String>>()
        
        devices.forEach { device ->
            device.macAddress?.let { mac ->
                macToIps.getOrPut(mac) { mutableListOf() }.add(device.ipAddress)
            }
        }
        
        return macToIps
            .filter { it.value.size > 1 }
            .map { DuplicateMac(it.key, it.value) }
    }
    
    /**
     * Get gateway IP address (delegates to NetworkScanner)
     */
    fun getGatewayIp(): String? {
        return networkScanner.getGatewayIp()
    }
    
    data class MitmThreatResult(
        val threatDetected: Boolean,
        val threats: List<String>,
        val deviceCount: Int,
        val detectionMethod: DetectionMethod,
        val threatScore: Int = 0,
        val gatewayAnalysis: Map<String, Any>? = null
    )
    
    data class DuplicateMac(
        val macAddress: String,
        val ipAddresses: List<String>
    )
}