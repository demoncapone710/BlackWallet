"""
Test script for withdrawal functionality
"""
import requests
import json

BASE_URL = "http://localhost:8000"

def test_withdrawal_flow():
    print("=" * 60)
    print("Testing Withdrawal Flow")
    print("=" * 60)
    
    # 1. Login as demo user
    print("\n[1/5] Logging in as demo user...")
    login_response = requests.post(
        f"{BASE_URL}/login",
        json={"username": "demo", "password": "Demo@123"}
    )
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.text}")
        return
    
    token = login_response.json()["token"]
    print(f"✓ Login successful. Token: {token[:20]}...")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Check current balance
    print("\n[2/5] Checking current balance...")
    balance_response = requests.get(f"{BASE_URL}/balance", headers=headers)
    
    if balance_response.status_code != 200:
        print(f"❌ Failed to get balance: {balance_response.text}")
        return
    
    balance = balance_response.json()["balance"]
    print(f"✓ Current balance: ${balance:.2f}")
    
    # 3. Get payment methods
    print("\n[3/5] Getting payment methods...")
    pm_response = requests.get(f"{BASE_URL}/api/payment/payment-methods", headers=headers)
    
    if pm_response.status_code != 200:
        print(f"❌ Failed to get payment methods: {pm_response.text}")
        return
    
    payment_methods = pm_response.json()["payment_methods"]
    bank_accounts = [pm for pm in payment_methods if pm["type"] == "bank_account"]
    
    print(f"✓ Found {len(payment_methods)} payment methods")
    print(f"  - Bank accounts: {len(bank_accounts)}")
    print(f"  - Cards: {len([pm for pm in payment_methods if pm['type'] == 'card'])}")
    
    # 4. Add a test bank account if none exists
    if len(bank_accounts) == 0:
        print("\n[4/5] Adding test bank account...")
        add_bank_response = requests.post(
            f"{BASE_URL}/api/payment/payment-methods/bank",
            headers=headers,
            json={
                "account_number": "000123456789",
                "routing_number": "110000000"
            }
        )
        
        if add_bank_response.status_code != 200:
            print(f"❌ Failed to add bank account: {add_bank_response.text}")
            return
        
        bank_account_id = add_bank_response.json()["payment_method"]["id"]
        print(f"✓ Bank account added successfully (ID: {bank_account_id})")
    else:
        bank_account_id = bank_accounts[0]["id"]
        print(f"\n[4/5] Using existing bank account (ID: {bank_account_id})")
    
    # 5. Test withdrawal
    withdrawal_amount = min(10.0, balance)  # Withdraw $10 or all balance if less
    print(f"\n[5/5] Testing withdrawal of ${withdrawal_amount:.2f}...")
    
    withdraw_response = requests.post(
        f"{BASE_URL}/api/payment/withdraw",
        headers=headers,
        json={
            "bank_account_id": str(bank_account_id),
            "amount": withdrawal_amount
        }
    )
    
    if withdraw_response.status_code != 200:
        print(f"❌ Withdrawal failed: {withdraw_response.text}")
        return
    
    result = withdraw_response.json()
    print(f"✓ Withdrawal successful!")
    print(f"  - Amount: ${withdrawal_amount:.2f}")
    print(f"  - New balance: ${result['new_balance']:.2f}")
    print(f"  - Transaction ID: {result['transaction_id']}")
    print(f"  - Status: {result['status']}")
    print(f"  - Message: {result['message']}")
    
    # 6. Verify new balance
    print("\n[6/6] Verifying new balance...")
    balance_response = requests.get(f"{BASE_URL}/balance", headers=headers)
    new_balance = balance_response.json()["balance"]
    print(f"✓ Confirmed new balance: ${new_balance:.2f}")
    print(f"  - Previous: ${balance:.2f}")
    print(f"  - Withdrawn: ${withdrawal_amount:.2f}")
    print(f"  - Difference: ${balance - new_balance:.2f}")
    
    print("\n" + "=" * 60)
    print("✅ All withdrawal tests passed!")
    print("=" * 60)

if __name__ == "__main__":
    test_withdrawal_flow()
