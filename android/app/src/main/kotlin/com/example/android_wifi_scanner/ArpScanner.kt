package com.example.android_wifi_scanner

import android.content.Context
import android.util.Log
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.io.IOException

class ArpScanner(private val context: Context) {
    
    companion object {
        private const val TAG = "ArpScanner"
        private const val ARP_TABLE_PATH = "/proc/net/arp"
    }
    
    // Track if we have permission to read ARP table
    private var hasArpPermission: Boolean? = null
    
    data class ArpEntry(
        val ipAddress: String,
        val hwType: String,
        val flags: String,
        val macAddress: String,
        val mask: String,
        val device: String
    )
    
    /**
     * Scans the ARP table and returns all entries
     * Returns empty list if permission denied (NOT a security threat)
     */
    fun scanArpTable(): List<ArpEntry> {
        val entries = mutableListOf<ArpEntry>()
        
        try {
            val file = File(ARP_TABLE_PATH)
            if (!file.exists()) {
                Log.w(TAG, "ARP table file not found (normal on some Android versions)")
                hasArpPermission = false
                return entries
            }
            
            val reader = BufferedReader(FileReader(file))
            
            // If we get here, we have permission!
            hasArpPermission = true
            
            reader.use { br ->
                // Skip header line
                br.readLine()
                
                // Parse each line
                var line: String?
                while (br.readLine().also { line = it } != null) {
                    line?.let {
                        val entry = parseArpLine(it)
                        if (entry != null) {
                            entries.add(entry)
                        }
                    }
                }
            }
            
            Log.d(TAG, "Found ${entries.size} ARP entries")
            
        } catch (e: SecurityException) {
            // Permission denied - this is NORMAL on Android 10+, NOT a threat
            Log.w(TAG, "Permission denied reading ARP table (normal on Android 10+)")
            hasArpPermission = false
        } catch (e: IOException) {
            // Check if it's specifically a permission error
            if (e.message?.contains("EACCES") == true || e.message?.contains("Permission denied") == true) {
                Log.w(TAG, "Permission denied reading ARP table: ${e.message}")
                hasArpPermission = false
            } else {
                Log.e(TAG, "Error reading ARP table: ${e.message}")
                hasArpPermission = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error reading ARP table: ${e.message}")
            hasArpPermission = false
        }
        
        return entries
    }
    
    /**
     * Parse a single line from ARP table
     * Format: IP address HW type Flags HW address Mask Device
     * Example: 192.168.1.1 0x1 0x2 aa:bb:cc:dd:ee:ff * wlan0
     */
    private fun parseArpLine(line: String): ArpEntry? {
        val parts = line.trim().split(Regex("\\s+"))
        
        if (parts.size < 6) {
            return null
        }
        
        // Skip entries with incomplete MAC addresses
        if (parts[3] == "00:00:00:00:00:00") {
            return null
        }
        
        return ArpEntry(
            ipAddress = parts[0],
            hwType = parts[1],
            flags = parts[2],
            macAddress = parts[3],
            mask = parts[4],
            device = parts[5]
        )
    }
    
    /**
     * Detect ARP spoofing by checking for duplicate MAC addresses
     * Returns safe result if permission denied (NOT a threat)
     */
    fun detectArpSpoofing(currentEntries: List<ArpEntry>, previousEntries: List<ArpEntry>?): ArpSpoofingResult {
        // IMPORTANT: If we don't have permission, return safe result
        // Permission denial is NOT a security threat!
        if (hasArpPermission == false) {
            Log.d(TAG, "ARP scanning unavailable - returning safe result")
            return ArpSpoofingResult(
                spoofingDetected = false,
                duplicateMacs = emptyList(),
                changedMacs = emptyList(),
                totalEntries = 0,
                permissionDenied = true
            )
        }
        
        // If no entries but we have permission, also safe (just empty network)
        if (currentEntries.isEmpty()) {
            Log.d(TAG, "No ARP entries found (empty network or just connected)")
            return ArpSpoofingResult(
                spoofingDetected = false,
                duplicateMacs = emptyList(),
                changedMacs = emptyList(),
                totalEntries = 0
            )
        }
        
        val duplicateMacs = findDuplicateMacs(currentEntries)
        val changedMacs = if (previousEntries != null) {
            findChangedMacs(currentEntries, previousEntries)
        } else {
            emptyList()
        }
        
        val isSpoofingDetected = duplicateMacs.isNotEmpty() || changedMacs.isNotEmpty()
        
        if (isSpoofingDetected) {
            Log.w(TAG, "⚠️ ARP SPOOFING DETECTED! Duplicates: ${duplicateMacs.size}, Changed: ${changedMacs.size}")
        } else {
            Log.d(TAG, "✓ No ARP spoofing detected")
        }
        
        return ArpSpoofingResult(
            spoofingDetected = isSpoofingDetected,
            duplicateMacs = duplicateMacs,
            changedMacs = changedMacs,
            totalEntries = currentEntries.size
        )
    }
    
    /**
     * Find MAC addresses that appear multiple times for different IPs
     */
    private fun findDuplicateMacs(entries: List<ArpEntry>): List<DuplicateMac> {
        val macToIps = mutableMapOf<String, MutableList<String>>()
        
        // Group IPs by MAC address
        entries.forEach { entry ->
            macToIps.getOrPut(entry.macAddress) { mutableListOf() }.add(entry.ipAddress)
        }
        
        // Find MACs with multiple IPs
        return macToIps
            .filter { it.value.size > 1 }
            .map { DuplicateMac(it.key, it.value) }
    }
    
    /**
     * Find IP addresses whose MAC address has changed since last scan
     */
    private fun findChangedMacs(currentEntries: List<ArpEntry>, previousEntries: List<ArpEntry>): List<ChangedMac> {
        val currentMap = currentEntries.associateBy { it.ipAddress }
        val previousMap = previousEntries.associateBy { it.ipAddress }
        
        val changes = mutableListOf<ChangedMac>()
        
        currentMap.forEach { (ip, currentEntry) ->
            previousMap[ip]?.let { previousEntry ->
                if (currentEntry.macAddress != previousEntry.macAddress) {
                    changes.add(
                        ChangedMac(
                            ipAddress = ip,
                            oldMac = previousEntry.macAddress,
                            newMac = currentEntry.macAddress
                        )
                    )
                    Log.w(TAG, "MAC changed for $ip: ${previousEntry.macAddress} → ${currentEntry.macAddress}")
                }
            }
        }
        
        return changes
    }
    
    /**
     * Get the gateway MAC address
     */
    fun getGatewayMac(gatewayIp: String): String? {
        val entries = scanArpTable()
        return entries.find { it.ipAddress == gatewayIp }?.macAddress
    }
    
    /**
     * Check if gateway MAC has changed (critical indicator of MITM)
     * Returns false if we don't have permission (NOT a threat)
     */
    fun isGatewayCompromised(currentGatewayMac: String?, knownGatewayMac: String?): Boolean {
        // If no permission, can't detect (but NOT a threat)
        if (hasArpPermission == false) {
            return false
        }
        
        // If we don't have both MACs, can't compare
        if (currentGatewayMac == null || knownGatewayMac == null) {
            return false
        }
        
        // If MAC changed, this is CRITICAL
        if (currentGatewayMac != knownGatewayMac) {
            Log.e(TAG, "🚨 CRITICAL: Gateway MAC changed! $knownGatewayMac → $currentGatewayMac")
            return true
        }
        
        return false
    }
    
    /**
     * Check if ARP scanning is available on this device
     */
    fun isArpScanAvailable(): Boolean {
        if (hasArpPermission == null) {
            // Try a test scan to check permission
            scanArpTable()
        }
        return hasArpPermission == true
    }
    
    data class ArpSpoofingResult(
        val spoofingDetected: Boolean,
        val duplicateMacs: List<DuplicateMac>,
        val changedMacs: List<ChangedMac>,
        val totalEntries: Int,
        val permissionDenied: Boolean = false  // NEW: Track if permission was denied
    )
    
    data class DuplicateMac(
        val macAddress: String,
        val ipAddresses: List<String>
    )
    
    data class ChangedMac(
        val ipAddress: String,
        val oldMac: String,
        val newMac: String
    )
}