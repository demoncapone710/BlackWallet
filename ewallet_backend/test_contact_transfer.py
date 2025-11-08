"""
Quick test script for contact-based money transfer
Tests sending money via phone and email
"""
import requests
import json

BASE_URL = "http://localhost:8000"

def test_contact_transfer():
    print("=" * 60)
    print("Testing Contact-Based Money Transfer")
    print("=" * 60)
    
    # Step 1: Login as demo user
    print("\n[1/5] Logging in as demo user...")
    login_response = requests.post(
        f"{BASE_URL}/login",
        json={
            "username": "demo",
            "password": "Demo@123"
        }
    )
    
    if login_response.status_code != 200:
        print(f"❌ Login failed: {login_response.text}")
        return
    
    token = login_response.json()["token"]
    print(f"✓ Login successful! Token: {token[:20]}...")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    # Step 2: Check demo user balance
    print("\n[2/5] Checking demo user balance...")
    profile_response = requests.get(f"{BASE_URL}/profile", headers=headers)
    if profile_response.status_code == 200:
        balance = profile_response.json()["balance"]
        print(f"✓ Current balance: ${balance:.2f}")
    
    # Step 3: Look up Alice by phone
    print("\n[3/5] Looking up Alice by phone (5551111111)...")
    lookup_response = requests.get(
        f"{BASE_URL}/api/auth/user-by-contact/5551111111",
        headers=headers
    )
    
    if lookup_response.status_code == 200:
        result = lookup_response.json()
        if result.get("found"):
            print(f"✓ Found user: {result['username']} - {result['full_name']}")
        else:
            print("✗ User not found")
    
    # Step 4: Send $50 to Alice via phone
    print("\n[4/5] Sending $50 to Alice via phone...")
    transfer_response = requests.post(
        f"{BASE_URL}/api/auth/send-money-by-contact",
        headers=headers,
        json={
            "contact": "5551111111",
            "amount": 50.0,
            "contact_type": "phone"
        }
    )
    
    if transfer_response.status_code == 200:
        result = transfer_response.json()
        print(f"✓ {result['message']}")
        print(f"  Recipient exists: {result['recipient_exists']}")
        print(f"  Invitation sent: {result['invitation_sent']}")
    else:
        print(f"❌ Transfer failed: {transfer_response.text}")
    
    # Step 5: Send $25 to Bob via email
    print("\n[5/5] Sending $25 to Bob via email...")
    transfer_response = requests.post(
        f"{BASE_URL}/api/auth/send-money-by-contact",
        headers=headers,
        json={
            "contact": "bob@example.com",
            "amount": 25.0,
            "contact_type": "email"
        }
    )
    
    if transfer_response.status_code == 200:
        result = transfer_response.json()
        print(f"✓ {result['message']}")
        print(f"  Recipient exists: {result['recipient_exists']}")
        print(f"  Invitation sent: {result['invitation_sent']}")
    else:
        print(f"❌ Transfer failed: {transfer_response.text}")
    
    # Final balance check
    print("\n[Final] Checking updated balance...")
    profile_response = requests.get(f"{BASE_URL}/profile", headers=headers)
    if profile_response.status_code == 200:
        new_balance = profile_response.json()["balance"]
        print(f"✓ New balance: ${new_balance:.2f}")
        print(f"  Amount sent: ${balance - new_balance:.2f}")
    
    print("\n" + "=" * 60)
    print("✓ Contact transfer test completed!")
    print("=" * 60)

if __name__ == "__main__":
    try:
        test_contact_transfer()
    except requests.exceptions.ConnectionError:
        print("\n❌ Error: Cannot connect to backend server")
        print("   Make sure the server is running on http://localhost:8000")
    except Exception as e:
        print(f"\n❌ Error: {e}")
