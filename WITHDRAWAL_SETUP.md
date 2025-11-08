# Withdrawal Functionality - Complete Setup Guide

## Overview
The BlackWallet withdrawal system allows users to transfer money from their BlackWallet balance to their linked bank accounts via ACH transfer.

## ✅ Components Already Implemented

### Backend (`ewallet_backend/`)

#### 1. **Models** (`models.py`)
- `PaymentMethod` model with fields:
  - `id`, `user_id`, `stripe_payment_method_id`
  - `method_type` (card | bank_account)
  - `last4`, `brand`, `is_default`, `created_at`

#### 2. **API Routes** (`routes/payment.py`)

**Add Bank Account:**
```python
POST /api/payment/payment-methods/bank
Body: {
  "account_number": "string",
  "routing_number": "string"
}
```

**Withdraw to Bank:**
```python
POST /api/payment/withdraw
Body: {
  "bank_account_id": "string",
  "amount": float
}
Returns: {
  "message": "Withdrawal initiated (typically 1-3 business days)",
  "new_balance": float,
  "transaction_id": int,
  "status": "pending"
}
```

**Get Payment Methods:**
```python
GET /api/payment/payment-methods
Returns: {
  "payment_methods": [{
    "id": int,
    "type": "bank_account" | "card",
    "last4": "string",
    "brand": "string",
    "is_default": boolean
  }]
}
```

**Delete Payment Method:**
```python
DELETE /api/payment/payment-methods/{payment_method_id}
```

### Frontend (`lib/`)

#### 1. **Withdraw Screen** (`screens/withdraw_screen.dart`)

Features:
- Display current balance
- Select from linked bank accounts dropdown
- Enter withdrawal amount with quick-select chips ($10, $25, $50, $100)
- "Withdraw All" option
- Input validation (positive amount, sufficient balance)
- Loading states during API calls
- Success/error feedback via SnackBars
- Informational notes about ACH transfer timing

#### 2. **API Service** (`services/api_service.dart`)

Methods:
```dart
Future<bool> withdrawToBank(String bankAccountId, double amount)
Future<bool> addBankAccount(String accountNumber, String routingNumber)
Future<List<Map<String, dynamic>>> getPaymentMethods()
```

#### 3. **Integration**
- Withdraw button in `wallet_screen.dart` menu
- Navigation to `WithdrawScreen` with current balance
- Returns to wallet and refreshes on successful withdrawal

## 📋 How It Works

### User Flow:

1. **User opens Withdraw screen**
   - Sees current balance
   - Sees list of linked bank accounts (or prompt to add one)

2. **User adds bank account** (if needed)
   - Goes to Payment Methods
   - Adds bank account with account number + routing number
   - Backend creates PaymentMethod record

3. **User initiates withdrawal**
   - Selects bank account from dropdown
   - Enters amount (or uses quick-select)
   - Taps "Withdraw Now"

4. **Backend processing**
   - Validates amount > 0 and ≤ balance
   - Deducts amount from user balance
   - Creates Transaction record (type="withdrawal", status="pending")
   - Returns success with new balance

5. **User receives confirmation**
   - SnackBar shows success message
   - Screen closes and returns to wallet
   - Balance updates automatically

### Backend Processing:

```python
# Withdrawal endpoint logic
1. Validate amount is positive
2. Check sufficient balance
3. Deduct from user balance
4. Create Transaction record:
   - sender: current_user.username
   - receiver: "bank_account"
   - amount: requested amount
   - transaction_type: "withdrawal"
   - status: "pending"
   - external_provider: "stripe"
   - extra_data: {"bank_account_id": "..."}
5. Commit to database
6. Return success response
```

## 🧪 Testing the Withdrawal System

### Prerequisites:
1. Backend server running on port 8000
2. Database with test users created
3. Flutter app compiled and running

### Test Script:
Run `ewallet_backend/test_withdrawal.py` to test:
1. Login as demo user
2. Get current balance
3. Get payment methods
4. Add bank account (if needed)
5. Execute withdrawal
6. Verify balance updated

### Manual Testing Steps:

1. **Login to app** with demo account (username: `demo`, password: `Demo@123`)

2. **Navigate to Withdraw**
   - Tap "Withdraw Money" from wallet menu

3. **Add Bank Account** (first time)
   - If no bank accounts, go to Payment Methods
   - Tap "Add Bank Account"
   - Enter:
     - Account Number: `000123456789`
     - Routing Number: `110000000`
   - Submit

4. **Test Withdrawal**
   - Return to Withdraw screen
   - Select bank account from dropdown
   - Enter amount: `$10.00`
   - Tap "Withdraw Now"
   - Verify success message appears
   - Verify screen closes
   - Check wallet - balance should decrease by $10

5. **Verify Transaction**
   - Check transaction history
   - Should show withdrawal transaction with:
     - Type: "withdrawal"
     - Status: "pending"
     - Amount: deducted amount
     - Receiver: "bank_account"

## 🔧 Current Status

### ✅ Fully Implemented:
- Backend withdrawal endpoint
- Payment method management (add, get, delete)
- Transaction recording
- Frontend withdraw screen with full UI
- API service methods
- Balance validation
- Error handling
- Loading states
- User feedback

### ⏸️ Simulated (Not Production-Ready):
- **Actual ACH transfer**: Currently simulated, would need:
  - Stripe Connect account setup
  - Bank account verification (micro-deposits)
  - Stripe Payouts API integration
  - Webhook handling for payout status

### 🚀 To Make Production-Ready:

1. **Stripe Integration:**
```python
# Replace simulated withdrawal with real Stripe payout
stripe.Payout.create(
    amount=amount_cents,
    currency="usd",
    destination=payment_method.stripe_payment_method_id,
    statement_descriptor="BlackWallet withdrawal"
)
```

2. **Bank Account Verification:**
```python
# Implement micro-deposit verification
stripe.BankAccount.verify(
    payment_method_id,
    amounts=[32, 45]  # User enters amounts from micro-deposits
)
```

3. **Webhook Handler:**
```python
@router.post("/webhooks/stripe")
async def stripe_webhook(request: Request):
    # Handle payout.paid, payout.failed events
    # Update transaction status accordingly
```

4. **Additional Validation:**
- Daily withdrawal limits
- Minimum withdrawal amount
- Business hours restrictions
- Fraud detection

## 📱 Current Testing State

**Backend:** ✅ Running on port 8000
**Database:** ⚠️ Needs users (run `reset_database.py`)
**Frontend:** ✅ Compiled and ready
**Withdrawal Flow:** ✅ Fully functional (simulated)

## 🎯 Next Steps

1. Ensure database has test users with balances
2. Test adding bank account through app
3. Test withdrawal with various amounts
4. Verify transaction recording
5. Test error cases (insufficient balance, invalid amounts)
6. Test "Withdraw All" functionality

## 💡 Key Features

- **Smart Validation:** Prevents negative amounts, overdrafts
- **Quick Select:** Fast amount entry with preset chips
- **Withdraw All:** One-tap to withdraw entire balance
- **Clear Feedback:** Detailed success/error messages
- **ACH Info:** User education about 1-3 day processing
- **Payment Method Management:** Easy bank account linking
- **Transaction History:** Full audit trail of all withdrawals

## 🔒 Security Notes

- All API endpoints require authentication (Bearer token)
- Bank account details encrypted in transit (HTTPS)
- Transaction records are immutable
- Balance updates are atomic (database transaction)
- Input validation on both frontend and backend

