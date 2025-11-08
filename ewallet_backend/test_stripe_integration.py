"""
Test Stripe Connect Integration
Tests all real payment endpoints
"""
import requests
import json

# Configuration
BASE_URL = "http://localhost:8000"
TEST_USER = {"username": "test", "password": "test123"}

def login():
    """Login and get JWT token"""
    response = requests.post(
        f"{BASE_URL}/login",
        json=TEST_USER
    )
    if response.status_code == 200:
        data = response.json()
        print(f"Login response: {json.dumps(data, indent=2)}")
        token = data.get("access_token") or data.get("token")
        if token:
            print(f"✅ Logged in successfully")
            return token
        else:
            print(f"❌ No token in response: {data}")
            return None
    else:
        print(f"❌ Login failed: {response.text}")
        return None

def test_create_stripe_account(token):
    """Test creating a Stripe Connect account"""
    print("\n📝 Testing: Create Stripe Connect Account")
    response = requests.post(
        f"{BASE_URL}/api/real-payments/connect/create",
        headers={"Authorization": f"Bearer {token}"},
        json={"country": "US"}
    )
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_get_onboarding_link(token):
    """Test getting Stripe onboarding link"""
    print("\n📝 Testing: Get Onboarding Link")
    response = requests.get(
        f"{BASE_URL}/api/real-payments/connect/onboarding",
        headers={"Authorization": f"Bearer {token}"}
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Onboarding URL: {data.get('onboarding_url', 'N/A')[:80]}...")
        return True
    else:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return False

def test_account_status(token):
    """Test checking Stripe account status"""
    print("\n📝 Testing: Check Account Status")
    response = requests.get(
        f"{BASE_URL}/api/real-payments/connect/status",
        headers={"Authorization": f"Bearer {token}"}
    )
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def test_stripe_balance(token):
    """Test getting Stripe balance"""
    print("\n📝 Testing: Get Stripe Balance")
    response = requests.get(
        f"{BASE_URL}/api/real-payments/balance/stripe",
        headers={"Authorization": f"Bearer {token}"}
    )
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    return response.status_code == 200

def main():
    """Run all tests"""
    print("=" * 60)
    print("🧪 Stripe Connect Integration Tests")
    print("=" * 60)
    
    # Login
    token = login()
    if not token:
        print("\n❌ Cannot proceed without valid token")
        return
    
    # Test each endpoint
    tests = [
        ("Create Stripe Account", test_create_stripe_account),
        ("Get Onboarding Link", test_get_onboarding_link),
        ("Check Account Status", test_account_status),
        ("Get Stripe Balance", test_stripe_balance)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            success = test_func(token)
            results.append((test_name, "✅ PASS" if success else "❌ FAIL"))
        except Exception as e:
            print(f"❌ Error: {e}")
            results.append((test_name, f"❌ ERROR: {str(e)}"))
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Test Results Summary")
    print("=" * 60)
    for test_name, result in results:
        print(f"{test_name:.<40} {result}")
    
    passed = sum(1 for _, r in results if "PASS" in r)
    total = len(results)
    print(f"\nTotal: {passed}/{total} tests passed")
    print("=" * 60)

if __name__ == "__main__":
    main()
