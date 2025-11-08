package com.example.blackwallet

import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.blackwallet/hce"
    private var nfcAdapter: NfcAdapter? = null
    private var cardEmulation: CardEmulation? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        cardEmulation = nfcAdapter?.let { CardEmulation.getInstance(it) }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHceSupported" -> {
                    result.success(nfcAdapter != null && nfcAdapter!!.isEnabled)
                }
                
                "isDefaultPaymentApp" -> {
                    val isDefault = cardEmulation?.isDefaultServiceForCategory(
                        android.content.ComponentName(this, HceService::class.java),
                        CardEmulation.CATEGORY_PAYMENT
                    ) ?: false
                    result.success(isDefault)
                }
                
                "requestDefaultPaymentApp" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NFC_PAYMENT_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open payment settings", e.message)
                    }
                }
                
                "preparePayment" -> {
                    val cardholderName = call.argument<String>("cardholderName") ?: ""
                    val cardToken = call.argument<String>("cardToken") ?: ""
                    val expiryDate = call.argument<String>("expiryDate") ?: ""
                    
                    HceService.cardholderName = cardholderName
                    HceService.cardToken = cardToken
                    HceService.expiryDate = expiryDate
                    HceService.isPaymentReady = true
                    
                    result.success(true)
                }
                
                "cancelPayment" -> {
                    HceService.isPaymentReady = false
                    HceService.cardToken = ""
                    result.success(null)
                }
                
                "isPaymentReady" -> {
                    result.success(HceService.isPaymentReady)
                }
                
                "openNfcSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NFC_SETTINGS)
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open NFC settings", e.message)
                    }
                }
                
                else -> result.notImplemented()
            }
        }
    }
}

