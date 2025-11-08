import requests

BASE_URL = "http://localhost:8000"

# Login
r = requests.post(f"{BASE_URL}/api/auth/login", json={"username": "demo", "password": "demo123"})
token = r.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# Get initial balance
balance = requests.get(f"{BASE_URL}/api/balance", headers=headers).json()["balance"]
print(f"Initial balance: ${balance:.2f}")

# Test instant withdraw with $25 (expected fee: $0.38)
print("\nTesting instant withdraw of $25...")
r1 = requests.post(
    f"{BASE_URL}/api/payment/withdraw",
    headers=headers,
    json={"bank_account_id": "1", "amount": 25.0, "instant_transfer": True}
)

if r1.status_code == 200:
    result = r1.json()
    print(f"SUCCESS!")
    print(f"  Amount: ${result.get('amount', 25):.2f}")
    print(f"  Instant Fee: ${result.get('instant_fee', 0):.2f}")
    print(f"  Total Deducted: ${result.get('total_deducted', 0):.2f}")
    print(f"  Status: {result.get('status')}")
    print(f"  New Balance: ${result.get('new_balance', 0):.2f}")
    
    # Verify fee calculation (1.5% of $25 = $0.375, should be $0.38)
    expected_fee = max(25 * 0.015, 0.25)
    actual_fee = result.get('instant_fee', 0)
    if abs(actual_fee - expected_fee) < 0.01:
        print(f"  Fee calculation: CORRECT (${expected_fee:.2f})")
    else:
        print(f"  Fee calculation: INCORRECT (expected ${expected_fee:.2f}, got ${actual_fee:.2f})")
else:
    print(f"FAILED: {r1.status_code}")
    print(r1.text)

# Test standard withdraw with $10 (no fee)
print("\nTesting standard withdraw of $10...")
r2 = requests.post(
    f"{BASE_URL}/api/payment/withdraw",
    headers=headers,
    json={"bank_account_id": "1", "amount": 10.0, "instant_transfer": False}
)

if r2.status_code == 200:
    result2 = r2.json()
    print(f"SUCCESS!")
    print(f"  Amount: ${result2.get('amount', 10):.2f}")
    print(f"  Fee: ${result2.get('instant_fee', 0):.2f}")
    print(f"  Status: {result2.get('status')}")
    print(f"  New Balance: ${result2.get('new_balance', 0):.2f}")
else:
    print(f"FAILED: {r2.status_code}")
    print(r2.text)

print("\nAll tests completed!")
