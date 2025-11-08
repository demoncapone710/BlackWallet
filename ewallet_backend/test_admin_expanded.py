"""
Test script for expanded admin features.
Tests: Notifications, Advertisements, Promotions, Customer Messages, Active Accounts
"""

import requests
import json
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8000"

def print_response(response, title):
    """Print formatted response"""
    print(f"\n{'=' * 60}")
    print(f"{title}")
    print(f"{'=' * 60}")
    print(f"Status: {response.status_code}")
    try:
        print(json.dumps(response.json(), indent=2))
    except:
        print(response.text)
    print(f"{'=' * 60}")

def test_admin_expanded():
    """Test all expanded admin features"""
    
    # Step 1: Admin Login
    print("\n[LOGIN] Step 1: Admin Login")
    login_data = {
        "username": "admin",
        "password": "Admin@2025"
    }
    response = requests.post(f"{BASE_URL}/login", json=login_data)
    print_response(response, "Admin Login")
    
    if response.status_code != 200:
        print(" Login failed! Cannot continue.")
        return
    
    token = response.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    print(" Admin logged in successfully")
    
    # Step 2: Get User List (to get a user_id)
    print("\n Step 2: Get User List")
    response = requests.get(f"{BASE_URL}/api/admin/users", headers=headers)
    print_response(response, "User List")
    
    users = response.json().get("users", [])
    test_user_id = None
    if users:
        # Find a non-admin user
        for user in users:
            if not user.get("is_admin"):
                test_user_id = user["id"]
                print(f" Found test user: {user['username']} (ID: {test_user_id})")
                break
    
    # Step 3: Send Notification to Specific User
    if test_user_id:
        print("\n Step 3: Send Notification to User")
        notification_data = {
            "user_id": test_user_id,
            "title": "Welcome to BlackWallet!",
            "message": "Thank you for using our service. Enjoy exclusive features!",
            "notification_type": "welcome"
        }
        response = requests.post(
            f"{BASE_URL}/api/admin/notifications/send",
            headers=headers,
            json=notification_data
        )
        print_response(response, "Send Notification")
    
    # Step 4: Broadcast Notification to All Users
    print("\n Step 4: Broadcast Notification")
    broadcast_data = {
        "title": "System Maintenance Notice",
        "message": "We'll be performing maintenance tonight from 2-4 AM EST.",
        "notification_type": "announcement"
    }
    response = requests.post(
        f"{BASE_URL}/api/admin/notifications/send",
        headers=headers,
        json=broadcast_data
    )
    print_response(response, "Broadcast Notification")
    
    # Step 5: Get All Notifications
    print("\n Step 5: Get All Notifications")
    response = requests.get(
        f"{BASE_URL}/api/admin/notifications?limit=10",
        headers=headers
    )
    print_response(response, "All Notifications")
    
    # Step 6: Create Advertisement
    print("\n Step 6: Create Advertisement")
    ad_data = {
        "title": "Holiday Bonus Promotion",
        "description": "Get 20% extra on all deposits this week!",
        "image_url": "https://example.com/holiday-banner.jpg",
        "link_url": "https://example.com/promo",
        "ad_type": "banner",
        "target_audience": "all",
        "end_date": (datetime.utcnow() + timedelta(days=7)).isoformat()
    }
    response = requests.post(
        f"{BASE_URL}/api/admin/advertisements",
        headers=headers,
        json=ad_data
    )
    print_response(response, "Create Advertisement")
    ad_id = response.json().get("ad_id") if response.status_code == 200 else None
    
    # Step 7: Get All Advertisements
    print("\n Step 7: Get All Advertisements")
    response = requests.get(
        f"{BASE_URL}/api/admin/advertisements",
        headers=headers
    )
    print_response(response, "All Advertisements")
    
    # Step 8: Create Promotion
    print("\n Step 8: Create Promotion")
    promo_data = {
        "code": "WELCOME25",
        "title": "Welcome Bonus",
        "description": "Get $25 bonus on your first deposit",
        "promotion_type": "bonus",
        "value": 25.0,
        "value_type": "fixed",
        "min_transaction": 100.0,
        "max_uses": 100,
        "uses_per_user": 1,
        "end_date": (datetime.utcnow() + timedelta(days=30)).isoformat()
    }
    response = requests.post(
        f"{BASE_URL}/api/admin/promotions",
        headers=headers,
        json=promo_data
    )
    print_response(response, "Create Promotion")
    promo_id = response.json().get("promo_id") if response.status_code == 200 else None
    
    # Step 9: Get All Promotions
    print("\n  Step 9: Get All Promotions")
    response = requests.get(
        f"{BASE_URL}/api/admin/promotions",
        headers=headers
    )
    print_response(response, "All Promotions")
    
    # Step 10: Get Promotion Usage Stats
    if promo_id:
        print(f"\n Step 10: Get Promotion Usage (ID: {promo_id})")
        response = requests.get(
            f"{BASE_URL}/api/admin/promotions/{promo_id}/usage",
            headers=headers
        )
        print_response(response, "Promotion Usage Stats")
    
    # Step 11: Send Customer Message
    if test_user_id:
        print(f"\n Step 11: Send Message to User {test_user_id}")
        message_data = {
            "user_id": test_user_id,
            "subject": "Account Verification",
            "message": "Please verify your email address to unlock all features.",
            "message_type": "support"
        }
        response = requests.post(
            f"{BASE_URL}/api/admin/messages/send",
            headers=headers,
            json=message_data
        )
        print_response(response, "Send Customer Message")
    
    # Step 12: Get User Messages
    if test_user_id:
        print(f"\n Step 12: Get Messages for User {test_user_id}")
        response = requests.get(
            f"{BASE_URL}/api/admin/messages/user/{test_user_id}",
            headers=headers
        )
        print_response(response, "User Messages")
    
    # Step 13: Get Unread Customer Messages
    print("\n Step 13: Get Unread Messages")
    response = requests.get(
        f"{BASE_URL}/api/admin/messages/unread",
        headers=headers
    )
    print_response(response, "Unread Messages")
    
    # Step 14: Get Active Accounts (last 30 days)
    print("\n Step 14: Get Active Accounts")
    response = requests.get(
        f"{BASE_URL}/api/admin/accounts/active?days=30",
        headers=headers
    )
    print_response(response, "Active Accounts (30 days)")
    
    # Step 15: Get Inactive Accounts
    print("\n Step 15: Get Inactive Accounts")
    response = requests.get(
        f"{BASE_URL}/api/admin/accounts/inactive?days=30",
        headers=headers
    )
    print_response(response, "Inactive Accounts (30 days)")
    
    # Step 16: Get Admin Dashboard
    print("\n Step 16: Get Admin Dashboard")
    response = requests.get(
        f"{BASE_URL}/api/admin/analytics/dashboard",
        headers=headers
    )
    print_response(response, "Admin Dashboard Analytics")
    
    # Step 17: Toggle Promotion Status
    if promo_id:
        print(f"\n Step 17: Toggle Promotion Status (ID: {promo_id})")
        response = requests.put(
            f"{BASE_URL}/api/admin/promotions/{promo_id}/toggle",
            headers=headers
        )
        print_response(response, "Toggle Promotion")
    
    # Step 18: Update Advertisement
    if ad_id:
        print(f"\n  Step 18: Update Advertisement (ID: {ad_id})")
        ad_update_data = {
            "title": "UPDATED: Holiday Mega Sale!",
            "description": "Get 25% extra on all deposits - Extended!",
            "image_url": "https://example.com/mega-sale.jpg",
            "link_url": "https://example.com/sale",
            "ad_type": "banner",
            "target_audience": "all",
            "end_date": (datetime.utcnow() + timedelta(days=14)).isoformat()
        }
        response = requests.put(
            f"{BASE_URL}/api/admin/advertisements/{ad_id}",
            headers=headers,
            json=ad_update_data
        )
        print_response(response, "Update Advertisement")
    
    print("\n" + "=" * 60)
    print(" ALL TESTS COMPLETED!")
    print("=" * 60)
    print("\nNew Admin Features Tested:")
    print("   Send notifications (individual & broadcast)")
    print("   Notification management")
    print("   Advertisement CRUD operations")
    print("   Promotion/promo code system")
    print("   Customer messaging")
    print("   Active/inactive account tracking")
    print("   Comprehensive analytics dashboard")
    print("=" * 60)

if __name__ == "__main__":
    print("Testing Expanded Admin Features")
    print("=" * 60)
    test_admin_expanded()

