# Real Payment Integration Guide

## Overview
This guide shows how to enable **REAL money transactions** in BlackWallet using Stripe Connect.

## What You Built

### 🎯 Current Features (Simulated)
- ✅ Local balance tracking
- ✅ Peer-to-peer transfers (simulated)
- ✅ Virtual card generation (not connected)
- ✅ Transaction history

### 💰 NEW Features (Real Money)
- ✅ Stripe Connect integration
- ✅ Bank account linking
- ✅ Real money transfers between users
- ✅ Wallet top-ups (add money from card/bank)
- ✅ Withdrawals (send money to bank)
- ✅ Payment tracking with Stripe IDs

---

## Setup Instructions

### Step 1: Get Stripe API Keys

1. **Sign up for Stripe**: https://dashboard.stripe.com/register
2. **Get your API keys**:
   - Go to https://dashboard.stripe.com/test/apikeys
   - Copy your "Secret key" (starts with `sk_test_`)
   - Copy your "Publishable key" (starts with `pk_test_`)

3. **Update `.env` file**:
```bash
# Your existing keys
STRIPE_SECRET_KEY=sk_test_YOUR_KEY_HERE
STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE

# Add webhook secret (for production)
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
```

### Step 2: Run Database Migration

```bash
cd ewallet_backend
python migrate_stripe_connect.py
```

This adds:
- `stripe_account_id` to users table
- `stripe_payment_id`, `stripe_transfer_id`, `stripe_payout_id` to transactions

### Step 3: Install Required Package

```bash
pip install stripe
```

### Step 4: Start Backend

```bash
cd ewallet_backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

---

## API Endpoints (How to Use)

### 1. Create Stripe Connect Account

**Endpoint**: `POST /api/real-payments/connect/create`

**What it does**: Creates a Stripe account for the user so they can receive money

```bash
curl -X POST http://localhost:8000/api/real-payments/connect/create \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"country": "US"}'
```

**Response**:
```json
{
  "message": "Stripe account created",
  "stripe_account_id": "acct_xxxxx",
  "next_step": "Complete onboarding via /connect/onboarding"
}
```

### 2. Get Onboarding Link

**Endpoint**: `GET /api/real-payments/connect/onboarding`

**What it does**: Returns a URL where user completes Stripe setup (ID, bank account, tax info)

```bash
curl http://localhost:8000/api/real-payments/connect/onboarding \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response**:
```json
{
  "onboarding_url": "https://connect.stripe.com/setup/xxxxx",
  "message": "Complete setup in browser"
}
```

### 3. Add Money to Wallet (Top-Up)

**Endpoint**: `POST /api/real-payments/topup`

**What it does**: Charges user's card and adds money to their wallet

```bash
curl -X POST http://localhost:8000/api/real-payments/topup \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50.00,
    "payment_method_id": "pm_xxxxx"
  }'
```

**Response**:
```json
{
  "message": "Money added to wallet",
  "new_balance": 150.00,
  "amount": 50.00,
  "transaction_id": 123
}
```

### 4. Send Real Money to Another User

**Endpoint**: `POST /api/real-payments/send`

**What it does**: Transfers REAL money from your Stripe balance to recipient's Stripe balance

```bash
curl -X POST http://localhost:8000/api/real-payments/send \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "recipient_username": "alice",
    "amount": 25.00,
    "note": "Lunch money"
  }'
```

**Response**:
```json
{
  "message": "Money sent successfully",
  "recipient": "alice",
  "amount": 25.00,
  "new_balance": 125.00,
  "transaction_id": 124,
  "stripe_transfer_id": "tr_xxxxx"
}
```

### 5. Withdraw to Bank Account

**Endpoint**: `POST /api/real-payments/withdraw`

**What it does**: Sends money from wallet to user's bank account (arrives in 2-3 business days)

```bash
curl -X POST http://localhost:8000/api/real-payments/withdraw \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100.00
  }'
```

**Response**:
```json
{
  "message": "Withdrawal initiated",
  "amount": 100.00,
  "new_balance": 25.00,
  "arrival_date": 1699574400,
  "status": "in_transit"
}
```

### 6. Check Account Status

**Endpoint**: `GET /api/real-payments/connect/status`

**What it does**: Checks if user can send/receive money

```bash
curl http://localhost:8000/api/real-payments/connect/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response**:
```json
{
  "setup_complete": true,
  "can_receive_payments": true,
  "can_withdraw": true,
  "pending_requirements": []
}
```

---

## How It Works

### Money Flow

```
1. TOP-UP (Add Money)
   User's Card/Bank → Stripe → Your Platform → User's Wallet Balance

2. SEND MONEY (P2P Transfer)
   Sender's Stripe Balance → Stripe Transfer → Recipient's Stripe Balance

3. WITHDRAW
   User's Wallet → Stripe Payout → User's Bank Account
```

### Architecture

```
┌─────────────┐
│   Your App  │
│  (Backend)  │
└──────┬──────┘
       │
       ↓
┌─────────────────┐
│  Stripe Connect │  ← Handles money movement
│   (Platform)    │
└────────┬────────┘
         │
    ┌────┴────┐
    ↓         ↓
┌──────┐  ┌──────┐
│User A│  │User B│  ← Each has Stripe Connect account
└──────┘  └──────┘
```

---

## Alternative: Create Your Own Payment API

If you don't want to use Stripe, you can create your own payment network:

### Option 1: Blockchain/Crypto
```python
# Use Ethereum, Solana, or similar
# Users send crypto tokens to each other
# You control the token contract
```

### Option 2: ACH Transfers via Plaid
```python
# Use Plaid to connect bank accounts
# Initiate ACH transfers (takes 1-3 days)
# Lower fees than Stripe
```

### Option 3: PayPal/Venmo
```python
# Integrate PayPal Payouts API
# Users can cash out to PayPal
# Simpler but less flexible
```

---

## Testing with Stripe Test Mode

Stripe provides test cards you can use:

### Test Card Numbers
- **Success**: `4242 4242 4242 4242`
- **Decline**: `4000 0000 0000 0002`
- **Insufficient funds**: `4000 0000 0000 9995`

### Test Bank Account
- **Routing**: `110000000`
- **Account**: `000123456789`

**Note**: In test mode, no real money moves. Perfect for development!

---

## Production Checklist

Before going live:

- [ ] Switch to Stripe live mode keys
- [ ] Set up webhook endpoints for payment notifications
- [ ] Implement proper error handling
- [ ] Add payment reconciliation
- [ ] Set up fraud detection
- [ ] Get proper business licenses
- [ ] Implement KYC (Know Your Customer) verification
- [ ] Add transaction fees
- [ ] Set up customer support
- [ ] Implement refund handling

---

## Fees

### Stripe Connect Fees (Standard Pricing)
- **Card payments**: 2.9% + $0.30 per transaction
- **ACH payments**: 0.8% (max $5)
- **Payouts**: $0.25 per payout
- **International**: +1% for currency conversion

### Your Platform Fees
You can charge additional fees:
```python
# Example: Charge 1% platform fee
platform_fee = amount * 0.01
stripe.Transfer.create(
    amount=amount_cents,
    destination=recipient_account,
    transfer_group=transaction_id,
    # Platform keeps this fee
    amount_to_capture=amount_cents - int(platform_fee * 100)
)
```

---

## Security Best Practices

1. **Never store card numbers**: Let Stripe handle it
2. **Use HTTPS**: Always encrypt API calls
3. **Validate webhooks**: Verify Stripe signatures
4. **Implement rate limiting**: Prevent abuse
5. **Log everything**: Track all money movements
6. **2FA for withdrawals**: Add extra security
7. **Fraud detection**: Monitor suspicious patterns

---

## Support

- **Stripe Docs**: https://stripe.com/docs/connect
- **Stripe Dashboard**: https://dashboard.stripe.com
- **Test Mode**: Use for development (no real money)
- **Live Mode**: Switch when ready for production

---

## What's Next?

### Immediate Next Steps:
1. Run migration: `python migrate_stripe_connect.py`
2. Get Stripe keys and add to `.env`
3. Test the `/connect/create` endpoint
4. Complete onboarding flow
5. Test money transfers

### Future Enhancements:
- Add instant payouts (higher fees)
- Support multiple currencies
- Add subscription payments
- Implement refunds
- Add dispute handling
- Create invoicing system
- Add recurring payments

---

## Questions?

The integration is ready to use! Test it with Stripe's test mode first. No real money will move until you switch to live keys.

**Ready to enable real payments?** Just run the migration and update your Stripe keys!
