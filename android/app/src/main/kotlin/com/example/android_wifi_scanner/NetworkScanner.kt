package com.example.android_wifi_scanner

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.*
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Alternative to ARP scanning that works on Android 10+
 * Uses active network scanning instead of reading /proc/net/arp
 */
class NetworkScanner(private val context: Context) {
    
    companion object {
        private const val TAG = "NetworkScanner"
        private const val PING_TIMEOUT_MS = 1000
        private const val PORT_SCAN_TIMEOUT_MS = 500
    }
    
    data class NetworkDevice(
        val ipAddress: String,
        val isReachable: Boolean,
        val hostname: String?,
        val responseTime: Long
    )
    
    /**
     * Scan the local network for active devices
     * This works on all Android versions!
     */
    suspend fun scanNetwork(): List<NetworkDevice> = withContext(Dispatchers.IO) {
        val devices = mutableListOf<NetworkDevice>()
        val subnet = getSubnet()
        
        if (subnet == null) {
            Log.e(TAG, "Could not determine network subnet")
            return@withContext devices
        }
        
        Log.d(TAG, "Scanning network: $subnet.0/24")
        
        // Scan all IPs in parallel using coroutines
        val jobs = (1..254).map { lastOctet ->
            async {
                val ip = "$subnet.$lastOctet"
                scanDevice(ip)
            }
        }
        
        // Wait for all scans to complete
        jobs.awaitAll().filterNotNull().let { devices.addAll(it) }
        
        Log.d(TAG, "Network scan completed: ${devices.size} devices found")
        devices
    }
    
    /**
     * Scan a single device
     */
    private suspend fun scanDevice(ipAddress: String): NetworkDevice? = withContext(Dispatchers.IO) {
        try {
            val startTime = System.currentTimeMillis()
            val inetAddress = InetAddress.getByName(ipAddress)
            
            // Try to reach the device (ping)
            val isReachable = inetAddress.isReachable(PING_TIMEOUT_MS)
            
            if (isReachable) {
                val responseTime = System.currentTimeMillis() - startTime
                val hostname = try {
                    inetAddress.canonicalHostName
                } catch (e: Exception) {
                    null
                }
                
                Log.d(TAG, "Device found: $ipAddress (${hostname ?: "unknown"}) - ${responseTime}ms")
                
                return@withContext NetworkDevice(
                    ipAddress = ipAddress,
                    isReachable = true,
                    hostname = hostname,
                    responseTime = responseTime
                )
            }
        } catch (e: Exception) {
            // Device not reachable, skip
        }
        
        null
    }
    
    /**
     * Get the network subnet (e.g., "192.168.1")
     */
    private fun getSubnet(): String? {
        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcpInfo = wifiManager.dhcpInfo
            val ip = dhcpInfo.ipAddress
            
            // Convert to dotted decimal notation
            val subnet = String.format(
                "%d.%d.%d",
                ip and 0xff,
                ip shr 8 and 0xff,
                ip shr 16 and 0xff
            )
            
            return subnet
        } catch (e: Exception) {
            Log.e(TAG, "Error getting subnet: ${e.message}")
            return null
        }
    }
    
    /**
     * Get gateway IP
     */
    fun getGatewayIp(): String? {
        return try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcpInfo = wifiManager.dhcpInfo
            val gateway = dhcpInfo.gateway
            
            String.format(
                "%d.%d.%d.%d",
                gateway and 0xff,
                gateway shr 8 and 0xff,
                gateway shr 16 and 0xff,
                gateway shr 24 and 0xff
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error getting gateway IP: ${e.message}")
            null
        }
    }
    
    /**
     * Detect suspicious network behavior
     * Looks for devices impersonating the gateway
     */
    fun detectSuspiciousDevices(
        devices: List<NetworkDevice>,
        previousDevices: List<NetworkDevice>?
    ): SuspiciousDeviceResult {
        val gatewayIp = getGatewayIp()
        val suspiciousDevices = mutableListOf<String>()
        val newDevices = mutableListOf<NetworkDevice>()
        
        // Detect new devices
        if (previousDevices != null) {
            val previousIps = previousDevices.map { it.ipAddress }.toSet()
            devices.forEach { device ->
                if (device.ipAddress !in previousIps) {
                    newDevices.add(device)
                    Log.d(TAG, "New device detected: ${device.ipAddress}")
                }
            }
        }
        
        // Check for unusual network patterns
        // Example: Multiple devices responding very quickly (possible MITM)
        val fastResponders = devices.filter { it.responseTime < 5 }
        if (fastResponders.size > 1 && gatewayIp != null) {
            fastResponders.forEach { device ->
                if (device.ipAddress != gatewayIp) {
                    suspiciousDevices.add(device.ipAddress)
                    Log.w(TAG, "Suspicious fast response from: ${device.ipAddress}")
                }
            }
        }
        
        val threatDetected = suspiciousDevices.isNotEmpty()
        
        return SuspiciousDeviceResult(
            threatDetected = threatDetected,
            suspiciousDevices = suspiciousDevices,
            newDevices = newDevices,
            totalDevices = devices.size,
            gatewayIp = gatewayIp
        )
    }
    
    data class SuspiciousDeviceResult(
        val threatDetected: Boolean,
        val suspiciousDevices: List<String>,
        val newDevices: List<NetworkDevice>,
        val totalDevices: Int,
        val gatewayIp: String?
    )
}