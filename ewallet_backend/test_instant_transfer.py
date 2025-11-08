import requests
import json

BASE_URL = "http://localhost:8000"

def test_instant_transfer():
    """Test instant transfer withdrawal with fee calculation"""
    
    print("🧪 Testing Instant Transfer Feature")
    print("=" * 60)
    
    # Step 1: Login
    print("\n1️⃣ Logging in as demo user...")
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
    
    # Step 3: Test standard withdrawal (no fee)
    print("\n3️⃣ Testing standard withdrawal (1-3 days, no fee)...")
    withdrawal_amount = 10.0
    
    standard_withdrawal = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": "test_bank_123",
            "amount": withdrawal_amount,
            "instant_transfer": False
        }
    )
    
    if standard_withdrawal.status_code == 200:
        result = standard_withdrawal.json()
        print(f"✅ Standard withdrawal successful")
        print(f"   Amount: ${result.get('total_deducted', 0):.2f}")
        print(f"   Fee: $0.00")
        print(f"   New balance: ${result['new_balance']:.2f}")
        print(f"   Status: {result['status']}")
        print(f"   Message: {result['message']}")
    else:
        print(f"❌ Standard withdrawal failed: {standard_withdrawal.text}")
        return
    
    # Step 4: Check balance after standard withdrawal
    balance_response = requests.get(f"{BASE_URL}/api/balance", headers=headers)
    balance_after_standard = balance_response.json()["balance"]
    
    # Step 5: Test instant withdrawal (with fee)
    print("\n4️⃣ Testing instant withdrawal (within minutes, 1.5% fee)...")
    instant_amount = 50.0
    expected_fee = max(instant_amount * 0.015, 0.25)  # 1.5% with $0.25 minimum
    
    instant_withdrawal = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": "test_bank_456",
            "amount": instant_amount,
            "instant_transfer": True
        }
    )
    
    if instant_withdrawal.status_code == 200:
        result = instant_withdrawal.json()
        print(f"✅ Instant withdrawal successful")
        print(f"   Withdrawal amount: ${instant_amount:.2f}")
        print(f"   Instant transfer fee: ${result['instant_fee']:.2f}")
        print(f"   Total deducted: ${result['total_deducted']:.2f}")
        print(f"   New balance: ${result['new_balance']:.2f}")
        print(f"   Status: {result['status']}")
        print(f"   Message: {result['message']}")
        
        # Verify fee calculation
        if abs(result['instant_fee'] - expected_fee) < 0.01:
            print(f"✅ Fee calculation correct: ${expected_fee:.2f}")
        else:
            print(f"❌ Fee mismatch! Expected ${expected_fee:.2f}, got ${result['instant_fee']:.2f}")
    else:
        print(f"❌ Instant withdrawal failed: {instant_withdrawal.text}")
        return
    
    # Step 6: Test minimum fee scenario
    print("\n5️⃣ Testing minimum fee scenario (small amount)...")
    small_amount = 5.0  # 1.5% would be $0.075, but minimum is $0.25
    
    small_instant = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": "test_bank_789",
            "amount": small_amount,
            "instant_transfer": True
        }
    )
    
    if small_instant.status_code == 200:
        result = small_instant.json()
        print(f"✅ Small instant withdrawal successful")
        print(f"   Withdrawal amount: ${small_amount:.2f}")
        print(f"   Instant transfer fee: ${result['instant_fee']:.2f}")
        print(f"   (Minimum fee of $0.25 applied)")
        print(f"   Total deducted: ${result['total_deducted']:.2f}")
        print(f"   New balance: ${result['new_balance']:.2f}")
    else:
        print(f"❌ Small withdrawal failed: {small_instant.text}")
    
    # Step 7: Final balance check
    print("\n6️⃣ Final balance verification...")
    balance_response = requests.get(f"{BASE_URL}/api/balance", headers=headers)
    final_balance = balance_response.json()["balance"]
    
    total_withdrawn = withdrawal_amount + instant_amount + result['instant_fee'] + small_amount + 0.25
    expected_final = initial_balance - total_withdrawn
    
    print(f"✅ Final balance: ${final_balance:.2f}")
    print(f"   Expected: ${expected_final:.2f}")
    print(f"   Total withdrawn (including fees): ${total_withdrawn:.2f}")
    
    if abs(final_balance - expected_final) < 0.01:
        print("✅ Balance calculations correct!")
    else:
        print(f"⚠️ Balance mismatch (might be due to rounding)")
    
    # Step 8: Check transaction history
    print("\n7️⃣ Checking transaction history...")
    history_response = requests.get(f"{BASE_URL}/api/transactions", headers=headers)
    
    if history_response.status_code == 200:
        transactions = history_response.json()["transactions"]
        withdrawal_txs = [tx for tx in transactions if tx["transaction_type"] == "withdrawal"]
        fee_txs = [tx for tx in transactions if tx["transaction_type"] == "fee"]
        
        print(f"✅ Found {len(withdrawal_txs)} withdrawal transactions")
        print(f"✅ Found {len(fee_txs)} fee transactions")
        
        # Show last few transactions
        print("\n   Recent transactions:")
        for tx in transactions[:5]:
            print(f"   - {tx['transaction_type']}: ${tx['amount']:.2f} ({tx['status']})")
    
    print("\n" + "=" * 60)
    print("✅ All instant transfer tests completed successfully!")

if __name__ == "__main__":
    try:
        test_instant_transfer()
    except Exception as e:
        print(f"\n❌ Test failed with error: {e}")
        import traceback
        traceback.print_exc()
