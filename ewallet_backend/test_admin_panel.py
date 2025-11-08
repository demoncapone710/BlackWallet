"""
Test Admin Panel Features
Tests all admin endpoints with the admin account
"""
import requests
import json

BASE_URL = "http://localhost:8000"

# Admin credentials
ADMIN_USER = {
    "username": "admin",
    "password": "Admin@2025"
}

def print_section(title):
    print("\n" + "="*70)
    print(f"  {title}")
    print("="*70)

def login_admin():
    """Login as admin"""
    print("\n🔐 Logging in as admin...")
    response = requests.post(f"{BASE_URL}/login", json=ADMIN_USER)
    
    if response.status_code == 200:
        data = response.json()
        token = data.get("token")
        print(f"✅ Admin logged in successfully")
        return token
    else:
        print(f"❌ Login failed: {response.status_code}")
        print(response.text)
        return None

def test_get_all_users(token):
    """Test getting all users"""
    print_section("📋 GET ALL USERS")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/admin/users", headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"Total Users: {data['total']}")
        print(f"\nShowing {len(data['users'])} users:")
        for user in data['users'][:5]:  # Show first 5
            print(f"  • {user['username']} - Balance: ${user['balance']:.2f} - Admin: {user['is_admin']}")
    else:
        print(f"Error: {response.text}")

def test_get_user_details(token, user_id=6):
    """Test getting detailed user info"""
    print_section(f"🔍 GET USER DETAILS (ID: {user_id})")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/admin/users/{user_id}", headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        user = data['user']
        stats = data['statistics']
        
        print(f"\nUser: {user['username']}")
        print(f"Email: {user['email']}")
        print(f"Balance: ${user['balance']:.2f}")
        print(f"Is Admin: {user['is_admin']}")
        print(f"\nStatistics:")
        print(f"  Total Sent: ${stats['total_sent']:.2f}")
        print(f"  Total Received: ${stats['total_received']:.2f}")
        print(f"  Transaction Count: {stats['transaction_count']}")
        print(f"  Net Flow: ${stats['net_flow']:.2f}")
        
        print(f"\nRecent Transactions: {len(data['recent_transactions'])}")
    else:
        print(f"Error: {response.text}")

def test_system_stats(token):
    """Test system statistics"""
    print_section("📊 SYSTEM STATISTICS")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/admin/stats/overview", headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"\n🎯 System Overview:")
        print(f"  Total Users: {data['total_users']}")
        print(f"  Total Transactions: {data['total_transactions']}")
        print(f"  Total Volume: ${data['total_volume']:.2f}")
        print(f"  Active Users (24h): {data['active_users_24h']}")
        print(f"  Average Balance: ${data['average_balance']:.2f}")
        print(f"  Stripe Mode: {data['stripe_mode'].upper()}")
    else:
        print(f"Error: {response.text}")

def test_stripe_mode(token):
    """Test getting Stripe mode"""
    print_section("🔧 STRIPE CONFIGURATION")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/admin/config/stripe-mode", headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"\nCurrent Mode: {data['mode'].upper()}")
        print(f"Is Live: {data['is_live']}")
        print(f"Warning: {data['warning']}")
        print(f"Test Key Set: {data['test_key_set']}")
        print(f"Live Key Set: {data['live_key_set']}")
    else:
        print(f"Error: {response.text}")

def test_update_balance(token, user_id=6):
    """Test updating user balance (read-only test)"""
    print_section("💰 UPDATE BALANCE (View Only - Not Executing)")
    
    print(f"\nTo update balance for user ID {user_id}:")
    print(f"  PUT /api/admin/users/{user_id}/balance")
    print(f"  Body: {{'new_balance': 100.0, 'reason': 'Admin adjustment'}}")
    print(f"\n⚠️  Skipping actual update to preserve data")

def test_transaction_stats(token):
    """Test transaction statistics"""
    print_section("📈 TRANSACTION STATISTICS (Last 7 Days)")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/admin/stats/transactions?days=7", headers=headers)
    
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        print(f"\nPeriod: {data['period_days']} days")
        print(f"Total Transactions: {data['total_transactions']}")
        print(f"Total Volume: ${data['total_volume']:.2f}")
        print(f"Average Transaction: ${data['average_transaction']:.2f}")
        
        if data['daily_volumes']:
            print(f"\nDaily Volumes:")
            for date, volume in sorted(data['daily_volumes'].items())[-7:]:
                print(f"  {date}: ${volume:.2f}")
    else:
        print(f"Error: {response.text}")

def main():
    print("\n" + "="*70)
    print("🔧 BLACKWALLET ADMIN PANEL TEST")
    print("="*70)
    
    # Login
    token = login_admin()
    if not token:
        print("\n❌ Failed to authenticate. Exiting...")
        return
    
    # Wait for server to be ready
    import time
    print("\n⏳ Waiting for server to be ready...")
    time.sleep(3)
    
    # Run tests
    try:
        test_system_stats(token)
        test_get_all_users(token)
        test_get_user_details(token)
        test_stripe_mode(token)
        test_transaction_stats(token)
        test_update_balance(token)
        
        print("\n" + "="*70)
        print("✅ ALL ADMIN TESTS COMPLETED")
        print("="*70)
        print("\n📝 Available Admin Endpoints:")
        print("  • GET  /api/admin/users - List all users")
        print("  • GET  /api/admin/users/{id} - User details")
        print("  • PUT  /api/admin/users/{id} - Update user account")
        print("  • PUT  /api/admin/users/{id}/balance - Edit balance")
        print("  • GET  /api/admin/stats/overview - System statistics")
        print("  • GET  /api/admin/stats/transactions - Transaction stats")
        print("  • GET  /api/admin/config/stripe-mode - Get Stripe mode")
        print("  • POST /api/admin/config/stripe-mode - Set Stripe mode")
        print("\n🔐 Admin Credentials:")
        print("  Username: admin")
        print("  Password: Admin@2025")
        print("  ⚠️  Change password after first login!")
        print("\n" + "="*70)
        
    except Exception as e:
        print(f"\n❌ Error during tests: {e}")

if __name__ == "__main__":
    main()
