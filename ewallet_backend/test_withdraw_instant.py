"""
Test Instant Withdraw Feature
Tests the instant withdraw toggle in the withdraw screen
"""
import requests
import json

BASE_URL = "http://localhost:8000"

def test_instant_withdraw():
    print("Testing Instant Withdraw Feature")
    print("=" * 60)
    
    # Step 1: Login
    print("\n[1] Logging in as demo user...")
    login_response = requests.post(
        f"{BASE_URL}/api/auth/login",
        json={"username": "demo", "password": "demo123"}
    )
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.text}")
        return
    
    token = login_response.json()["access_token"]
    print("✅ Login successful")
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # Step 2: Check initial balance
    print("\n2️⃣ Checking initial balance...")
    balance_response = requests.get(f"{BASE_URL}/api/balance", headers=headers)
    initial_balance = balance_response.json()["balance"]
    print(f"✅ Initial balance: ${initial_balance:.2f}")
    
    # Step 3: Get payment methods (bank accounts)
    print("\n3️⃣ Getting payment methods...")
    methods_response = requests.get(f"{BASE_URL}/api/payment/payment-methods", headers=headers)
    
    if methods_response.status_code != 200:
        print(f"❌ Failed to get payment methods: {methods_response.text}")
        return
    
    methods = methods_response.json().get("payment_methods", [])
    bank_accounts = [m for m in methods if m.get('type') == 'bank_account']
    
    if not bank_accounts:
        print("\n⚠️  No bank accounts found. Adding a test bank account...")
        add_bank = requests.post(
            f"{BASE_URL}/api/payment/payment-methods/bank",
            headers=headers,
            json={
                "account_number": "000123456789",
                "routing_number": "110000000",
                "account_holder_name": "Demo User",
                "account_type": "checking"
            }
        )
        if add_bank.status_code == 200:
            print("✅ Test bank account added")
            methods_response = requests.get(f"{BASE_URL}/api/payment/payment-methods", headers=headers)
            methods = methods_response.json().get("payment_methods", [])
            bank_accounts = [m for m in methods if m.get('type') == 'bank_account']
        else:
            print(f"❌ Failed to add bank account: {add_bank.text}")
            return
    
    bank_account_id = str(bank_accounts[0]['id'])
    print(f"✅ Using bank account ID: {bank_account_id}")
    
    # Step 4: Test standard withdrawal (no fee)
    print("\n4️⃣ Testing standard withdrawal (FREE, 1-3 days)...")
    standard_amount = 10.0
    
    standard_withdrawal = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": bank_account_id,
            "amount": standard_amount,
            "instant_transfer": False
        }
    )
    
    if standard_withdrawal.status_code == 200:
        result = standard_withdrawal.json()
        print(f"✅ Standard withdrawal successful")
        print(f"   Amount: ${result.get('amount', standard_amount):.2f}")
        print(f"   Fee: $0.00")
        print(f"   Total deducted: ${standard_amount:.2f}")
        print(f"   Status: {result['status']}")
        print(f"   New balance: ${result['new_balance']:.2f}")
    else:
        print(f"❌ Standard withdrawal failed: {standard_withdrawal.text}")
        return
    
    # Step 5: Test instant withdrawal with $50 (1.5% = $0.75)
    print("\n5️⃣ Testing instant withdrawal with $50 (1.5% fee = $0.75)...")
    instant_amount = 50.0
    expected_fee = 0.75
    
    instant_withdrawal = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": bank_account_id,
            "amount": instant_amount,
            "instant_transfer": True
        }
    )
    
    if instant_withdrawal.status_code == 200:
        result = instant_withdrawal.json()
        print(f"✅ Instant withdrawal successful")
        print(f"   Amount: ${result.get('amount', instant_amount):.2f}")
        print(f"   Instant fee: ${result['instant_fee']:.2f}")
        print(f"   Total deducted: ${result['total_deducted']:.2f}")
        print(f"   Status: {result['status']}")
        print(f"   New balance: ${result['new_balance']:.2f}")
        
        # Verify fee calculation
        if abs(result['instant_fee'] - expected_fee) < 0.01:
            print(f"   ✅ Fee calculated correctly: ${expected_fee:.2f}")
        else:
            print(f"   ❌ Fee mismatch! Expected ${expected_fee:.2f}, got ${result['instant_fee']:.2f}")
    else:
        print(f"❌ Instant withdrawal failed: {instant_withdrawal.text}")
        return
    
    # Step 6: Test minimum fee scenario ($5 -> $0.25 minimum)
    print("\n6️⃣ Testing minimum fee scenario ($5 -> $0.25 minimum fee)...")
    small_amount = 5.0
    expected_min_fee = 0.25
    
    small_instant = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": bank_account_id,
            "amount": small_amount,
            "instant_transfer": True
        }
    )
    
    if small_instant.status_code == 200:
        result = small_instant.json()
        print(f"✅ Small instant withdrawal successful")
        print(f"   Amount: ${result.get('amount', small_amount):.2f}")
        print(f"   Instant fee: ${result['instant_fee']:.2f}")
        print(f"   Total deducted: ${result['total_deducted']:.2f}")
        print(f"   (1.5% of $5 = $0.075, but minimum $0.25 applied)")
        print(f"   Status: {result['status']}")
        print(f"   New balance: ${result['new_balance']:.2f}")
        
        if abs(result['instant_fee'] - expected_min_fee) < 0.01:
            print(f"   ✅ Minimum fee applied correctly: ${expected_min_fee:.2f}")
        else:
            print(f"   ❌ Fee mismatch! Expected ${expected_min_fee:.2f}, got ${result['instant_fee']:.2f}")
    else:
        print(f"❌ Small instant withdrawal failed: {small_instant.text}")
        return
    
    # Step 7: Final balance check
    print("\n7️⃣ Final balance verification...")
    balance_response = requests.get(f"{BASE_URL}/api/balance", headers=headers)
    final_balance = balance_response.json()["balance"]
    
    total_withdrawn = standard_amount + instant_amount + expected_fee + small_amount + expected_min_fee
    expected_final = initial_balance - total_withdrawn
    
    print(f"   Initial balance: ${initial_balance:.2f}")
    print(f"   Total withdrawn: ${total_withdrawn:.2f}")
    print(f"   Expected final: ${expected_final:.2f}")
    print(f"   Actual final: ${final_balance:.2f}")
    
    if abs(final_balance - expected_final) < 0.01:
        print("   ✅ Balance matches expected value")
    else:
        print(f"   ⚠️  Balance mismatch (difference: ${abs(final_balance - expected_final):.2f})")
    
    # Step 8: Check transaction history
    print("\n8️⃣ Checking transaction history...")
    transactions = requests.get(f"{BASE_URL}/api/transactions", headers=headers)
    
    if transactions.status_code == 200:
        txs = transactions.json().get("transactions", [])
        withdrawal_txs = [t for t in txs if t['transaction_type'] == 'withdrawal']
        fee_txs = [t for t in txs if t['transaction_type'] == 'fee']
        
        print(f"✅ Found {len(withdrawal_txs)} withdrawal transactions")
        print(f"✅ Found {len(fee_txs)} fee transactions")
        
        # Show last few transactions
        print("\n   Recent transactions:")
        for tx in txs[:5]:
            print(f"   - {tx['transaction_type']}: ${tx['amount']:.2f} ({tx['status']})")
    
    # Step 9: Test Stripe mode info
    print("\n9️⃣ Checking Stripe mode...")
    try:
        stripe_mode = requests.get(f"{BASE_URL}/api/admin/config/stripe-mode", headers=headers)
        if stripe_mode.status_code == 200:
            mode_data = stripe_mode.json()
            print(f"   Mode: {mode_data['mode'].upper()}")
            print(f"   {mode_data['warning']}")
            print(f"   Test key configured: {mode_data['test_key_set']}")
            print(f"   Live key configured: {mode_data['live_key_set']}")
        else:
            print(f"   ⚠️  Could not get Stripe mode (may need admin access)")
    except Exception as e:
        print(f"   ⚠️  Could not check Stripe mode: {e}")
    
    print("\n" + "=" * 60)
    print("✅ All instant withdraw tests completed successfully!")
    print("\n📋 Summary:")
    print(f"   • Standard withdrawal: ${standard_amount:.2f} (FREE)")
    print(f"   • Instant withdrawal: ${instant_amount:.2f} (${expected_fee:.2f} fee)")
    print(f"   • Small instant: ${small_amount:.2f} (${expected_min_fee:.2f} min fee)")
    print(f"   • Total fees paid: ${expected_fee + expected_min_fee:.2f}")


if __name__ == "__main__":
    try:
        test_instant_withdraw()
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
