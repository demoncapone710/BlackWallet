package com.example.blackwallet

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * BlackWallet Host Card Emulation Service
 * 
 * This service allows the app to emulate an NFC card for contactless payments.
 * It handles APDU commands from POS terminals and responds with payment data.
 * 
 * Security Notes:
 * - Tokens should be dynamically generated and have short lifespans
 * - Real implementation requires server-side tokenization
 * - PCI DSS compliance mandatory for production
 */
class HceService : HostApduService() {

    companion object {
        private const val TAG = "BlackWalletHCE"
        
        // AID for payment application (must match apduservice.xml)
        private const val PAYMENT_AID = "F0010203040506"
        
        // APDU Command codes
        private const val SELECT_APDU_HEADER = "00A40400"
        private const val GET_PROCESSING_OPTIONS = "80A80000"
        private const val READ_RECORD = "00B2"
        
        // Status codes
        private val SUCCESS_SW = byteArrayOf(0x90.toByte(), 0x00.toByte())
        private val FAILED_SW = byteArrayOf(0x6F.toByte(), 0x00.toByte())
        private val NOT_FOUND_SW = byteArrayOf(0x6A.toByte(), 0x82.toByte())
        
        // Shared data from Flutter
        var cardholderName: String = "BlackWallet User"
        var cardToken: String = ""
        var expiryDate: String = "1225" // MMYY format
        var isPaymentReady: Boolean = false
    }

    override fun onDeactivated(reason: Int) {
        Log.d(TAG, "Service deactivated. Reason: $reason")
    }

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) {
            return FAILED_SW
        }

        val hexCommand = bytesToHex(commandApdu)
        Log.d(TAG, "Received APDU: $hexCommand")

        return when {
            // SELECT command - POS terminal selecting payment app
            hexCommand.startsWith(SELECT_APDU_HEADER) -> {
                handleSelectCommand(commandApdu)
            }
            
            // GET PROCESSING OPTIONS - Terminal requesting payment details
            hexCommand.startsWith(GET_PROCESSING_OPTIONS) -> {
                handleGetProcessingOptions()
            }
            
            // READ RECORD - Terminal reading card data
            hexCommand.startsWith(READ_RECORD) -> {
                handleReadRecord(commandApdu)
            }
            
            else -> {
                Log.w(TAG, "Unknown command: $hexCommand")
                FAILED_SW
            }
        }
    }

    private fun handleSelectCommand(commandApdu: ByteArray): ByteArray {
        Log.d(TAG, "Handling SELECT command")
        
        if (!isPaymentReady) {
            Log.w(TAG, "Payment not ready")
            return NOT_FOUND_SW
        }

        // Extract AID from command
        val aidLength = commandApdu[4].toInt()
        val receivedAid = commandApdu.copyOfRange(5, 5 + aidLength)
        val receivedAidHex = bytesToHex(receivedAid)
        
        Log.d(TAG, "Received AID: $receivedAidHex")

        return if (receivedAidHex == PAYMENT_AID) {
            // Return File Control Information (FCI)
            val fci = buildFCI()
            concatenate(fci, SUCCESS_SW)
        } else {
            NOT_FOUND_SW
        }
    }

    private fun handleGetProcessingOptions(): ByteArray {
        Log.d(TAG, "Handling GET PROCESSING OPTIONS")
        
        if (!isPaymentReady || cardToken.isEmpty()) {
            return FAILED_SW
        }

        // Build Application Interchange Profile (AIP) and Application File Locator (AFL)
        val response = ByteArrayOutputStream()
        
        // Tag 0x80 - Response Message Template Format 1
        response.write(0x80)
        response.write(0x06) // Length
        
        // AIP (2 bytes) - CDA supported
        response.write(0x00)
        response.write(0x80)
        
        // AFL (4 bytes) - Record 1-4 on file 1
        response.write(0x08)
        response.write(0x01)
        response.write(0x01)
        response.write(0x00)

        return concatenate(response.toByteArray(), SUCCESS_SW)
    }

    private fun handleReadRecord(commandApdu: ByteArray): ByteArray {
        if (commandApdu.size < 3) {
            return FAILED_SW
        }

        val recordNumber = commandApdu[2].toInt()
        val sfi = (commandApdu[3].toInt() shr 3) and 0x1F
        
        Log.d(TAG, "Reading record $recordNumber from SFI $sfi")

        return when (recordNumber) {
            1 -> buildRecord1()
            2 -> buildRecord2()
            else -> NOT_FOUND_SW
        }
    }

    private fun buildFCI(): ByteArray {
        val fci = ByteArrayOutputStream()
        
        // FCI Template (Tag 0x6F)
        fci.write(0x6F)
        
        val fciData = ByteArrayOutputStream()
        
        // DF Name / AID (Tag 0x84)
        fciData.write(0x84)
        val aidBytes = hexToBytes(PAYMENT_AID)
        fciData.write(aidBytes.size)
        fciData.write(aidBytes)
        
        // Application Label (Tag 0x50)
        fciData.write(0x50)
        val label = "BlackWallet".toByteArray()
        fciData.write(label.size)
        fciData.write(label)
        
        // Application Priority (Tag 0x87)
        fciData.write(0x87)
        fciData.write(0x01)
        fciData.write(0x01) // Priority 1
        
        val fciDataBytes = fciData.toByteArray()
        fci.write(fciDataBytes.size)
        fci.write(fciDataBytes)
        
        return fci.toByteArray()
    }

    private fun buildRecord1(): ByteArray {
        val record = ByteArrayOutputStream()
        
        // Record Template (Tag 0x70)
        record.write(0x70)
        
        val recordData = ByteArrayOutputStream()
        
        // Application PAN (Tag 0x5A) - Using tokenized card number
        recordData.write(0x5A)
        val panBytes = encodePAN(cardToken)
        recordData.write(panBytes.size)
        recordData.write(panBytes)
        
        // Cardholder Name (Tag 0x5F20)
        recordData.write(0x5F)
        recordData.write(0x20)
        val nameBytes = cardholderName.toByteArray()
        recordData.write(nameBytes.size)
        recordData.write(nameBytes)
        
        // Application Expiration Date (Tag 0x5F24)
        recordData.write(0x5F)
        recordData.write(0x24)
        val expiryBytes = hexToBytes(expiryDate)
        recordData.write(expiryBytes.size)
        recordData.write(expiryBytes)
        
        val recordDataBytes = recordData.toByteArray()
        record.write(recordDataBytes.size)
        record.write(recordDataBytes)
        
        return concatenate(record.toByteArray(), SUCCESS_SW)
    }

    private fun buildRecord2(): ByteArray {
        val record = ByteArrayOutputStream()
        
        // Record Template (Tag 0x70)
        record.write(0x70)
        
        val recordData = ByteArrayOutputStream()
        
        // Track 2 Equivalent Data (Tag 0x57)
        recordData.write(0x57)
        val track2 = buildTrack2Data()
        recordData.write(track2.size)
        recordData.write(track2)
        
        // Application Cryptogram (Tag 0x9F26) - Dynamic data
        recordData.write(0x9F)
        recordData.write(0x26)
        recordData.write(0x08)
        recordData.write(generateCryptogram())
        
        val recordDataBytes = recordData.toByteArray()
        record.write(recordDataBytes.size)
        record.write(recordDataBytes)
        
        return concatenate(record.toByteArray(), SUCCESS_SW)
    }

    private fun encodePAN(token: String): ByteArray {
        // Encode PAN in BCD format (right-justified with 'F' padding)
        val cleaned = token.replace(Regex("[^0-9]"), "")
        val padded = if (cleaned.length % 2 != 0) cleaned + "F" else cleaned
        return hexToBytes(padded)
    }

    private fun buildTrack2Data(): ByteArray {
        // Format: PAN + separator (D) + Expiry (YYMM) + Service Code + Discretionary Data
        val cleaned = cardToken.replace(Regex("[^0-9]"), "")
        val track2String = cleaned + "D" + expiryDate + "201"
        return hexToBytes(track2String.replace("D", "D"))
    }

    private fun generateCryptogram(): ByteArray {
        // In production, this should be a proper cryptographic operation
        // using card keys and transaction data
        // For now, return a simple pseudo-random value
        val random = ByteArray(8)
        for (i in 0..7) {
            random[i] = ((System.currentTimeMillis() shr (i * 8)) and 0xFF).toByte()
        }
        return random
    }

    // Utility functions
    private fun bytesToHex(bytes: ByteArray): String {
        return bytes.joinToString("") { "%02X".format(it) }
    }

    private fun hexToBytes(hex: String): ByteArray {
        val result = ByteArray(hex.length / 2)
        for (i in result.indices) {
            val index = i * 2
            result[i] = hex.substring(index, index + 2).toInt(16).toByte()
        }
        return result
    }

    private fun concatenate(a: ByteArray, b: ByteArray): ByteArray {
        val result = ByteArray(a.size + b.size)
        System.arraycopy(a, 0, result, 0, a.size)
        System.arraycopy(b, 0, result, a.size, b.size)
        return result
    }
}
