# Quick Start: Card System API

## Prerequisites
Backend must be running on `http://localhost:8000`

## Authentication
All user endpoints require JWT token in header:
```
Authorization: Bearer YOUR_TOKEN_HERE
```

Get token from `/login` endpoint.

---

## 🔥 Quick Test Commands

### 1. Register & Login
```bash
# Register
curl -X POST http://localhost:8000/signup \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "Test123!",
    "email": "test@example.com",
    "phone": "+15551234567",
    "full_name": "Test User"
  }'

# Login
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "password": "Test123!"}'
```

**Response:** Save the `access_token` from response!

---

### 2. Add Funds (Admin)
```bash
curl -X POST http://localhost:8000/admin/add-funds \
  -H "Content-Type: application/json" \
  -d '{"username": "testuser", "amount": 1000.00}'
```

---

### 3. Create Virtual Card
```bash
curl -X POST http://localhost:8000/api/cards/create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"card_type": "virtual", "network": "visa"}'
```

**Response:**
```json
{
  "message": "Card created successfully",
  "card": {
    "id": 1,
    "card_number": "4532123456789012",
    "cvv": "123",
    "expiry_month": 11,
    "expiry_year": 2029,
    "network": "visa",
    "daily_limit": 1000.0,
    "transaction_limit": 500.0
  }
}
```

---

### 4. List Your Cards
```bash
curl -X GET http://localhost:8000/api/cards/list \
  -H "Authorization: Bearer YOUR_TOKEN"
```

---

### 5. Register POS Terminal
```bash
curl -X POST http://localhost:8000/api/pos/register-terminal \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "terminal_name": "Store Counter #1",
    "location_name": "Main Street Store",
    "address": "123 Main St"
  }'
```

**Response:** Save the `api_key` and `api_secret`!

---

### 6. Process POS Payment
```bash
curl -X POST http://localhost:8000/api/pos/process-payment \
  -H "Content-Type: application/json" \
  -d '{
    "terminal_id": "YOUR_TERMINAL_ID",
    "api_key": "YOUR_API_KEY",
    "card_number": "4532123456789012",
    "amount": 45.99,
    "entry_mode": "contactless",
    "merchant_name": "Main Street Store",
    "cvv": "123"
  }'
```

---

### 7. ATM Withdrawal
```bash
curl -X POST http://localhost:8000/api/atm/withdraw \
  -H "Content-Type: application/json" \
  -d '{
    "card_number": "4532123456789012",
    "pin": "1234",
    "amount": 100.00,
    "atm_id": "ATM001",
    "atm_location": "Bank of America"
  }'
```

---

### 8. Generate Gift Card
```bash
curl -X POST http://localhost:8000/api/gift-cards/generate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50.00,
    "quantity": 1,
    "card_type": "digital"
  }'
```

---

### 9. Check Gift Card Balance
```bash
curl -X GET http://localhost:8000/api/gift-cards/balance/CARD_NUMBER_HERE
```

---

### 10. Redeem Gift Card
```bash
curl -X POST http://localhost:8000/api/gift-cards/redeem \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "card_number": "1234567890123456",
    "pin": "1234"
  }'
```

---

### 11. Use Gift Card at Merchant
```bash
curl -X POST http://localhost:8000/api/gift-cards/use \
  -H "Content-Type: application/json" \
  -d '{
    "card_number": "1234567890123456",
    "pin": "1234",
    "amount": 25.50,
    "merchant_name": "Online Store"
  }'
```

---

### 12. Send to External Wallet
```bash
curl -X POST http://localhost:8000/api/cross-wallet/send \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "wallet_provider": "venmo",
    "recipient_identifier": "@username",
    "amount": 50.00
  }'
```

Supported wallets: `venmo`, `cashapp`, `paypal`, `zelle`

---

### 13. Get Supported Wallets
```bash
curl -X GET http://localhost:8000/api/cross-wallet/supported
```

---

### 14. Get Card Transaction History
```bash
curl -X GET http://localhost:8000/api/cards/1/transactions \
  -H "Authorization: Bearer YOUR_TOKEN"
```

(Replace `1` with your card ID)

---

### 15. Update Card Limits
```bash
curl -X POST http://localhost:8000/api/cards/update-limits \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "card_id": 1,
    "daily_limit": 2000.00,
    "transaction_limit": 1000.00
  }'
```

---

### 16. Freeze/Unfreeze Card
```bash
# Freeze
curl -X POST http://localhost:8000/api/cards/freeze \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"card_id": 1, "freeze": true}'

# Unfreeze
curl -X POST http://localhost:8000/api/cards/freeze \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"card_id": 1, "freeze": false}'
```

---

## 🧪 Run Automated Test Suite

```bash
cd ewallet_backend
python test_card_system.py
```

This will run all 14 test steps automatically!

---

## 📚 API Documentation

Interactive docs available at:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 🔐 Security Notes

1. **Never share CVV**: Only shown once on card creation
2. **Store tokens securely**: JWT tokens should be encrypted
3. **Use HTTPS in production**: All API calls must be over SSL
4. **Rotate API keys**: POS terminal keys should be rotated regularly
5. **Monitor fraud scores**: Set up alerts for high-risk transactions

---

## 🚨 Common Errors

### "Invalid token"
- Token expired (24 hour lifetime)
- Need to login again

### "Insufficient funds"
- User wallet balance too low
- Add funds via admin endpoint or Stripe deposit

### "Card frozen"
- Card was manually frozen
- Unfreeze using `/api/cards/freeze` endpoint

### "Transaction declined - high risk"
- Fraud detection triggered
- Risk score > 80
- Check transaction amount, velocity, merchant

### "Daily limit exceeded"
- User hit daily spending limit
- Wait until next day or increase limit

---

## 💡 Pro Tips

1. **Test with small amounts first** ($1-10)
2. **Use contactless for faster approvals**
3. **Keep PIN secure** - needed for ATM withdrawals
4. **Monitor transaction history** for fraud
5. **Freeze cards immediately** if lost/stolen

---

## 🎯 Integration Checklist

For integrating into Flutter app:

- [ ] Create auth service to get/store JWT tokens
- [ ] Build card list UI (shows card number, expiry, balance)
- [ ] Create card detail screen (flip animation for CVV)
- [ ] Add "Create Card" button
- [ ] Implement freeze/unfreeze toggle
- [ ] Show transaction history per card
- [ ] Add gift card redemption screen
- [ ] Build external wallet send form
- [ ] Add loading states and error handling
- [ ] Implement biometric auth for sensitive operations

---

## 📞 Need Help?

Check the comprehensive guide: `CARD_SYSTEM_COMPLETE.md`
