# Payment Integration Options for BlackWallet

## Overview
Multiple payment providers and methods to give users flexibility for deposits and withdrawals.

---

## 🏦 Payment Processors (Like Stripe)

### 1. **Stripe** (Current)
**Best for:** Credit/debit cards, ACH bank transfers, international payments

✅ **Pros:**
- Industry standard, trusted
- Excellent documentation
- Handles compliance (PCI, etc.)
- International support (135+ countries)
- Developer-friendly API
- Strong fraud detection

❌ **Cons:**
- 2.9% + 30¢ per transaction
- Instant payouts: 1.5% fee
- Need business verification

**Use Cases:** Primary payment processor for cards and bank accounts

---

### 2. **PayPal / Braintree**
**Best for:** PayPal balance transfers, Venmo integration

✅ **Pros:**
- Users can pay with PayPal balance
- Venmo integration available
- Well-known brand, trusted by users
- Buyer/seller protection
- International reach

❌ **Cons:**
- 2.9% + 30¢ per transaction
- Can freeze accounts without warning
- Longer dispute process
- More restrictions than Stripe

**Integration:**
```python
import braintree

gateway = braintree.BraintreeGateway(
    braintree.Configuration(
        environment=braintree.Environment.Production,
        merchant_id="your_merchant_id",
        public_key="your_public_key",
        private_key="your_private_key"
    )
)

# Create transaction
result = gateway.transaction.sale({
    "amount": "10.00",
    "payment_method_nonce": nonce_from_client,
    "options": {
        "submit_for_settlement": True
    }
})
```

---

### 3. **Square**
**Best for:** In-person cash deposits, point-of-sale integration

✅ **Pros:**
- Free POS hardware available
- Great for physical locations
- Cash App integration
- Simple pricing
- Same-day deposits available

❌ **Cons:**
- 2.6% + 10¢ in-person, 2.9% + 30¢ online
- Best for US/Canada/UK/Australia
- Less international reach than Stripe

**Use Cases:** Physical cash deposit kiosks, retail integration

---

### 4. **Plaid + Dwolla** (ACH Direct)
**Best for:** Bank account verification and ACH transfers

✅ **Pros:**
- Direct bank transfers (ACH)
- Much cheaper: 0.5% - 1% fee (max $5-10)
- Plaid verifies bank accounts instantly
- No credit card fees
- Better for larger amounts

❌ **Cons:**
- ACH takes 3-5 business days
- US bank accounts only
- More complex setup
- Needs both Plaid (verification) and Dwolla (transfer)

**Integration:**
```python
# Step 1: Plaid - Verify bank account
import plaid

client = plaid.Client(client_id='xxx', secret='xxx', environment='production')

# Get bank account info
exchange_response = client.Item.public_token.exchange(public_token)
access_token = exchange_response['access_token']

auth_response = client.Auth.get(access_token)
account = auth_response['accounts'][0]

# Step 2: Dwolla - Create customer and funding source
import dwollav2

client = dwollav2.Client(key='xxx', secret='xxx', environment='production')

customer = client.post('customers', {
    'firstName': 'John',
    'lastName': 'Doe',
    'email': 'john@example.com'
})

# Step 3: Transfer money
transfer = client.post('transfers', {
    'amount': {'value': '10.00', 'currency': 'USD'},
    'source': customer_funding_source,
    'destination': your_funding_source
})
```

**Pricing:**
- Plaid: $0.25 per verification
- Dwolla: 0.5% (max $5) per transfer

---

### 5. **Adyen**
**Best for:** International payments, multiple currencies

✅ **Pros:**
- 250+ payment methods worldwide
- One integration for all countries
- Best for international expansion
- Enterprise-level features
- Local payment methods (iDEAL, Alipay, etc.)

❌ **Cons:**
- Expensive: Setup fees + monthly fees
- Complex pricing structure
- Overkill for small businesses
- Longer onboarding

**Use Cases:** When expanding internationally

---

## 💵 Alternative Payment Methods

### 6. **Cash App for Business**
**Best for:** Peer-to-peer transfers, younger demographic

✅ **Pros:**
- Users can pay from Cash App balance
- Instant transfers
- Popular with Gen Z/Millennials
- $Cashtag for easy payments

❌ **Cons:**
- 2.75% fee for business accounts
- US only
- Less robust than traditional processors

**Integration:**
- Can use Cash App API for business payments
- Or instruct users to send to your $Cashtag manually

---

### 7. **Zelle for Business**
**Best for:** Bank-to-bank instant transfers

✅ **Pros:**
- FREE for users (no fees!)
- Instant transfers (seconds)
- Integrated with 1,700+ US banks
- High transaction limits ($2,500-5,000/day)

❌ **Cons:**
- US banks only
- No chargeback protection
- Less suited for business use
- Manual reconciliation needed

**Implementation:**
- Provide your business Zelle email/phone
- Users send money via their bank app
- You manually credit their wallet balance
- Good for larger deposits to avoid fees

---

### 8. **Cryptocurrency (Bitcoin, USDC, etc.)**
**Best for:** International transfers, tech-savvy users, avoiding fees

✅ **Pros:**
- Very low fees (< 1%)
- Instant or near-instant
- No banks needed
- International with no borders
- USDC stablecoin (pegged to USD)

❌ **Cons:**
- Volatility (except stablecoins)
- Regulatory uncertainty
- Users need crypto wallet
- Complex for average user

**Providers:**
- **Coinbase Commerce** - Accept crypto payments
- **BitPay** - Bitcoin payment processor
- **Circle** - USDC integration

**Integration Example:**
```python
# Using Coinbase Commerce
import coinbase_commerce

client = coinbase_commerce.Client(api_key='your_api_key')

charge = client.charge.create(
    name='Deposit to BlackWallet',
    description='Add funds to wallet',
    pricing_type='fixed_price',
    local_price={
        'amount': '10.00',
        'currency': 'USD'
    }
)
# User pays with crypto, you credit their balance
```

---

### 9. **Wire Transfers / ACH Credits**
**Best for:** Large deposits, business clients

✅ **Pros:**
- No percentage fees (flat $15-30)
- Great for large amounts ($1000+)
- Secure, traditional method
- High limits

❌ **Cons:**
- Slow (2-5 business days)
- Manual reconciliation needed
- User needs wire transfer details
- Not instant

**Implementation:**
- Display your bank account details
- Include unique reference number per user
- Match incoming wires to user accounts
- Semi-automated with banking API

---

### 10. **Mobile Money (International)**

#### **M-Pesa** (Africa - Kenya, Tanzania, etc.)
- Mobile phone-based money transfer
- No bank account needed
- Used by 50+ million users
- Instant transfers

#### **PayTM** (India)
- Digital wallet, huge user base
- UPI integration
- E-commerce payments

#### **PIX** (Brazil)
- Instant bank transfers
- FREE for consumers
- QR code based
- Government-backed

#### **GCash / PayMaya** (Philippines)
- Mobile wallets
- Cash in/out at retail locations

**Use Cases:** If expanding to these markets

---

### 11. **Gift Cards / Vouchers**
**Best for:** Non-bank users, gift giving, promotions

✅ **Pros:**
- No payment processor needed
- Sell at retail locations
- Great for gifting
- Promotional tool
- Regulatory simplicity

❌ **Cons:**
- Need physical/digital card system
- Distribution logistics
- Fraud risk with stolen cards

**Implementation:**
```python
# Generate voucher codes
import secrets

def generate_voucher(amount, count=1):
    codes = []
    for _ in range(count):
        code = secrets.token_hex(8).upper()  # e.g., "A1B2C3D4E5F6G7H8"
        
        voucher = VoucherCode(
            code=code,
            amount=amount,
            valid_until=datetime.utcnow() + timedelta(days=365)
        )
        db.add(voucher)
        codes.append(code)
    
    db.commit()
    return codes

# Redeem in app
@router.post("/redeem-voucher")
async def redeem_voucher(code: str, user: User):
    voucher = db.query(VoucherCode).filter(
        VoucherCode.code == code,
        VoucherCode.used == False
    ).first()
    
    if voucher:
        user.balance += voucher.amount
        voucher.used = True
        db.commit()
```

**Distribution:**
- Sell at convenience stores (like iTunes cards)
- Online purchase (email code)
- Partner with retail chains
- Promotional giveaways

---

### 12. **Check Deposits (Mobile)**
**Best for:** Traditional users, business checks

✅ **Pros:**
- Familiar for older demographics
- Accepts business checks
- No percentage fees

❌ **Cons:**
- Slow (3-7 days hold)
- Fraud risk
- Needs check imaging technology

**Providers:**
- **Mitek** - Mobile check capture SDK
- **Jack Henry** - Banking check processing
- **FIS** - Enterprise check solutions

---

### 13. **Direct Deposit / Payroll Integration**
**Best for:** Employees getting paid into BlackWallet

✅ **Pros:**
- Recurring deposits
- Direct from employer
- No fees
- Builds user engagement

❌ **Cons:**
- Need bank routing/account number
- Compliance requirements
- Users need to set up with employer

**Implementation:**
- Partner with a bank or use a BaaS provider
- Get unique routing + account numbers per user
- Funds flow to your partner bank
- Auto-credit user wallet balance

**Providers:**
- **Synapse** - BaaS, provides routing numbers
- **Treasury Prime** - Banking infrastructure
- **Unit.co** - Banking-as-a-Service

---

## 📊 Recommended Multi-Provider Strategy

### **Tier 1: Core (Launch)**
1. **Stripe** - Credit/debit cards, primary processor
2. **Manual Bank Transfer** - Wire/ACH for large amounts
3. **Admin Credits** - For testing, promotions

### **Tier 2: Growth (6 months)**
4. **Plaid + Dwolla** - Cheaper ACH for regular users
5. **Zelle** - Free instant transfers (manual)
6. **Gift Cards** - Retail distribution

### **Tier 3: Scale (1 year+)**
7. **PayPal/Venmo** - Alternative wallet
8. **International** - Pick based on target market
9. **Direct Deposit** - Via BaaS partner
10. **Crypto** - For international/tech users

---

## 💰 Cost Comparison

### Deposits (for $100):
| Method | User Cost | Business Cost | Speed |
|--------|-----------|---------------|-------|
| Stripe Card | Free | $2.90 + $0.30 = $3.20 | Instant |
| Stripe ACH | Free | $0.80 (0.8%) | 3-5 days |
| Plaid+Dwolla | Free | $0.75 | 3-5 days |
| PayPal | Free | $3.20 | Instant |
| Zelle | FREE | FREE | Instant |
| Wire Transfer | $15-30 | FREE | 2-5 days |
| Cash App | Free | $2.75 | Instant |
| Gift Card | Free | 5-10% wholesale | Instant |
| Crypto (USDC) | ~$0.50 | ~$0.50 | Minutes |

### Withdrawals (for $100):
| Method | User Cost | Business Cost | Speed |
|--------|-----------|---------------|-------|
| Stripe Instant | $1.50 | Included | Minutes |
| Stripe Standard | Free | $0.25 | 1-3 days |
| Dwolla ACH | Free | $0.50 | 3-5 days |
| Zelle | FREE | FREE | Instant |
| Check Mailing | Free | $2-5 | 5-7 days |
| Crypto | ~$0.50 | ~$0.50 | Minutes |

---

## 🔧 Implementation Priority

### Phase 1: Keep It Simple (Current)
```
✅ Stripe - Cards & Bank accounts
✅ User-to-user transfers (internal)
```

### Phase 2: Reduce Fees (Next)
```
Add: Plaid + Dwolla for ACH
Add: Zelle manual integration
Result: Save 75% on fees for bank transfers
```

### Phase 3: Expand Options (Later)
```
Add: PayPal/Venmo as alternative
Add: Gift cards for retail
Add: Manual wire transfer instructions
```

### Phase 4: Scale Features (Future)
```
Add: Direct deposit (via BaaS)
Add: International methods (based on market)
Add: Crypto for specific use cases
```

---

## 🎯 Best Combination for BlackWallet

**Recommended Stack:**

1. **Primary: Stripe**
   - Credit/debit cards (instant, 2.9% + 30¢)
   - Standard bank withdrawals (free, 1-3 days)
   - Instant withdrawals ($1.50, minutes)

2. **Cost Savings: Plaid + Dwolla**
   - Bank account deposits (0.5%, 3-5 days)
   - Save users money on large deposits
   - Better unit economics for you

3. **Free Option: Zelle (Semi-Manual)**
   - FREE instant transfers
   - Provide your business Zelle info
   - Manual reconciliation initially
   - Scale with automation later

4. **Retail: Gift Cards**
   - Physical/digital voucher codes
   - Sell at stores or online
   - No payment processor needed
   - Great for marketing

5. **Fallback: Wire Transfer**
   - For large amounts ($1000+)
   - Provide bank account details
   - Include unique reference code
   - Manual or API reconciliation

---

## 📝 Implementation Code

### Multi-Provider Service Structure

```python
# services/payment_providers.py

class PaymentProvider:
    """Base class for payment providers"""
    
    async def deposit(self, user_id: str, amount: float, method_id: str):
        raise NotImplementedError
    
    async def withdraw(self, user_id: str, amount: float, method_id: str):
        raise NotImplementedError

class StripeProvider(PaymentProvider):
    """Stripe implementation"""
    # Already implemented
    pass

class DwollaProvider(PaymentProvider):
    """Dwolla ACH implementation"""
    
    async def deposit(self, user_id: str, amount: float, method_id: str):
        client = dwollav2.Client(key=settings.DWOLLA_KEY, secret=settings.DWOLLA_SECRET)
        
        transfer = client.post('transfers', {
            'amount': {'value': str(amount), 'currency': 'USD'},
            'source': method_id,  # User's bank account
            'destination': settings.DWOLLA_MASTER_ACCOUNT
        })
        
        return transfer['id']
    
    async def withdraw(self, user_id: str, amount: float, method_id: str):
        # Similar implementation for withdrawals
        pass

class PaymentService:
    """Unified payment service that routes to appropriate provider"""
    
    providers = {
        'stripe_card': StripeProvider(),
        'stripe_ach': StripeProvider(),
        'dwolla_ach': DwollaProvider(),
        'manual_wire': ManualProvider(),
        'voucher': VoucherProvider(),
    }
    
    async def deposit(self, provider_type: str, **kwargs):
        provider = self.providers[provider_type]
        return await provider.deposit(**kwargs)
```

### Frontend Selection

```dart
// lib/screens/deposit_screen.dart

class DepositScreen extends StatefulWidget {
  @override
  _DepositScreenState createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  String selectedMethod = 'stripe_card';
  
  List<Map<String, dynamic>> depositMethods = [
    {
      'id': 'stripe_card',
      'name': 'Credit/Debit Card',
      'icon': Icons.credit_card,
      'fee': '2.9% + \$0.30',
      'speed': 'Instant',
    },
    {
      'id': 'dwolla_ach',
      'name': 'Bank Account (ACH)',
      'icon': Icons.account_balance,
      'fee': '0.5% (max \$5)',
      'speed': '3-5 days',
    },
    {
      'id': 'zelle',
      'name': 'Zelle',
      'icon': Icons.flash_on,
      'fee': 'FREE',
      'speed': 'Instant',
      'note': 'Send to our Zelle: wallet@blackwallet.com',
    },
    {
      'id': 'voucher',
      'name': 'Gift Card / Voucher',
      'icon': Icons.card_giftcard,
      'fee': 'FREE',
      'speed': 'Instant',
    },
    {
      'id': 'wire',
      'name': 'Wire Transfer',
      'icon': Icons.business,
      'fee': 'FREE (bank may charge)',
      'speed': '2-5 days',
      'note': 'Best for amounts over \$1,000',
    },
  ];
  
  // Build method selection UI
}
```

---

## 🚀 Quick Start: Add Dwolla ACH

Want to add cheaper ACH transfers right now? Here's the quick version:

1. **Sign up for Dwolla**: https://www.dwolla.com/
2. **Sign up for Plaid**: https://plaid.com/
3. **Install packages**:
```bash
pip install dwollav2 plaid-python
```

4. **Add to config.py**:
```python
DWOLLA_KEY = os.getenv("DWOLLA_KEY")
DWOLLA_SECRET = os.getenv("DWOLLA_SECRET")
PLAID_CLIENT_ID = os.getenv("PLAID_CLIENT_ID")
PLAID_SECRET = os.getenv("PLAID_SECRET")
```

5. **Create new endpoint**:
```python
@router.post("/link-bank-plaid")
async def link_bank_account(
    public_token: str,
    account_id: str,
    current_user: User = Depends(get_current_user)
):
    # Exchange public token for access token
    exchange_response = plaid_client.Item.public_token.exchange(public_token)
    access_token = exchange_response['access_token']
    
    # Get bank account details
    auth_response = plaid_client.Auth.get(access_token)
    account = next(a for a in auth_response['accounts'] if a['account_id'] == account_id)
    
    # Create Dwolla funding source
    # ... implementation
    
    return {"message": "Bank account linked"}
```

That's 70% cheaper than Stripe for bank transfers!

---

Want me to implement any of these methods? I recommend starting with **Plaid + Dwolla** for ACH - it'll save you tons on fees for users who don't need instant deposits!
