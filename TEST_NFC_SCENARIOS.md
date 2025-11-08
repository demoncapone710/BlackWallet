# NFC Testing Scenarios - BlackWallet

## 🧪 Comprehensive NFC Test Guide

### Prerequisites
- ✅ Backend server running on port 8000
- ✅ Android device with NFC enabled
- ✅ User account with balance
- ✅ Virtual card created (for ATM testing)

---

## Test Scenario 1: POS Terminal Payment (HCE)

### Test 1A: Setup & Activation

**Steps:**
1. Open BlackWallet app
2. Navigate to **Wallet → Menu → "HCE Contactless Pay"**
3. Check status indicators:
   - ✅ NFC Available
   - ✅ HCE Supported
   - ⚠️ Not Default Payment App (if first time)

**Expected Results:**
- Screen shows "Set as Default Payment App" card
- "Activate Contactless Payment" button disabled until default is set

**Actions:**
4. Tap **"Set as Default Payment App"**
5. System Settings opens → NFC & Payment
6. Select **BlackWallet** as default
7. Return to app
8. Tap **"Activate Contactless Payment"**
9. Complete biometric authentication (fingerprint/face)

**Expected Results:**
- ✅ Green checkmark appears
- Status: "Payment Ready"
- NFC icon pulsing animation
- Message: "Hold phone to contactless terminal"

---

### Test 1B: Small Purchase (<$25)

**Hardware Needed:**
- POS terminal with contactless support OR
- Another Android device with terminal emulator app

**Steps:**
1. Payment activated (from Test 1A)
2. Merchant enters amount: **$15.00**
3. Terminal prompts: "Tap card or phone"
4. Hold phone to terminal (back of phone, < 4cm distance)
5. Keep phone steady for 1-2 seconds

**Expected Results:**
- Phone vibrates slightly
- Terminal beeps/shows approval
- Screen shows: "Payment Processing..."
- Transaction approved within 2-3 seconds
- Success message: "Payment Complete - $15.00"
- Balance deducted immediately
- Transaction appears in history

**Backend Verification:**
```bash
# Check backend logs
curl http://localhost:8000/api/cards/MY_CARD_ID/transactions
```

**Should show:**
```json
{
  "amount": 15.00,
  "merchant": "Test Merchant",
  "entry_mode": "contactless",
  "status": "completed",
  "auth_code": "ABC123"
}
```

---

### Test 1C: Large Purchase (>$25)

**Steps:**
1. Merchant enters amount: **$150.00**
2. Hold phone to terminal
3. Terminal prompts: "Enter PIN" or "Sign receipt"

**Expected Results:**
- Transaction requires additional verification
- PIN pad appears OR signature requested
- After verification, payment approved
- Higher security for larger amounts

---

### Test 1D: Multiple Consecutive Payments

**Steps:**
1. Complete payment #1: $10.00
2. Wait 2 seconds
3. Complete payment #2: $20.00
4. Wait 2 seconds
5. Complete payment #3: $15.00

**Expected Results:**
- All three payments process successfully
- No need to reactivate between payments
- Each transaction has unique auth code
- Balance updates after each payment

---

### Test 1E: Insufficient Funds

**Setup:**
- User balance: $25.00
- Purchase amount: $50.00

**Steps:**
1. Merchant enters $50.00
2. Hold phone to terminal

**Expected Results:**
- Terminal shows: "Declined - Insufficient Funds"
- No money deducted
- Transaction status: "declined"
- User receives notification

---

### Test 1F: Frozen Card

**Setup:**
1. Go to Virtual Cards screen
2. Freeze the card

**Steps:**
1. Attempt to make payment
2. Hold phone to terminal

**Expected Results:**
- Terminal shows: "Declined - Card Inactive"
- No payment processed
- Security measure working

---

## Test Scenario 2: ATM Withdrawal

### Test 2A: Contactless ATM Withdrawal

**Hardware Needed:**
- NFC-enabled ATM (look for contactless symbol)

**Steps:**
1. Create virtual card if not exists:
   - Wallet → Virtual Cards → "Create Card"
   - Set PIN (e.g., 1234)
   - Card generated with 16-digit number
   
2. Go to ATM
3. Select "Contactless Withdrawal"
4. Hold phone to NFC reader on ATM
5. ATM reads card data
6. Enter PIN on ATM keypad: **1234**
7. Select amount: **$100.00**
8. Confirm transaction

**Expected Results:**
- Card recognized by ATM
- PIN accepted
- Cash dispensed
- Wallet balance deducted: $100.00
- Transaction fee (if any) shown
- Transaction in history with type: "ATM Withdrawal"

---

### Test 2B: Daily Limit Enforcement

**Setup:**
- Card daily limit: $500
- Already withdrawn today: $400

**Steps:**
1. Attempt to withdraw: **$200.00**

**Expected Results:**
- ATM shows: "Daily limit exceeded"
- Remaining limit: $100.00
- Transaction declined
- No funds deducted

---

### Test 2C: Wrong PIN (Security)

**Steps:**
1. Tap card at ATM
2. Enter wrong PIN: **0000**
3. Try again: **9999**
4. Try third time: **8888**

**Expected Results:**
- After 3 failed attempts:
  - Card automatically frozen
  - User receives security alert notification
  - Must unfreeze in app
  - Prevents fraud

---

### Test 2D: Balance Inquiry

**Steps:**
1. Tap card at ATM
2. Enter PIN
3. Select "Balance Inquiry" (not withdrawal)

**Expected Results:**
- ATM shows current wallet balance
- No transaction fee
- No fund movement
- Just information display

---

## Test Scenario 3: Phone-to-Phone (P2P) - When Re-enabled

### Test 3A: Basic P2P Transfer

**Hardware Needed:**
- 2 Android devices with NFC
- Both have BlackWallet app
- Both users logged in

**Device A (Sender):**
1. Balance: $100.00
2. Navigate to **Wallet → Menu → "NFC Tap-to-Pay"**
3. Switch to **"Pay"** tab
4. Scroll to "Phone-to-Phone Payment" section
5. Enter amount: **$25.00**
6. Tap **"Send via Phone Tap"**
7. Screen shows: "Hold phones back-to-back..."

**Device B (Receiver):**
1. Open BlackWallet (any screen with NFC active)
2. Or open NFC Payment screen

**Both Devices:**
1. Hold phones back-to-back
2. Align NFC areas (usually center/top of back)
3. Keep steady for 2-3 seconds

**Expected Results:**
- Both phones vibrate
- Device A shows: "Sending $25.00..."
- Device B shows: "Receiving payment..."
- Both show success message
- Device A: Balance decreases to $75.00
- Device B: Balance increases by $25.00
- Both receive notifications
- Transaction in both histories

---

### Test 3B: High-Value P2P (≥$100)

**Steps:**
Same as Test 3A but amount: **$150.00**

**Expected Results:**
- Before NFC tap, Device A prompts biometric authentication
- User must authenticate with fingerprint/face
- Then proceed with NFC transfer
- Security measure for large transfers

---

### Test 3C: P2P with Note/Memo

**Steps:**
1. Device A enters amount: $20.00
2. Add note: "Lunch money"
3. Send via NFC tap

**Expected Results:**
- Note appears in receiver's notification
- Note visible in transaction history
- Helps identify payment purpose

---

### Test 3D: P2P Connection Timeout

**Steps:**
1. Device A initiates payment
2. Wait 30 seconds without bringing devices together

**Expected Results:**
- Timeout message after 30 seconds
- "NFC connection timeout - Please try again"
- No funds moved
- Can retry immediately

---

### Test 3E: P2P Insufficient Funds

**Setup:**
- Device A balance: $15.00
- Attempt to send: $30.00

**Steps:**
1. Enter amount: $30.00
2. Tap "Send via Phone Tap"

**Expected Results:**
- BEFORE NFC tap, app checks balance
- Shows error: "Insufficient funds"
- Prevents NFC initiation
- Saves user embarrassment

---

## 🔧 Troubleshooting Guide

### Issue: "NFC Not Available"

**Solution:**
1. Check device settings: Settings → Connected devices → NFC
2. Enable NFC toggle
3. Restart app
4. If still not working, device may not support NFC

---

### Issue: "Not Set as Default Payment App"

**Solution:**
1. Go to: Settings → Apps → Default apps → Tap & pay
2. Select "BlackWallet"
3. Return to app and retry

---

### Issue: POS Terminal Not Recognizing Phone

**Causes & Solutions:**
1. **Too far away**
   - Hold phone closer (< 4cm)
   - Direct contact with terminal

2. **Wrong area of phone**
   - NFC antenna usually in center/top of back
   - Try different positions

3. **Payment not activated**
   - Open HCE Payment screen
   - Check "Payment Ready" status
   - Reactivate if needed

4. **Terminal doesn't support HCE**
   - Some older terminals only work with physical cards
   - Try different terminal

5. **Phone case interference**
   - Metal cases block NFC
   - Remove case and retry

---

### Issue: ATM Rejecting Card

**Solutions:**
1. Check card status in app (not frozen)
2. Verify correct PIN
3. Check daily limits
4. Ensure sufficient balance
5. Try different ATM

---

### Issue: P2P Not Working (When Enabled)

**Solutions:**
1. Both devices have NFC enabled
2. Both devices unlocked
3. Both apps open and active
4. Phones properly aligned
5. Hold steady for full 2-3 seconds
6. Try airplane mode off
7. Restart both apps

---

## 📊 Test Results Tracking

### POS Terminal Tests
- [ ] Test 1A: Setup & Activation
- [ ] Test 1B: Small Purchase (<$25)
- [ ] Test 1C: Large Purchase (>$25)
- [ ] Test 1D: Multiple Consecutive Payments
- [ ] Test 1E: Insufficient Funds
- [ ] Test 1F: Frozen Card

**Notes:** _______________________________________________

---

### ATM Tests
- [ ] Test 2A: Contactless Withdrawal
- [ ] Test 2B: Daily Limit Enforcement
- [ ] Test 2C: Wrong PIN Security
- [ ] Test 2D: Balance Inquiry

**Notes:** _______________________________________________

---

### P2P Tests (When Re-enabled)
- [ ] Test 3A: Basic P2P Transfer
- [ ] Test 3B: High-Value P2P (≥$100)
- [ ] Test 3C: P2P with Note
- [ ] Test 3D: Connection Timeout
- [ ] Test 3E: Insufficient Funds

**Notes:** _______________________________________________

---

## 🎯 Success Criteria

### All Tests Pass If:
1. ✅ POS payments work at real terminals
2. ✅ ATM withdrawals process correctly
3. ✅ Security measures (biometric, PIN, limits) enforced
4. ✅ Transaction history accurate
5. ✅ Balances update in real-time
6. ✅ Notifications sent for all transactions
7. ✅ Error handling graceful and informative

### Production Ready When:
1. ✅ All test scenarios pass
2. ✅ Security audit completed
3. ✅ PCI DSS compliance verified
4. ✅ EMV certification obtained
5. ✅ Load testing completed (100+ concurrent transactions)
6. ✅ Fraud detection rules active
7. ✅ 24/7 monitoring in place

---

## 📞 Support Testing

If any test fails:
1. Check backend logs: `ewallet_backend/logs/blackwallet.log`
2. Check Flutter console for errors
3. Enable debug mode in HCE service
4. Check Android logcat for NFC events:
   ```bash
   adb logcat | grep -i nfc
   ```
5. Verify network connectivity
6. Restart app and retry

---

**Test Date:** _______________
**Tester:** _______________
**Device Model:** _______________
**Android Version:** _______________
**App Version:** _______________
**Overall Result:** [ ] PASS  [ ] FAIL  [ ] PARTIAL

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________
