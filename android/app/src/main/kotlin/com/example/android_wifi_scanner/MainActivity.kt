package com.example.android_wifi_scanner

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.ScanResult
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.widget.Toast
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import com.example.android_wifi_scanner.VpnDetectionPlugin


class MainActivity : FlutterActivity() {
    private val WIFI_SCAN_CHANNEL = "wifi_security/network_info"
    private val PERMISSIONS_REQUEST_CODE = 123

    private lateinit var wifiManager: WifiManager
    private lateinit var connectivityManager: ConnectivityManager
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register VPN Detection Plugin
        flutterEngine.plugins.add(VpnDetectionPlugin())
        
        // Register Network Security Plugin
        flutterEngine.plugins.add(NetworkSecurityPlugin())
        
        Log.d("MainActivity", "✅ All plugins registered: VPN Detection, Network Security")

        wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_SCAN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWifiNetworks" -> {
                        if (!hasWifiPermissions()) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION),
                                PERMISSIONS_REQUEST_CODE
                            )
                            pendingResult = result
                        } else {
                            startWifiScan(result)
                        }
                    }
                    
                    "connectToNetwork" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password")
                        if (ssid != null) {
                            connectToNetwork(ssid, password, result)
                        } else {
                            result.error("INVALID_ARGS", "SSID is required", null)
                        }
                    }
                    
                    "disconnectFromNetwork" -> {
                        disconnectFromNetwork(result)
                    }
                    
                    "getCurrentNetwork" -> {
                        getCurrentNetwork(result)
                    }

                    "getCurrentNetworkInfo" -> {
                        getCurrentNetworkInfo(result)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasWifiPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private val wifiScanReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            unregisterReceiver(this)
            val results = wifiManager.scanResults
            val networkList = results.mapNotNull { scanResult ->
                if (scanResult.SSID.isEmpty()) return@mapNotNull null

                mapOf(
                    "ssid" to scanResult.SSID,
                    "bssid" to scanResult.BSSID,
                    "signalLevel" to scanResult.level,
                    "frequency" to scanResult.frequency,
                    "isSecure" to !scanResult.capabilities.contains("OPEN"),
                    "capabilities" to scanResult.capabilities
                )
            }

            try {
                pendingResult?.success(networkList)
            } catch (e: IllegalStateException) {
                Log.w("MainActivity", "Reply already submitted.")
            }
            pendingResult = null
        }
    }

    private fun startWifiScan(result: MethodChannel.Result) {
        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val isLocationEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                || locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        if (!isLocationEnabled) {
            result.error("LOCATION_DISABLED", "Location services are disabled", null)
            return
        }

        val success = wifiManager.startScan()
        if (!success) {
            result.error("SCAN_FAILED", "Wi-Fi scan failed to start", null)
            return
        }

        pendingResult = result
        registerReceiver(wifiScanReceiver, IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION))
    }

    private fun connectToNetwork(ssid: String, password: String?, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ (API 29+)
                val specifier = WifiNetworkSpecifier.Builder()
                    .setSsid(ssid)
                    .apply {
                        if (!password.isNullOrEmpty()) {
                            setWpa2Passphrase(password)
                        }
                    }
                    .build()

                val request = NetworkRequest.Builder()
                    .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                    .setNetworkSpecifier(specifier)
                    .build()

                val networkCallback = object : ConnectivityManager.NetworkCallback() {
                    override fun onAvailable(network: Network) {
                        super.onAvailable(network)
                        connectivityManager.bindProcessToNetwork(network)
                        result.success(true)
                    }

                    override fun onUnavailable() {
                        super.onUnavailable()
                        result.success(false)
                    }
                }

                connectivityManager.requestNetwork(request, networkCallback)
            } else {
                // Android 9 and below
                @Suppress("DEPRECATION")
                val wifiConfig = WifiConfiguration().apply {
                    SSID = "\"$ssid\""
                    if (password.isNullOrEmpty()) {
                        allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                    } else {
                        preSharedKey = "\"$password\""
                    }
                }

                @Suppress("DEPRECATION")
                val networkId = wifiManager.addNetwork(wifiConfig)
                if (networkId != -1) {
                    @Suppress("DEPRECATION")
                    wifiManager.disconnect()
                    @Suppress("DEPRECATION")
                    val enabled = wifiManager.enableNetwork(networkId, true)
                    @Suppress("DEPRECATION")
                    wifiManager.reconnect()
                    result.success(enabled)
                } else {
                    result.success(false)
                }
            }
        } catch (e: Exception) {
            result.error("CONNECTION_FAILED", e.message, null)
        }
    }

    private fun disconnectFromNetwork(result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: Disable WiFi temporarily to force disconnect
                if (wifiManager.isWifiEnabled) {
                    @Suppress("DEPRECATION")
                    wifiManager.isWifiEnabled = false
                    
                    // Re-enable WiFi after 1 second
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        @Suppress("DEPRECATION")
                        wifiManager.isWifiEnabled = true
                    }, 1000)
                }
                result.success(true)
            } else {
                // Android 9 and below
                @Suppress("DEPRECATION")
                val disconnected = wifiManager.disconnect()
                result.success(disconnected)
            }
        } catch (e: Exception) {
            result.error("DISCONNECT_FAILED", e.message, null)
        }
    }

    private fun getCurrentNetwork(result: MethodChannel.Result) {
        try {
            val wifiInfo = wifiManager.connectionInfo
            val ssid = wifiInfo?.ssid?.removeSurrounding("\"")
            
            if (ssid.isNullOrEmpty() || ssid == "<unknown ssid>") {
                result.success(null)
            } else {
                result.success(ssid)
            }
        } catch (e: Exception) {
            result.error("GET_NETWORK_FAILED", e.message, null)
        }
    }

    private fun getCurrentNetworkInfo(result: MethodChannel.Result) {
        try {
            Log.d("MainActivity", "🔍 getCurrentNetworkInfo called")
            
            val wifiInfo = wifiManager.connectionInfo
            val dhcpInfo = wifiManager.dhcpInfo
            
            val ssid = wifiInfo?.ssid?.removeSurrounding("\"")
            
            if (ssid.isNullOrEmpty() || ssid == "<unknown ssid>") {
                Log.d("MainActivity", "⚠️ No network connected")
                result.success(mapOf<String, Any>())
                return
            }
            
            Log.d("MainActivity", "📡 Getting info for: $ssid")
            
            // Get BSSID (MAC address of access point)
            val bssid = wifiInfo.bssid ?: ""
            
            // Get signal strength
            val rssi = wifiInfo.rssi
            val signalLevel = WifiManager.calculateSignalLevel(rssi, 5)
            
            // Get IP addresses
            val ipAddress = intToIp(dhcpInfo.ipAddress)
            val gatewayIp = intToIp(dhcpInfo.gateway)
            val netmask = intToIp(dhcpInfo.netmask)
            val dns1 = intToIp(dhcpInfo.dns1)
            val dns2 = intToIp(dhcpInfo.dns2)
            
            // Get encryption type from scan results
            var encryption = "Unknown"
            var frequency = 0
            
            try {
                val scanResults = wifiManager.scanResults
                val matchingNetwork = scanResults.find { it.SSID == ssid }
                
                if (matchingNetwork != null) {
                    encryption = when {
                        matchingNetwork.capabilities.contains("WPA3") -> "WPA3"
                        matchingNetwork.capabilities.contains("WPA2") -> "WPA2"
                        matchingNetwork.capabilities.contains("WPA") -> "WPA"
                        matchingNetwork.capabilities.contains("WEP") -> "WEP"
                        else -> "Open"
                    }
                    frequency = matchingNetwork.frequency
                }
            } catch (e: Exception) {
                Log.w("MainActivity", "Could not get encryption info: ${e.message}")
            }
            
            // Calculate subnet
            val subnet = "$ipAddress/${netmaskToCidr(netmask)}"
            
            // Prepare DNS servers list
            val dnsServers = mutableListOf<String>()
            if (dns1 != "0.0.0.0") dnsServers.add(dns1)
            if (dns2 != "0.0.0.0") dnsServers.add(dns2)
            
            val networkInfo = mapOf(
                "ssid" to ssid,
                "bssid" to bssid,
                "encryption" to encryption,
                "signalStrength" to rssi,
                "signalLevel" to signalLevel,
                "frequency" to frequency,
                "ipAddress" to ipAddress,
                "gatewayIp" to gatewayIp,
                "gatewayMac" to bssid, // Use BSSID as gateway MAC (best we can do on Android)
                "subnet" to subnet,
                "netmask" to netmask,
                "dnsServers" to dnsServers
            )
            
            Log.d("MainActivity", "✅ Network info collected:")
            Log.d("MainActivity", "   BSSID: $bssid")
            Log.d("MainActivity", "   Gateway IP: $gatewayIp")
            Log.d("MainActivity", "   Encryption: $encryption")
            
            result.success(networkInfo)
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ getCurrentNetworkInfo failed: ${e.message}")
            e.printStackTrace()
            result.error("GET_NETWORK_INFO_FAILED", e.message, null)
        }
    }
    
    private fun intToIp(ip: Int): String {
        return String.format(
            "%d.%d.%d.%d",
            ip and 0xff,
            (ip shr 8) and 0xff,
            (ip shr 16) and 0xff,
            (ip shr 24) and 0xff
        )
    }
    
    private fun netmaskToCidr(netmask: String): Int {
        val parts = netmask.split(".")
        if (parts.size != 4) return 24
        
        var cidr = 0
        for (part in parts) {
            val num = part.toIntOrNull() ?: 0
            cidr += Integer.bitCount(num)
        }
        return cidr
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == PERMISSIONS_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pendingResult?.let { startWifiScan(it) }
            } else {
                pendingResult?.error("PERMISSION_DENIED", "Location permission denied", null)
                pendingResult = null
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            
            // WiFi Scanner channel
            val wifiChannel = NotificationChannel(
                "wifi_scanner",
                "Wi-Fi Scanner Background",
                NotificationManager.IMPORTANCE_LOW
            )
            wifiChannel.description = "Background scanning notifications"
            
            // Evil Twin channel ⭐ ADD THIS!
            val evilTwinChannel = NotificationChannel(
                "evil_twin_channel",
                "Evil Twin Detection",
                NotificationManager.IMPORTANCE_HIGH
            )
            evilTwinChannel.description = "Alerts for Evil Twin attack detection"
            evilTwinChannel.enableVibration(true)
            evilTwinChannel.enableLights(true)
            evilTwinChannel.lightColor = android.graphics.Color.RED
            
            // MITM channel
            val mitmChannel = NotificationChannel(
                "mitm_channel",
                "MITM Detection",
                NotificationManager.IMPORTANCE_HIGH
            )
            mitmChannel.description = "Man-in-the-Middle attack alerts"
            mitmChannel.enableVibration(true)
            mitmChannel.enableLights(true)
            
            // Register all channels
            notificationManager?.createNotificationChannel(wifiChannel)
            notificationManager?.createNotificationChannel(evilTwinChannel)
            notificationManager?.createNotificationChannel(mitmChannel)
            
            Log.d("MainActivity", "✅ All notification channels created")
        }
    }
}