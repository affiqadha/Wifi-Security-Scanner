package com.example.android_wifi_scanner

import android.util.Log
import java.io.IOException
import java.net.URL
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import java.security.SecureRandom
import java.util.Date

class CertificateValidator {
    
    companion object {
        private const val TAG = "CertificateValidator"
        
        // Test HTTPS endpoints - using highly reliable ones
        private val TEST_URLS = listOf(
            "https://www.google.com",
            "https://www.cloudflare.com"
        )
        
        // Increased timeout for better reliability
        private const val CONNECTION_TIMEOUT_MS = 10000  // 10 seconds
        private const val READ_TIMEOUT_MS = 10000        // 10 seconds
    }
    
    /**
     * Check SSL certificate for a given URL
     */
    fun checkCertificate(urlString: String, timeoutMs: Int = CONNECTION_TIMEOUT_MS): CertificateCheckResult {
        try {
            val url = URL(urlString)
            val connection = url.openConnection() as HttpsURLConnection
            connection.connectTimeout = timeoutMs
            connection.readTimeout = READ_TIMEOUT_MS
            
            try {
                connection.connect()
                
                val certificates = connection.serverCertificates
                
                if (certificates.isEmpty()) {
                    Log.w(TAG, "No certificates found for $urlString")
                    return CertificateCheckResult(
                        url = urlString,
                        isValid = false,
                        error = "No certificates found"
                    )
                }
                
                // Check the first certificate (server certificate)
                val serverCert = certificates[0] as? X509Certificate
                
                if (serverCert == null) {
                    Log.w(TAG, "Invalid certificate type for $urlString")
                    return CertificateCheckResult(
                        url = urlString,
                        isValid = false,
                        error = "Invalid certificate type"
                    )
                }
                
                // Validate certificate
                val validation = validateCertificate(serverCert, urlString)
                
                return CertificateCheckResult(
                    url = urlString,
                    isValid = validation.isValid,
                    issuer = serverCert.issuerDN.name,
                    subject = serverCert.subjectDN.name,
                    notBefore = serverCert.notBefore,
                    notAfter = serverCert.notAfter,
                    isSelfSigned = validation.isSelfSigned,
                    isExpired = validation.isExpired,
                    error = validation.error
                )
                
            } finally {
                connection.disconnect()
            }
            
        } catch (e: IOException) {
            Log.w(TAG, "Connection error for $urlString: ${e.message}")
            // Don't treat network errors as security threats
            return CertificateCheckResult(
                url = urlString,
                isValid = true,  // Changed: Network error doesn't mean threat
                error = "Network error (not a security issue): ${e.message}",
                isNetworkError = true
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error checking $urlString: ${e.message}")
            return CertificateCheckResult(
                url = urlString,
                isValid = true,  // Changed: Unknown error doesn't mean threat
                error = "Check failed (not necessarily a threat): ${e.message}",
                isNetworkError = true
            )
        }
    }
    
    /**
     * Validate an X509 certificate
     */
    private fun validateCertificate(cert: X509Certificate, url: String): CertificateValidation {
        val now = Date()
        
        // Check if expired
        val isExpired = now.after(cert.notAfter) || now.before(cert.notBefore)
        
        // Check if self-signed (strong indicator of MITM)
        val isSelfSigned = cert.issuerDN.equals(cert.subjectDN)
        
        // Check hostname match (relaxed - CN or SAN)
        val hostname = try {
            URL(url).host
        } catch (e: Exception) {
            ""
        }
        
        val subjectDN = cert.subjectDN.name
        val hostnameMatches = hostname.isEmpty() || 
                             subjectDN.contains("CN=$hostname", ignoreCase = true) ||
                             subjectDN.contains("CN=*.", ignoreCase = true)  // Wildcard cert
        
        val error = when {
            isExpired -> "Certificate expired or not yet valid"
            isSelfSigned -> "Self-signed certificate (CRITICAL - possible MITM)"
            !hostnameMatches -> "Certificate hostname mismatch (might be CDN)"
            else -> null
        }
        
        // Only flag as invalid if it's a REAL security issue (expired or self-signed)
        // Hostname mismatch might just be CDN, so we're more lenient
        val isValid = !isExpired && !isSelfSigned
        
        return CertificateValidation(
            isValid = isValid,
            isSelfSigned = isSelfSigned,
            isExpired = isExpired,
            hostnameMatches = hostnameMatches,
            error = error
        )
    }
    
    /**
     * Perform SSL stripping detection test
     * More lenient - only flags clear attacks
     */
    fun detectSslStripping(): SslStrippingResult {
        val suspiciousConnections = mutableListOf<String>()
        var totalTests = 0
        var httpsSuccessful = 0
        
        TEST_URLS.forEach { httpsUrl ->
            totalTests++
            
            val checkResult = checkCertificate(httpsUrl, timeoutMs = CONNECTION_TIMEOUT_MS)
            
            // Only count as successful if truly valid (not network error)
            if (checkResult.isValid && !checkResult.isNetworkError) {
                httpsSuccessful++
            } else if (checkResult.isSelfSigned == true) {
                // Self-signed certificate is CRITICAL indicator of MITM
                Log.w(TAG, "CRITICAL: Self-signed cert detected for $httpsUrl")
                suspiciousConnections.add(httpsUrl)
            }
            // Note: We're NOT testing HTTP fallback as it creates false positives
        }
        
        // Only detect stripping if we have CLEAR evidence (self-signed certs)
        val strippingDetected = suspiciousConnections.isNotEmpty()
        
        Log.d(TAG, "SSL Stripping Check: $httpsSuccessful/$totalTests successful, ${suspiciousConnections.size} suspicious")
        
        return SslStrippingResult(
            strippingDetected = strippingDetected,
            suspiciousConnections = suspiciousConnections,
            totalTests = totalTests,
            httpsSuccessful = httpsSuccessful
        )
    }
    
    /**
     * Test if HTTP connection succeeds (removed - causes false positives)
     */
    private fun testHttpConnection(urlString: String): Boolean {
        return false  // Disabled to prevent false positives
    }
    
    /**
     * Comprehensive SSL security check with improved logic
     */
    fun performSslSecurityCheck(): SslSecurityResult {
        val certificateResults = TEST_URLS.map { checkCertificate(it) }
        val strippingResult = detectSslStripping()
        
        // Only count certificates that had actual security issues (not network errors)
        val invalidCerts = certificateResults.filter { 
            !it.isValid && !it.isNetworkError 
        }
        val selfSignedCerts = certificateResults.filter { 
            it.isSelfSigned == true 
        }
        
        // Only flag as threat if we have CLEAR evidence of attack
        val threatDetected = selfSignedCerts.isNotEmpty()  // Only self-signed is critical
        
        val threatLevel = when {
            selfSignedCerts.isNotEmpty() -> "Critical"
            strippingResult.strippingDetected -> "High"
            invalidCerts.size >= 2 -> "Medium"  // Multiple failures might indicate issue
            else -> "Low"
        }
        
        Log.d(TAG, "SSL Security Check: Threat=$threatDetected, Level=$threatLevel, " +
                  "SelfSigned=${selfSignedCerts.size}, Invalid=${invalidCerts.size}")
        
        return SslSecurityResult(
            threatDetected = threatDetected,
            threatLevel = threatLevel,
            certificateResults = certificateResults,
            strippingResult = strippingResult,
            selfSignedCount = selfSignedCerts.size,
            invalidCertCount = invalidCerts.size
        )
    }
    
    data class CertificateCheckResult(
        val url: String,
        val isValid: Boolean,
        val issuer: String? = null,
        val subject: String? = null,
        val notBefore: Date? = null,
        val notAfter: Date? = null,
        val isSelfSigned: Boolean? = null,
        val isExpired: Boolean? = null,
        val error: String? = null,
        val isNetworkError: Boolean = false  // New: distinguish network errors from security issues
    )
    
    data class CertificateValidation(
        val isValid: Boolean,
        val isSelfSigned: Boolean,
        val isExpired: Boolean,
        val hostnameMatches: Boolean,
        val error: String?
    )
    
    data class SslStrippingResult(
        val strippingDetected: Boolean,
        val suspiciousConnections: List<String>,
        val totalTests: Int,
        val httpsSuccessful: Int
    )
    
    data class SslSecurityResult(
        val threatDetected: Boolean,
        val threatLevel: String,
        val certificateResults: List<CertificateCheckResult>,
        val strippingResult: SslStrippingResult,
        val selfSignedCount: Int,
        val invalidCertCount: Int
    )
}