"""
Test webhook endpoints locally or in production
"""
import requests
import json
import sys
from datetime import datetime


def test_webhook_health(base_url: str):
    """Test webhook health endpoint"""
    print(f"\n🔍 Testing webhook health at {base_url}")
    try:
        response = requests.get(f"{base_url}/api/webhooks/health", timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def test_stripe_webhook(base_url: str, test_mode: bool = True):
    """Send a test Stripe webhook event"""
    print(f"\n🔍 Testing Stripe webhook at {base_url}")
    
    # Sample payment_intent.succeeded event
    test_event = {
        "id": "evt_test_123",
        "type": "payment_intent.succeeded",
        "data": {
            "object": {
                "id": "pi_test_123",
                "amount": 1000,  # $10.00
                "currency": "usd",
                "status": "succeeded",
                "metadata": {
                    "user_id": "1",
                    "transaction_id": "1"
                }
            }
        }
    }
    
    try:
        response = requests.post(
            f"{base_url}/api/webhooks/stripe",
            json=test_event,
            headers={
                "Content-Type": "application/json",
                # Note: In production, Stripe-Signature header is required
            },
            timeout=10
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code in [200, 201]
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def test_api_root(base_url: str):
    """Test API root endpoint"""
    print(f"\n🔍 Testing API root at {base_url}")
    try:
        response = requests.get(base_url, timeout=10)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def main():
    """Run all webhook tests"""
    # Get base URL from command line or use default
    if len(sys.argv) > 1:
        base_url = sys.argv[1].rstrip('/')
    else:
        base_url = "http://localhost:8000"
    
    print("=" * 60)
    print("🧪 BlackWallet Webhook Testing")
    print("=" * 60)
    print(f"Target: {base_url}")
    print(f"Time: {datetime.now().isoformat()}")
    print("=" * 60)
    
    results = []
    
    # Test API root
    results.append(("API Root", test_api_root(base_url)))
    
    # Test webhook health
    results.append(("Webhook Health", test_webhook_health(base_url)))
    
    # Test Stripe webhook (only in development)
    if "localhost" in base_url or "127.0.0.1" in base_url:
        results.append(("Stripe Webhook", test_stripe_webhook(base_url)))
    else:
        print("\n⚠️  Skipping Stripe webhook test (use Stripe Dashboard for production)")
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Test Summary")
    print("=" * 60)
    for test_name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} - {test_name}")
    
    total = len(results)
    passed = sum(1 for _, p in results if p)
    print(f"\nResults: {passed}/{total} tests passed")
    print("=" * 60)
    
    # Exit with error code if any test failed
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
