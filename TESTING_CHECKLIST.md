# BlackWallet Testing Checklist

## Pre-Testing Setup
- [ ] Ensure device has NFC hardware enabled
- [ ] Enable biometric authentication on device (fingerprint/face ID)
- [ ] Have at least 2 devices for NFC P2P testing
- [ ] Backend server running and accessible
- [ ] Test user account created with funds

## 1. Authentication & Security Tests

### Biometric Authentication
- [ ] **App Startup - Biometric Required**
  - Launch app
  - Verify biometric prompt appears
  - Cancel authentication → verify stays on auth screen
  - Authenticate successfully → verify navigates to wallet
  - Test with incorrect biometric → verify error handling

- [ ] **Biometric Fallback to PIN**
  - Launch app and fail/cancel biometric auth
  - Tap "Use PIN instead" button
  - Enter correct PIN → verify navigates to wallet
  - Enter incorrect PIN → verify error message

- [ ] **Transaction Authentication**
  - Initiate high-value send (>$100)
  - Verify biometric prompt appears
  - Cancel → verify transaction cancelled
  - Authenticate → verify transaction proceeds

### PIN Authentication
- [ ] **PIN Setup**
  - Go to Profile → "Set up PIN"
  - Enter 4-6 digit PIN
  - Confirm PIN matches
  - Verify PIN is saved

- [ ] **PIN Change**
  - Go to Profile → "Change PIN"
  - Verify current PIN required
  - Enter new PIN and confirm
  - Verify PIN updated

- [ ] **PIN Unlock**
  - Fail biometric auth on startup
  - Use "Use PIN instead"
  - Enter correct PIN → verify app unlocks
  - Enter wrong PIN → verify error, retry allowed

- [ ] **PIN Remove**
  - Go to Profile → "Remove PIN"
  - Verify PIN required to remove
  - Confirm removal
  - Restart app → verify no PIN prompt (only biometric)

### Session Management
- [ ] App stays unlocked for 5 minutes of activity
- [ ] App locks after 5 minutes of inactivity
- [ ] Lock screen requires re-authentication
- [ ] Sensitive operations always require auth regardless of session

## 2. NFC Payment Tests

### NFC Hardware Check
- [ ] **NFC Availability**
  - Go to Wallet → Menu → "NFC Tap-to-Pay"
  - Verify NFC availability message
  - If unavailable, verify helpful error message

### NFC Tag Payment (Write)
- [ ] **Create Payment Tag**
  - Open NFC screen → "Receive" tab
  - Enter amount ($10.50)
  - Enter optional note
  - Tap "Create Payment Tag"
  - Hold NFC tag to device
  - Verify success message
  - Verify tag details shown

- [ ] **Read Payment Tag**
  - Have another user open NFC screen → "Pay" tab
  - Tap "Start Terminal Payment"
  - Hold tagged NFC sticker to device
  - Verify payment details displayed
  - Confirm biometric auth if required
  - Verify payment processed
  - Check balance deducted

### NFC Phone-to-Phone (P2P)
- [ ] **Send Money via NFC P2P**
  - Device A: Open NFC screen → "Pay" tab
  - Enter recipient username
  - Enter amount ($5.00)
  - Tap "Send via NFC (Phone-to-Phone)"
  - Device B: Open NFC screen → "Pay" tab (or any screen with NFC active)
  - Hold devices back-to-back
  - Verify Device B receives payment notification
  - Verify both balances updated

- [ ] **P2P with Note**
  - Same as above but include a note
  - Verify note appears in notification & transaction history

### NFC Error Handling
- [ ] Tag read timeout → verify error message
- [ ] Invalid tag format → verify error message
- [ ] Insufficient funds → verify error before NFC write
- [ ] Network error during payment → verify graceful handling
- [ ] NFC disabled on device → verify helpful message

## 3. Transaction Receipt & Export Tests

### Individual Receipt Generation
- [ ] **PDF Receipt**
  - Go to Transactions screen
  - Tap any transaction
  - Tap "Generate PDF Receipt"
  - Verify PDF opens/shares correctly
  - Check PDF contains: transaction ID, date, amount, status, parties, note

- [ ] **Share Receipt**
  - Generate PDF receipt
  - Tap share button
  - Verify share sheet appears
  - Share via email/message → verify attachment received

### Bulk Export
- [ ] **CSV Export**
  - Go to Transactions screen
  - Tap "Export CSV" button (top right)
  - Verify CSV file generated
  - Open CSV → verify all transactions present
  - Check columns: Date, Type, Amount, From, To, Status, Note

- [ ] **Empty Transaction List**
  - New account with no transactions
  - Attempt export → verify handles gracefully

## 4. Notification Tests

### Local Notifications
- [ ] **Deposit Notification**
  - Complete card deposit
  - Verify notification appears
  - Tap notification → verify opens app

- [ ] **Money Sent Notification**
  - Send money to another user
  - Verify "Money sent" notification

- [ ] **Money Request Notification**
  - Create payment request
  - Verify "Payment request sent" notification

- [ ] **NFC Payment Notification**
  - Complete NFC payment
  - Verify notification with amount & recipient

### Notification Permissions
- [ ] Deny notification permission → app functions without notifications
- [ ] Enable notification in Profile settings → verify notifications work
- [ ] Disable in Profile → verify notifications stop

## 5. Core Wallet Features

### Balance & Dashboard
- [ ] Balance displays correctly
- [ ] Stat cards show accurate data (Today, Week, Month)
- [ ] Recent transactions list populated
- [ ] Pull-to-refresh updates data

### Send Money
- [ ] Send to valid username → success
- [ ] Send to invalid username → error message
- [ ] Send amount > balance → error message
- [ ] Send $0 or negative → validation error
- [ ] Add optional note → verify appears in transaction
- [ ] Biometric auth for high value → verify prompt

### Receive Money / Request
- [ ] Create payment request with amount
- [ ] Share QR code
- [ ] Another user scans QR → verify request appears
- [ ] Fulfill request → verify payment completes
- [ ] View pending requests

### Deposit
- [ ] Add bank account (mock)
- [ ] Deposit from bank → verify balance increases
- [ ] Add credit card
- [ ] Deposit from card (Stripe test card: 4242 4242 4242 4242)
- [ ] Verify notification appears
- [ ] Check transaction history

### QR Code Payments
- [ ] Generate QR code for payment request
- [ ] Another device scans QR
- [ ] Payment processes correctly
- [ ] Invalid QR → error handling

## 6. UI/UX Tests

### Theme & Design
- [ ] Black and red theme applied consistently
- [ ] Gradient backgrounds render correctly
- [ ] Icons and colors match design
- [ ] Dark mode toggle works (Profile settings)

### Navigation
- [ ] Bottom navigation works (Wallet, Transactions, Profile)
- [ ] Back button behavior correct
- [ ] Menu items all navigate correctly
- [ ] Deep links work (if implemented)

### Responsive Design
- [ ] Test on different screen sizes
- [ ] Landscape orientation
- [ ] Text scaling (accessibility)
- [ ] Touch targets adequate size

### Error States
- [ ] Network offline → graceful error messages
- [ ] Server error → user-friendly message
- [ ] Loading indicators display during operations
- [ ] Empty states (no transactions, no cards, etc.)

## 7. Profile & Settings

### Profile Management
- [ ] View profile with username and balance
- [ ] Avatar shows initial letter
- [ ] Settings persist after app restart

### Security Settings
- [ ] Toggle biometric authentication
- [ ] PIN setup/change/remove
- [ ] Change password (if implemented)

### Preferences
- [ ] Notification toggle persists
- [ ] Dark mode toggle (requires restart)
- [ ] Settings sync across sessions

### Logout
- [ ] Logout confirmation dialog
- [ ] Logout clears session
- [ ] Returns to login screen
- [ ] Cannot access app without re-login

## 8. Edge Cases & Stress Tests

### Performance
- [ ] Large transaction list (100+ items) scrolls smoothly
- [ ] Multiple rapid API calls handled gracefully
- [ ] Low memory conditions
- [ ] Slow network conditions

### Data Integrity
- [ ] Balance updates atomically
- [ ] No duplicate transactions
- [ ] Transaction history consistent
- [ ] Concurrent operations handled

### Security
- [ ] Cannot bypass biometric/PIN on startup
- [ ] Session timeout works correctly
- [ ] Sensitive data not exposed in logs
- [ ] API tokens securely stored

### Device Compatibility
- [ ] Test on multiple Android versions
- [ ] Different NFC chip implementations
- [ ] Various biometric hardware types
- [ ] Different screen densities

## 9. Backend Integration

### API Calls
- [ ] All endpoints return expected data
- [ ] Error responses handled gracefully
- [ ] Token refresh works (if applicable)
- [ ] Rate limiting respected

### Real-time Updates
- [ ] Balance refreshes correctly
- [ ] Transaction list updates
- [ ] Pull-to-refresh works

## 10. Production Readiness

### Security Audit
- [ ] Secure token storage
- [ ] PIN hashing verified (SHA-256)
- [ ] Biometric integration secure
- [ ] No sensitive data in logs
- [ ] HTTPS enforced

### Compliance
- [ ] Privacy policy accessible
- [ ] Terms of service accessible
- [ ] User consent for biometrics
- [ ] Data protection measures

### Error Logging
- [ ] Errors logged (without sensitive data)
- [ ] Crash reporting (if integrated)
- [ ] Analytics events tracked

### Release Preparation
- [ ] Version number correct
- [ ] App icons set
- [ ] Splash screen configured
- [ ] Proper signing for release
- [ ] ProGuard/R8 configured
- [ ] App size optimized

---

## Test Results Summary

**Date Tested:** _____________  
**Tester:** _____________  
**Device:** _____________  
**Android Version:** _____________  
**App Version:** _____________  

**Pass Rate:** _____ / _____ tests passed

**Critical Issues Found:**

**Minor Issues Found:**

**Notes:**
