# Testing Guide - Real Money System

## 🧪 Complete Test Scenarios

### Test 1: New User Signup with Auto Stripe Account

**Steps:**
1. Open app → Go to signup screen
2. Enter: username, email, password
3. Tap "Sign Up"

**Expected Results:**
- ✓ Account created successfully
- ✓ Backend logs show: "Stripe account created: acct_..."
- ✓ User has `stripe_account_id` in database
- ✓ Response includes `stripe_account_created: true`

**Test Data:**
```
Username: testuser123
Email: test@example.com
Password: Test1234!
```

**Backend Check:**
```sql
SELECT stripe_account_id FROM users WHERE username = 'testuser123';
-- Should return: acct_xxxxxxxxxxxxx
```

---

### Test 2: Stripe Onboarding Flow

**Prerequisites:**
- User must be logged in
- Stripe account auto-created (Test 1)

**Steps:**
1. Navigate to Settings/Profile → Stripe Setup
2. Tap "Start Onboarding"
3. System opens Stripe onboarding in browser
4. Complete Stripe onboarding form:
   - Business type: Individual
   - Name: Test User
   - Email: test@example.com
   - Phone: +1 555-123-4567
   - DOB: 01/01/1990
   - SSN: 000-00-0000 (test mode)
   - Address: 123 Test St, City, ST 12345
5. Submit and return to app
6. Check account status

**Expected Results:**
- ✓ Onboarding link generated
- ✓ Browser opens successfully
- ✓ Form submits without errors
- ✓ Account status shows "connected: true"
- ✓ Charges enabled: true
- ✓ Payouts enabled: true

**API Endpoint Test:**
```bash
curl -X POST http://localhost:8000/api/stripe-connect/onboarding-link \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_url": "http://localhost:8000/stripe/refresh",
    "return_url": "http://localhost:8000/stripe/return"
  }'
```

---

### Test 3: Add Bank Account

**Prerequisites:**
- User logged in
- Stripe onboarding complete

**Steps:**
1. Settings → Bank Accounts
2. Tap "Add Bank Account"
3. Enter test bank details:
   - Routing Number: 110000000
   - Account Number: 000123456789
   - Account Holder Name: Test User
4. Submit

**Expected Results:**
- ✓ Bank account added successfully
- ✓ Shows in bank accounts list
- ✓ Display format: "Test Bank ****6789"
- ✓ Status: "verified" or "new"

**Test Routing Numbers:**
```
110000000 - Standard test routing
021000021 - Chase (test)
011401533 - Wells Fargo (test)
```

**API Endpoint Test:**
```bash
curl -X GET http://localhost:8000/api/stripe-connect/bank-accounts \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### Test 4: Real Money Deposit

**Prerequisites:**
- User logged in
- Stripe onboarding complete
- Note starting balance

**Steps:**
1. Go to Wallet screen
2. Tap "Add Money" / "Deposit"
3. Select amount: $100.00 (or use quick button)
4. Tap "Add Money"
5. Stripe payment sheet appears
6. Enter test card:
   - Card: 4242 4242 4242 4242
   - Exp: Any future date (e.g., 12/25)
   - CVC: Any 3 digits (e.g., 123)
   - ZIP: Any 5 digits (e.g., 12345)
7. Tap "Pay"
8. Confirm payment

**Expected Results:**
- ✓ Payment sheet opens smoothly
- ✓ Card accepted
- ✓ Success message shown
- ✓ Balance updates instantly (+$100)
- ✓ Transaction appears in history
- ✓ Transaction type: "deposit"
- ✓ Status: "completed"

**Test Cards:**
```
Success:
4242 4242 4242 4242 - Visa

Failure Cases:
4000 0000 0000 0002 - Declined
4000 0000 0000 9995 - Insufficient funds
4000 0000 0000 0069 - Expired card
```

**API Endpoint Test:**
```bash
# Create deposit intent
curl -X POST http://localhost:8000/api/stripe-connect/deposit-intent \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100.00
  }'

# Confirm deposit
curl -X POST http://localhost:8000/api/stripe-connect/deposit \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100.00,
    "payment_intent_id": "pi_xxxxxxxxxxxxx"
  }'
```

---

### Test 5: Real Money Withdrawal

**Prerequisites:**
- User logged in
- Has balance (Test 4)
- Bank account added (Test 3)
- Note starting balance

**Steps:**
1. Go to Wallet screen
2. Tap "Cash Out" / "Withdraw"
3. Select bank account from dropdown
4. Enter amount: $50.00
5. Tap "Withdraw"
6. Review confirmation:
   - Amount: $50.00
   - Bank: Test Bank ****6789
   - Arrival: 2-3 business days
7. Tap "Confirm"

**Expected Results:**
- ✓ Bank accounts load in dropdown
- ✓ Amount validation works (can't exceed balance)
- ✓ Confirmation dialog shows details
- ✓ Success dialog with transaction ID
- ✓ Balance updates instantly (-$50)
- ✓ Transaction in history
- ✓ Type: "withdrawal"
- ✓ Status: "pending" or "processing"
- ✓ Stripe payout created

**Validation Tests:**
```
Test 5a: Withdraw more than balance
- Amount: $9999.00
- Expected: Error "Insufficient balance"

Test 5b: Withdraw $0
- Amount: $0.00
- Expected: Error "Amount must be positive"

Test 5c: Withdraw all
- Click "All" button
- Expected: Amount = current balance
```

**API Endpoint Test:**
```bash
curl -X POST http://localhost:8000/api/stripe-connect/withdraw \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50.00,
    "bank_account_id": "ba_xxxxxxxxxxxxx"
  }'
```

---

### Test 6: User-to-User Transfer

**Prerequisites:**
- User A logged in with balance
- User B exists in system
- Note both balances

**Steps:**
1. User A: Wallet → Send
2. Enter User B username/ID
3. Enter amount: $25.00
4. Add message (optional)
5. Tap "Send"
6. Confirm transfer

**Expected Results:**
- ✓ User B found in system
- ✓ Amount validated against balance
- ✓ Confirmation shows details
- ✓ User A balance: -$25.00
- ✓ User B balance: +$25.00
- ✓ Both see transaction in history
- ✓ Transaction links sender/receiver

**Test Users:**
```
User A:
Username: sender123
Balance: $100.00

User B:
Username: receiver456
Balance: $50.00

After transfer:
User A: $75.00
User B: $75.00
```

---

### Test 7: Offline Mode - Queue Transaction

**Prerequisites:**
- User logged in
- Has balance
- Another device nearby for NFC

**Steps:**
1. User A: Turn OFF Wi-Fi and Mobile Data
2. Settings → Verify "Offline Mode" enabled
3. Go to NFC Send
4. Tap devices together
5. Enter amount: $10.00
6. Complete NFC payment
7. Check queued transactions

**Expected Results:**
- ✓ App detects offline status
- ✓ Transaction queued locally
- ✓ Message: "Payment queued - will sync when online"
- ✓ Transaction shows "pending" status
- ✓ Stored in SharedPreferences
- ✓ Queue count shows "1 pending"
- ✓ Balance NOT deducted yet

**Offline Transaction Structure:**
```json
{
  "sender_id": 123,
  "receiver_id": 456,
  "amount": 10.00,
  "timestamp": "2024-01-08T12:00:00Z",
  "device_id": "unique-device-id-123",
  "type": "nfc_transfer"
}
```

**Check Queue:**
```dart
// In app console/debug
final count = await OfflineTransactionManager.getQueueCount();
print('Queued transactions: $count');
```

---

### Test 8: Offline Mode - Auto Sync

**Prerequisites:**
- Transaction queued (Test 7)
- User still logged in

**Steps:**
1. Turn ON Wi-Fi or Mobile Data
2. Wait up to 5 minutes (auto-sync)
3. OR manually trigger: Settings → Sync Now
4. Watch transaction process

**Expected Results:**
- ✓ App detects online status
- ✓ Auto-sync triggers within 5 min
- ✓ Transaction synced to server
- ✓ Server validates transaction
- ✓ Balances updated on both sides
- ✓ Transaction moves to "completed"
- ✓ Queue cleared
- ✓ Queue count: 0

**Sync Validation:**
- No duplicate transactions
- Correct sender/receiver
- Accurate amount
- Timestamp preserved
- Device ID tracked

**API Endpoint Test:**
```bash
curl -X POST http://localhost:8000/api/transaction-sync/sync-offline \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sender_id": 123,
    "receiver_id": 456,
    "amount": 10.00,
    "timestamp": "2024-01-08T12:00:00Z",
    "device_id": "unique-device-id-123"
  }'
```

---

### Test 9: Offline Mode - Batch Sync

**Prerequisites:**
- Multiple transactions queued
- User back online

**Steps:**
1. Queue 3+ transactions offline
2. Come back online
3. Trigger sync

**Expected Results:**
- ✓ All transactions synced together
- ✓ Batch endpoint called once
- ✓ Response shows success/failure per transaction
- ✓ Failed transactions stay in queue
- ✓ Successful ones removed
- ✓ All balances correct

**Batch Sync Test:**
```bash
curl -X POST http://localhost:8000/api/transaction-sync/sync-batch \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transactions": [
      {
        "sender_id": 123,
        "receiver_id": 456,
        "amount": 10.00,
        "timestamp": "2024-01-08T12:00:00Z",
        "device_id": "device-123"
      },
      {
        "sender_id": 123,
        "receiver_id": 789,
        "amount": 15.00,
        "timestamp": "2024-01-08T12:05:00Z",
        "device_id": "device-123"
      }
    ]
  }'
```

---

### Test 10: Transaction History

**Prerequisites:**
- Multiple transactions completed
- Mix of deposits, withdrawals, transfers

**Steps:**
1. Go to Wallet/History
2. View transaction list
3. Filter by type
4. Search by amount
5. View transaction details

**Expected Results:**
- ✓ All transactions listed
- ✓ Correct chronological order
- ✓ Each shows: type, amount, date, status
- ✓ Color coding by type
- ✓ Icons match transaction type
- ✓ Tap for full details
- ✓ Details show: sender, receiver, timestamp, ID

**Transaction Types:**
```
+ Deposit    - Green   - + icon
- Withdrawal - Blue    - $ icon
→ Sent       - Red     - → icon
← Received   - Green   - ← icon
⊗ Offline    - Orange  - ⊗ icon
```

---

## 🐛 Error Scenarios to Test

### Deposit Errors

**Test 10a: Card Declined**
- Card: 4000 0000 0000 0002
- Expected: "Payment declined - try another card"

**Test 10b: Insufficient Funds**
- Card: 4000 0000 0000 9995
- Expected: "Insufficient funds in account"

**Test 10c: Expired Card**
- Card: 4000 0000 0000 0069
- Expected: "Card has expired"

**Test 10d: Amount Too Low**
- Amount: $0.50
- Expected: "Minimum deposit is $1.00"

**Test 10e: Amount Too High**
- Amount: $15,000.00
- Expected: "Maximum deposit is $10,000.00"

### Withdrawal Errors

**Test 10f: Insufficient Balance**
- Balance: $10.00
- Withdrawal: $50.00
- Expected: "Insufficient wallet balance"

**Test 10g: No Bank Account**
- User hasn't added bank
- Expected: "Please add a bank account first"

**Test 10h: Unverified Account**
- Stripe onboarding incomplete
- Expected: "Complete account setup first"

### Offline Sync Errors

**Test 10i: Duplicate Transaction**
- Sync same transaction twice
- Expected: "Transaction already processed"

**Test 10j: Sender Balance Check**
- Queued $100, but only have $50
- Expected: "Insufficient balance to sync"

**Test 10k: Invalid User**
- Receiver doesn't exist
- Expected: "Receiver not found"

---

## 📊 Success Metrics

After all tests:

- [ ] 100% successful deposits
- [ ] 100% successful withdrawals
- [ ] No balance discrepancies
- [ ] All offline transactions synced
- [ ] No duplicate transactions
- [ ] All error cases handled
- [ ] UI responsive and smooth
- [ ] No crashes or freezes
- [ ] Proper error messages shown
- [ ] Transaction history accurate

---

## 🔍 Database Verification

After testing, verify database state:

```sql
-- Check users have Stripe accounts
SELECT username, stripe_account_id, balance 
FROM users 
WHERE stripe_account_id IS NOT NULL;

-- Check transaction counts
SELECT 
  status,
  COUNT(*) as count,
  SUM(amount) as total
FROM transactions
GROUP BY status;

-- Check for offline transactions
SELECT * FROM transactions 
WHERE is_offline = 1;

-- Verify balance integrity
SELECT 
  u.username,
  u.balance as wallet_balance,
  (
    SELECT COALESCE(SUM(amount), 0) 
    FROM transactions 
    WHERE receiver_id = u.id AND status = 'completed'
  ) -
  (
    SELECT COALESCE(SUM(amount), 0) 
    FROM transactions 
    WHERE sender_id = u.id AND status = 'completed'
  ) as calculated_balance
FROM users u;
```

---

## 🎯 Performance Tests

### Load Test: Multiple Deposits

1. Make 10 deposits rapidly
2. Verify all process correctly
3. Check for race conditions
4. Confirm balance accuracy

### Load Test: Batch Sync

1. Queue 50+ transactions offline
2. Sync all at once
3. Monitor sync time
4. Verify all succeed

### Stress Test: Concurrent Operations

1. Deposit + Withdraw + Transfer simultaneously
2. Verify no deadlocks
3. Check balance consistency
4. Confirm all transactions recorded

---

## 📝 Test Results Template

```
Test Suite: Real Money System
Date: _________
Tester: _________

Test 1: New User Signup         [ ] Pass [ ] Fail
Test 2: Stripe Onboarding       [ ] Pass [ ] Fail
Test 3: Add Bank Account        [ ] Pass [ ] Fail
Test 4: Deposit                 [ ] Pass [ ] Fail
Test 5: Withdrawal              [ ] Pass [ ] Fail
Test 6: Transfer                [ ] Pass [ ] Fail
Test 7: Queue Offline           [ ] Pass [ ] Fail
Test 8: Auto Sync               [ ] Pass [ ] Fail
Test 9: Batch Sync              [ ] Pass [ ] Fail
Test 10: Transaction History    [ ] Pass [ ] Fail

Error Tests:                    [ ] Pass [ ] Fail
Performance Tests:              [ ] Pass [ ] Fail
Database Verification:          [ ] Pass [ ] Fail

Notes:
_______________________________________________
_______________________________________________
```

---

## 🚀 Ready for Production?

Before going live:

- [ ] All tests pass
- [ ] No critical bugs
- [ ] Error handling complete
- [ ] UI polished
- [ ] Switch to live Stripe keys
- [ ] Update Stripe webhooks
- [ ] Test with real bank accounts
- [ ] Verify KYC requirements
- [ ] Review transaction limits
- [ ] Set up monitoring
- [ ] Prepare customer support docs
- [ ] Legal compliance check
