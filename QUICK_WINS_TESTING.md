# Quick Wins Testing Guide

## 🚀 Quick Start

### Prerequisites
✅ Backend running on `http://localhost:8000`
✅ Flutter app connected to your device/emulator
✅ User account created and logged in

## Testing Workflow

### 1. Access Quick Features
1. Open BlackWallet app
2. Tap the **Menu** icon (☰) in top-right
3. Select **"Quick Features"**
4. You'll see 3 tabs: Favorites, Scheduled, Links

---

## Feature Tests

### ⭐ Test 1: Favorites System

**Add a Favorite:**
1. Go to "Quick Features" → Favorites tab
2. Should see empty state initially
3. Currently, favorites are added when you send money (integration pending)

**Expected Behavior:**
- Empty state message: "No favorites yet"
- Later: List of saved recipients with usage counts

---

### 📅 Test 2: Scheduled Payments

**Create One-Time Payment:**
1. Go to "Quick Features" → Scheduled tab
2. Tap **"+ Schedule Payment"** button
3. Fill in:
   - Amount: `50.00`
   - Recipient: Your wallet ID or email
   - Schedule Date: Tomorrow at 10:00 AM
   - Recurring: OFF
4. Tap **"Schedule"**

**Expected Result:**
- Payment appears in list
- Shows "Next: [Tomorrow 10:00 AM]"
- Shows amount and recipient

**Create Recurring Payment:**
1. Tap **"+ Schedule Payment"** again
2. Fill in:
   - Amount: `25.00`
   - Recipient: Your wallet ID
   - Schedule Date: Today at current time + 2 minutes
   - Recurring: ON
   - Frequency: Daily
3. Tap **"Schedule"**

**Expected Result:**
- Payment appears with "Recurring: Daily"
- Background processor will execute in 2 minutes

**Cancel Payment:**
1. Find a scheduled payment
2. Tap **"Cancel"** button
3. Confirm cancellation

**Expected Result:**
- Payment removed from list
- Shows success message

---

### 🔗 Test 3: Payment Links

**Create Payment Link:**
1. Go to "Quick Features" → Links tab
2. Tap **"+ Create Link"** button
3. Fill in:
   - Amount: `100.00` (optional - leave blank for any amount)
   - Description: `Test Payment Link`
   - Expires: Select tomorrow
   - Max Uses: `5`
4. Tap **"Create"**

**Expected Result:**
- Link appears in list
- Shows link code (e.g., `PL-ABC123`)
- Shows 0 uses, $0 collected

**Share Link:**
1. Tap **"Share"** button on the link
2. Copy the link code
3. Share via any platform

**Pay via Link (Test as different user or same user):**
1. In payment link details or create a test endpoint
2. Enter the link code
3. Enter amount (if not fixed)
4. Complete payment

**Expected Result:**
- Link shows 1 use
- Total collected updates
- Payer receives confirmation

---

### 🔍 Test 4: Transaction Search

**Access Search:**
1. From wallet screen menu, select **"Search Transactions"**
2. Should see search bar and filter button

**Test Text Search:**
1. Type recipient name or wallet ID in search box
2. Tap search

**Expected Result:**
- Shows transactions matching search term
- Updates in real-time

**Test Filters:**
1. Tap **"Filter"** button
2. Set **Amount Range:**
   - Min: `10`
   - Max: `100`
3. Select **Date Range:**
   - Start: Last week
   - End: Today
4. Select **Transaction Type:** "Sent"
5. Tap **"Apply Filters"**

**Expected Result:**
- Filter chips appear above results
- Shows only sent transactions between $10-$100 in date range
- Can remove filters by tapping X on chips

**Test Clear Filters:**
1. Tap **"Clear All"** button

**Expected Result:**
- All filter chips removed
- Shows all transactions

---

## Backend Testing

### Test Scheduled Payment Processor

**Start the processor:**
```bash
cd ewallet_backend
python process_scheduled_payments.py
```

**Expected Output:**
```
INFO:__main__:Scheduled payment processor started
INFO:__main__:Checking for pending payments...
INFO:__main__:Found 1 pending payment(s) to process
INFO:__main__:Processing payment ID 1: $25.00 to user_123
INFO:__main__:✅ Payment executed successfully
INFO:__main__:Next check in 60 seconds...
```

**Test Automatic Execution:**
1. Create a scheduled payment for 2 minutes from now
2. Wait for processor to execute it
3. Check transaction history - should see the payment
4. Refresh scheduled payments - should show next execution time (if recurring)

---

### API Testing (Manual)

**Test with curl (requires auth token):**

```bash
# Get your auth token first
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"your_wallet_id","password":"your_password"}'

# Save the token from response
export TOKEN="your_token_here"

# Test Favorites
curl http://localhost:8000/api/favorites \
  -H "Authorization: Bearer $TOKEN"

# Test Scheduled Payments
curl http://localhost:8000/api/scheduled-payments \
  -H "Authorization: Bearer $TOKEN"

# Test Payment Links
curl http://localhost:8000/api/payment-links \
  -H "Authorization: Bearer $TOKEN"

# Test Transaction Search
curl -X POST http://localhost:8000/api/transactions/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"test","min_amount":10,"max_amount":100}'
```

---

## Integration Tests (Next Phase)

### Test 5: Add to Favorites (When Integrated)

1. Go to **Send Money** screen
2. Enter recipient details
3. Look for ⭐ **"Add to Favorites"** button
4. Tap to save recipient
5. Go to Quick Features → Favorites
6. Verify recipient appears

### Test 6: Schedule from Send Money (When Integrated)

1. Go to **Send Money** screen
2. Check **"Schedule this payment"** checkbox
3. Select date/time and recurrence
4. Send money
5. Go to Quick Features → Scheduled
6. Verify payment appears

### Test 7: QR Limit Enforcement (When Integrated)

**Set Limits:**
1. API call to set limits (UI pending):
```bash
curl -X POST http://localhost:8000/api/qr-limits/update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "max_per_transaction": 500.00,
    "daily_limit": 2000.00,
    "require_auth_above": 100.00
  }'
```

**Test Limit Enforcement:**
1. Go to **Scan QR** screen
2. Scan a QR code for amount > $500
3. Should see error: "Amount exceeds per-transaction limit"

**Test Biometric Requirement:**
1. Scan QR for amount > $100 but < $500
2. Should prompt for biometric authentication
3. Complete authentication
4. Payment proceeds

**Test Daily Limit:**
1. Make multiple QR payments totaling > $2000 in one day
2. Next payment should be blocked
3. Should see error: "Daily limit reached"

---

## Performance Tests

### Load Testing
- Create 100+ favorites
- Create 50+ scheduled payments
- Create 20+ payment links
- Search 1000+ transactions

**Expected:**
- UI remains responsive
- Search returns results < 1 second
- Lists scroll smoothly
- Pull-to-refresh works

---

## Edge Cases

### Test Error Handling

**Scheduled Payment - Insufficient Balance:**
1. Schedule payment for $1000
2. Keep balance < $1000
3. Wait for execution time
4. Check logs - should show "Insufficient balance" error
5. Payment should remain active for retry

**Payment Link - Expired:**
1. Create link with expiry = yesterday
2. Try to pay via link
3. Should see "Payment link expired" error

**Payment Link - Max Uses Reached:**
1. Create link with max_uses = 1
2. Pay once successfully
3. Try to pay again
4. Should see "Payment link no longer active" error

**Search - No Results:**
1. Search for non-existent recipient
2. Should show "No transactions found" message

---

## Success Criteria

✅ **Favorites**
- Can view favorites list
- Shows usage count and last used date
- Can remove favorites
- Empty state displayed correctly

✅ **Scheduled Payments**
- Can create one-time and recurring payments
- Payments appear in list with correct details
- Can cancel payments
- Background processor executes payments
- Recurring payments reschedule correctly

✅ **Payment Links**
- Can create links with various configurations
- Link codes are unique
- Can share links
- Payment via link works
- Usage tracking accurate
- Expired/max-use enforcement works

✅ **Transaction Search**
- Text search works
- All filters apply correctly
- Filter chips display and removable
- Results update in real-time
- Performance is good with many transactions

---

## Known Issues / Limitations

1. **Favorites** - Currently no UI to add favorites (needs send money integration)
2. **Sub-Wallets** - Backend ready but no dedicated UI screen yet
3. **Transaction Tags** - Backend ready but no UI to add tags
4. **QR Limits** - Backend ready but not integrated into scan QR flow
5. **Background Processor** - Needs to run as separate service (not auto-start)

---

## Troubleshooting

### "Backend not responding"
```bash
# Check if backend is running
curl http://localhost:8000/

# If not running, start it
cd ewallet_backend
python run_server.py
```

### "Table doesn't exist" errors
```bash
# Run migration again
cd ewallet_backend
python migrate_quick_wins.py
```

### "Authentication failed"
- Ensure you're logged in
- Check token is valid
- Try logging out and back in

### Scheduled payments not executing
```bash
# Check if processor is running
# If not, start it
cd ewallet_backend
python process_scheduled_payments.py
```

### Search returns no results
- Verify you have transactions in database
- Check search term matches transaction data
- Try clearing all filters

---

## Next Steps After Testing

1. **Report Bugs** - Document any issues found
2. **Suggest Improvements** - UX/UI feedback
3. **Integration** - Complete send money enhancements
4. **Production** - Deploy background processor as service
5. **Documentation** - Update user guide with Quick Wins features

---

**Happy Testing! 🎉**

For issues or questions, refer to `QUICK_WINS_COMPLETE.md` for implementation details.
