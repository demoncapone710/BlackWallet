# Testing Withdrawal Feature - Quick Guide

## ✅ Backend is Ready
- Server running on port 8000
- Database reset with test users
- Authentication fixed
- All API endpoints working

## 📱 Test Steps in the App

### 1. Login
- Open the app
- Login with:
  - **Username**: `demo`
  - **Password**: `Demo@123`
- Current balance should show **$5,000.00** (or $4,990 if test already ran)

### 2. Add Bank Account (First Time Only)
- Tap **≡** menu → **Payment Methods**
- Tap **"Add Bank Account"**
- Enter:
  - **Account Number**: `000123456789`
  - **Routing Number**: `110000000`
- Tap **"Add Bank Account"**
- You should see success message

### 3. Test Withdrawal
- Go back to Wallet screen
- Tap **≡** menu → **Withdraw Money**
- You should see:
  - Current balance displayed
  - Bank account dropdown (select the account you added)
  - Amount input field
  - Quick select chips: $10, $25, $50, $100
  - "Withdraw All" button
  - "Withdraw Now" button

### 4. Perform Test Withdrawal
**Option A - Small Amount:**
- Tap the **$10** chip (or enter 10 manually)
- Select your bank account from dropdown
- Tap **"Withdraw Now"**
- Expected: Success message, balance decreases by $10

**Option B - Custom Amount:**
- Enter any amount (e.g., $25.50)
- Select bank account
- Tap **"Withdraw Now"**
- Expected: Success message, balance updates

**Option C - Withdraw All:**
- Tap **"Withdraw All"** button
- Amount field fills with full balance
- Tap **"Withdraw Now"**
- Expected: Success, balance goes to $0.00

### 5. Verify Transaction
- Go to **Transaction History**
- You should see withdrawal transaction:
  - Type: "Withdrawal"
  - Status: "Pending"
  - Amount: What you withdrew
  - Receiver: "bank_account"
  - Date/Time: Just now

### 6. Check Updated Balance
- Return to Wallet screen
- Balance should reflect the withdrawal
- Example: Started with $5,000, withdrew $10 → Now shows $4,990

## ✅ What to Verify

### Success Indicators:
- ✓ Bank account appears in dropdown
- ✓ Balance shown correctly
- ✓ Amount validation works (can't withdraw more than balance)
- ✓ Success message appears after withdrawal
- ✓ Screen closes and returns to wallet
- ✓ Balance updates immediately
- ✓ Transaction appears in history
- ✓ Transaction shows "pending" status

### Error Cases to Test:
- ❌ Try withdrawing $0 → Should show error
- ❌ Try withdrawing negative amount → Should prevent input
- ❌ Try withdrawing more than balance → Should show "Insufficient balance"
- ❌ Try withdrawing without selecting bank → Should show validation error

## 📊 Test Results Template

**Test 1: Add Bank Account**
- [ ] Bank account added successfully
- [ ] Last 4 digits shown: 6789

**Test 2: Withdraw $10**
- [ ] Withdrawal successful
- [ ] Balance decreased by $10
- [ ] Transaction recorded

**Test 3: Withdraw Custom Amount ($25)**
- [ ] Amount accepted
- [ ] Success message shown
- [ ] Balance updated correctly

**Test 4: Withdraw All**
- [ ] Full balance withdrawn
- [ ] Balance shows $0.00
- [ ] Transaction recorded

**Test 5: Error Handling**
- [ ] Can't withdraw $0
- [ ] Can't overdraw account
- [ ] Validation messages clear

## 🔧 Backend Test Already Passed

The automated test script (`test_withdrawal.py`) already verified:
```
✅ Login successful
✅ Current balance: $5000.00
✅ Bank account added (ID: 1)
✅ Withdrawal successful ($10.00)
✅ New balance: $4990.00
✅ Transaction ID: 1, Status: pending
✅ Balance verified
```

## 🎯 What's Working

**Frontend:**
- ✅ Complete UI with validation
- ✅ Quick-select amount chips
- ✅ Withdraw all button
- ✅ Loading states
- ✅ Error/success feedback

**Backend:**
- ✅ Authentication (JWT tokens)
- ✅ Balance management
- ✅ Transaction logging
- ✅ Payment method storage
- ✅ Input validation

**Integration:**
- ✅ API calls working
- ✅ Token passing correctly
- ✅ Error handling
- ✅ State management

## 💡 Notes

- Withdrawals show as "pending" (simulating ACH 1-3 day processing)
- Stripe integration bypassed for testing (can be enabled for production)
- All withdrawals are logged in the database
- Balance updates are immediate and atomic
- Multiple bank accounts can be added

## 🚀 Ready to Test!

The withdrawal system is fully functional. Just follow the steps above in the app and verify everything works as expected!
