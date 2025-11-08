# BlackWallet Testing Quick Start Guide

## Getting Started with Testing

This guide will help you quickly test all the new features added to BlackWallet.

## Prerequisites

1. **Physical Android Device** (recommended for NFC and biometric testing)
   - Enable Developer Options
   - Enable USB Debugging
   - Enable NFC in device settings
   - Set up fingerprint/face unlock

2. **Backend Server Running**
   ```powershell
   cd ewallet_backend
   python main.py
   ```

3. **Test Account**
   - Create a test account or use existing credentials
   - Ensure account has some balance for testing transactions

## Quick Test Flow (5 Minutes)

### 1. Developer Testing Screen (Fastest Way!)

The easiest way to test all features:

1. **Open the app**
2. **Go to Wallet → Menu (top right) → "Dev Testing"** (only visible in debug mode)
3. **Tap "Run All Tests"** - This will automatically test:
   - API Connection
   - Biometric Authentication
   - PIN Service
   - Notifications (you'll see 4 test notifications)
   - NFC Availability
   - Receipt Generation

4. **Review the log output** at the bottom of the screen - all tests should show "SUCCESS" or "PASS"

### 2. Manual Feature Testing (10 Minutes)

#### A. PIN Setup & Authentication
1. Go to **Profile → Security Section**
2. Tap **"Set up PIN"**
3. Enter a 4-6 digit PIN (e.g., `1234`)
4. Confirm PIN
5. Close app completely
6. Reopen app
7. When biometric prompt appears, tap **"Use PIN instead"**
8. Enter your PIN → should unlock app

#### B. Biometric Authentication
1. Close and reopen app
2. Use fingerprint/face ID to unlock
3. Try sending money > $100
4. Verify biometric prompt appears for transaction auth

#### C. NFC Tap-to-Pay
1. Go to **Wallet → Menu → NFC Tap-to-Pay**
2. **Receive Tab (Create Payment Tag)**:
   - Enter amount: `10.50`
   - Enter note: `Coffee payment`
   - Tap "Create Payment Tag"
   - Hold NFC sticker/card to phone back
   - Verify success message

3. **Pay Tab (Read Tag)**:
   - Tap "Start Terminal Payment"
   - Hold the tagged NFC sticker to phone
   - Verify payment details appear
   - Confirm payment
   - Check balance updated

4. **Phone-to-Phone (P2P)** (requires 2 devices):
   - Device A: NFC screen → Pay tab
   - Enter recipient username
   - Enter amount: `5.00`
   - Tap "Send via NFC (Phone-to-Phone)"
   - Device B: Open NFC screen (any tab)
   - Hold devices back-to-back
   - Verify payment notification on Device B
   - Check both balances updated

#### D. Transaction Receipts & Export
1. Go to **Transactions** screen
2. **Export All**:
   - Tap export icon (top right)
   - Choose "Export as CSV"
   - Verify CSV file opens/shares

3. **Individual Receipt**:
   - Tap any transaction in the list
   - Bottom sheet appears
   - Tap "Generate PDF Receipt"
   - Verify PDF opens/shares
   - Check all transaction details present

#### E. Notifications
1. **Test each type**:
   - Make a deposit → Check notification
   - Send money → Check notification
   - Create payment request → Check notification
   - Complete NFC payment → Check notification

2. **Permission Check**:
   - Go to Profile → Preferences
   - Toggle "Push Notifications" off/on
   - Verify notifications respect setting

#### F. Profile & Settings Management
1. Go to **Profile**
2. **Security Section** should show:
   - Biometric toggle (if device supports)
   - Set up/Change PIN option
   - Remove PIN (if PIN is set)
   - Change Password

3. **Test PIN Management**:
   - Change PIN: Verify → New PIN → Confirm
   - Remove PIN: Verify → Removed

## Common Issues & Solutions

### Issue: Biometric not working
- **Solution**: Check device supports biometric
- Enable in device settings
- Re-enroll fingerprint/face
- Check app permissions

### Issue: NFC not available
- **Solution**: Check device has NFC hardware
- Enable NFC in device settings (Settings → Connected devices → Connection preferences → NFC)
- Try rebooting device

### Issue: Notifications not showing
- **Solution**: Grant notification permission
- Check "Do Not Disturb" is off
- Enable in Profile → Preferences → Push Notifications

### Issue: PIN not saving
- **Solution**: Clear app data and retry
- Check storage permissions
- Verify SharedPreferences working

### Issue: API connection failed
- **Solution**: Check backend server running
- Verify device can reach server IP
- Check API_BASE_URL in code
- Check token is valid

## Testing Checklist

Use this quick checklist during testing:

```
□ Biometric auth on app startup
□ PIN fallback works
□ PIN setup/change/remove
□ NFC tag write (create payment tag)
□ NFC tag read (pay from tag)
□ NFC P2P (phone-to-phone)
□ Generate PDF receipt
□ Export transactions CSV
□ All 4 notification types work
□ Profile shows correct PIN status
□ Dev Testing screen runs all tests
□ App handles errors gracefully
```

## Advanced Testing

### Load Testing
1. Create 50+ transactions
2. Test scroll performance on Transactions screen
3. Export large CSV
4. Generate multiple PDFs

### Error Scenarios
1. Disable network → Test offline behavior
2. Invalid NFC tag → Verify error message
3. Insufficient balance → Verify validation
4. Wrong PIN multiple times → Verify handling
5. Cancel biometric → Verify fallback works

### Security Testing
1. Try bypassing biometric (should not be possible)
2. Check PIN is hashed (not plain text)
3. Verify session timeout works (5 min)
4. Check sensitive data not in logs
5. Verify high-value transactions require auth

## Performance Benchmarks

Expected performance:
- **App startup**: < 2 seconds (with biometric)
- **NFC tag read**: < 1 second
- **Receipt PDF generation**: < 2 seconds
- **CSV export (100 transactions)**: < 3 seconds
- **Notification display**: Instant
- **PIN verification**: < 0.5 seconds

## Automated Testing

Run the automated test suite:

```powershell
# From BlackWallet directory
flutter test
```

## Debugging Tips

### Enable verbose logging:
```dart
// In main.dart, add:
debugPrint('Your log message here');
```

### Check Android logs:
```powershell
flutter logs
# or
adb logcat | Select-String "flutter"
```

### NFC debugging:
```powershell
adb logcat | Select-String "NFC"
```

## Test Data

### Test Cards (Stripe)
- **Success**: 4242 4242 4242 4242
- **Decline**: 4000 0000 0000 0002
- **Insufficient Funds**: 4000 0000 0000 9995

### Test Scenarios
1. **Happy Path**: New user → Setup → Deposit → Send → Request → NFC
2. **Error Path**: Invalid username → Insufficient funds → Network error
3. **Edge Cases**: Minimum amounts → Maximum amounts → Concurrent operations

## Next Steps

After testing, consider:
1. Review the full [TESTING_CHECKLIST.md](./TESTING_CHECKLIST.md) for comprehensive testing
2. Document any bugs found
3. Test on multiple devices/Android versions
4. Perform security audit
5. Optimize performance bottlenecks
6. Add more unit/integration tests

## Support

If you encounter issues:
1. Check the logs in Dev Testing screen
2. Review error messages carefully
3. Try restarting the app
4. Clear app data if needed
5. Check backend server logs

## Testing Complete? ✅

Once all tests pass:
- [ ] All features working
- [ ] No critical bugs
- [ ] Performance acceptable
- [ ] Security validated
- [ ] Ready for production polish

---

**Remember**: Remove or disable the Dev Testing screen before production release!
