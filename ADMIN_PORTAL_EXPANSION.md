# Admin Portal Expansion - Complete Documentation

## Overview
The admin portal has been significantly expanded with customer communication, marketing, and analytics features. This document covers all new functionality added to the admin system.

## What's New

### 1. **Push Notifications System**
Send targeted notifications to users individually or broadcast to all users.

**Features:**
- Individual user notifications
- Broadcast to all users
- Notification types: welcome, announcement, alert, general
- Read/unread tracking
- Notification history

### 2. **Advertisement Management**
Create and manage in-app advertisements with performance tracking.

**Features:**
- Create, update, delete advertisements
- Track impressions and clicks
- Ad targeting (audience segmentation)
- Active/inactive status
- Time-based campaigns (start/end dates)
- Multiple ad types: banner, popup, inline

### 3. **Promotion & Promo Code System**
Manage promotional codes with advanced usage tracking.

**Features:**
- Create unique promo codes
- Fixed or percentage-based discounts
- Minimum transaction requirements
- Usage limits (total and per-user)
- Time-limited promotions
- Usage tracking and analytics
- Toggle active/inactive status

### 4. **Customer Messaging System**
Direct communication channel between admin and customers.

**Features:**
- Send messages to specific users
- View conversation history
- Unread message notifications
- Message types: support, billing, general
- Threading support (parent messages)

### 5. **Active/Inactive Account Tracking**
Monitor user engagement and account activity.

**Features:**
- View active accounts (users with recent transactions)
- View inactive accounts (no recent activity)
- Configurable time periods (1-365 days)
- User engagement metrics

### 6. **Comprehensive Analytics Dashboard**
Centralized dashboard with key metrics.

**Features:**
- User statistics (total, active)
- Transaction metrics (count, volume, average)
- Financial overview (total balance in system)
- Notification statistics
- Marketing campaign metrics
- Support ticket tracking
- Stripe mode indicator

---

## API Endpoints Reference

### Notification Endpoints

#### Send Notification to User
```http
POST /api/admin/notifications/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "user_id": 2,  // null for broadcast
  "title": "Welcome to BlackWallet!",
  "message": "Thank you for using our service.",
  "notification_type": "welcome"
}
```

**Response:**
```json
{
  "message": "Notification sent",
  "recipient": "alice"
}
```

#### Broadcast Notification
```http
POST /api/admin/notifications/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "System Maintenance",
  "message": "Maintenance tonight 2-4 AM EST.",
  "notification_type": "announcement"
}
```

**Response:**
```json
{
  "message": "Notification broadcast",
  "recipients": 5
}
```

#### Get All Notifications
```http
GET /api/admin/notifications?skip=0&limit=50
Authorization: Bearer <token>
```

**Response:**
```json
{
  "total": 6,
  "skip": 0,
  "limit": 50,
  "notifications": [
    {
      "id": 1,
      "user_id": 2,
      "title": "Welcome!",
      "message": "Thank you...",
      "type": "welcome",
      "is_read": false,
      "sent_at": "2025-11-08T11:15:46.101464"
    }
  ]
}
```

---

### Advertisement Endpoints

#### Create Advertisement
```http
POST /api/admin/advertisements
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "Holiday Bonus Promotion",
  "description": "Get 20% extra on deposits!",
  "image_url": "https://example.com/banner.jpg",
  "link_url": "https://example.com/promo",
  "ad_type": "banner",
  "target_audience": "all",
  "end_date": "2025-12-31T23:59:59"
}
```

**Response:**
```json
{
  "message": "Advertisement created",
  "ad_id": 1
}
```

#### Get All Advertisements
```http
GET /api/admin/advertisements?active_only=true
Authorization: Bearer <token>
```

**Response:**
```json
{
  "total": 1,
  "advertisements": [
    {
      "id": 1,
      "title": "Holiday Bonus Promotion",
      "description": "Get 20% extra on deposits!",
      "image_url": "https://example.com/banner.jpg",
      "link_url": "https://example.com/promo",
      "ad_type": "banner",
      "target_audience": "all",
      "is_active": true,
      "impressions": 1234,
      "clicks": 56,
      "start_date": "2025-11-08T11:15:52.400495",
      "end_date": "2025-12-31T23:59:59"
    }
  ]
}
```

#### Update Advertisement
```http
PUT /api/admin/advertisements/{ad_id}
Authorization: Bearer <token>
Content-Type: application/json

{
  "title": "UPDATED: Holiday Mega Sale!",
  "description": "Get 25% extra - Extended!",
  "image_url": "https://example.com/mega-sale.jpg",
  "link_url": "https://example.com/sale",
  "ad_type": "banner",
  "target_audience": "all",
  "end_date": "2026-01-15T23:59:59"
}
```

#### Delete Advertisement
```http
DELETE /api/admin/advertisements/{ad_id}
Authorization: Bearer <token>
```

---

### Promotion Endpoints

#### Create Promotion
```http
POST /api/admin/promotions
Authorization: Bearer <token>
Content-Type: application/json

{
  "code": "WELCOME25",
  "title": "Welcome Bonus",
  "description": "Get $25 bonus on first deposit",
  "promotion_type": "bonus",
  "value": 25.0,
  "value_type": "fixed",  // or "percentage"
  "min_transaction": 100.0,
  "max_uses": 100,
  "uses_per_user": 1,
  "end_date": "2025-12-31T23:59:59"
}
```

**Response:**
```json
{
  "message": "Promotion created",
  "promo_id": 1,
  "code": "WELCOME25"
}
```

#### Get All Promotions
```http
GET /api/admin/promotions?active_only=true
Authorization: Bearer <token>
```

**Response:**
```json
{
  "total": 1,
  "promotions": [
    {
      "id": 1,
      "code": "WELCOME25",
      "title": "Welcome Bonus",
      "description": "Get $25 bonus on first deposit",
      "promotion_type": "bonus",
      "value": 25.0,
      "value_type": "fixed",
      "min_transaction": 100.0,
      "max_uses": 100,
      "uses_count": 5,
      "uses_per_user": 1,
      "is_active": true,
      "start_date": "2025-11-08T11:15:56.602385",
      "end_date": "2025-12-31T23:59:59"
    }
  ]
}
```

#### Get Promotion Usage Statistics
```http
GET /api/admin/promotions/{promo_id}/usage
Authorization: Bearer <token>
```

**Response:**
```json
{
  "promotion": {
    "code": "WELCOME25",
    "title": "Welcome Bonus",
    "uses_count": 5,
    "max_uses": 100
  },
  "total_amount_saved": 125.0,
  "usage_history": [
    {
      "user_id": 2,
      "amount_saved": 25.0,
      "used_at": "2025-11-08T15:30:00"
    }
  ]
}
```

#### Toggle Promotion Active/Inactive
```http
PUT /api/admin/promotions/{promo_id}/toggle
Authorization: Bearer <token>
```

**Response:**
```json
{
  "message": "Promotion activated",
  "is_active": true
}
```

---

### Customer Messaging Endpoints

#### Send Message to Customer
```http
POST /api/admin/messages/send
Authorization: Bearer <token>
Content-Type: application/json

{
  "user_id": 2,
  "subject": "Account Verification",
  "message": "Please verify your email address.",
  "message_type": "support"
}
```

**Response:**
```json
{
  "message": "Message sent",
  "message_id": 1
}
```

#### Get User Messages
```http
GET /api/admin/messages/user/{user_id}
Authorization: Bearer <token>
```

**Response:**
```json
{
  "user": {
    "id": 2,
    "username": "alice",
    "email": "alice@example.com"
  },
  "total_messages": 2,
  "messages": [
    {
      "id": 1,
      "subject": "Account Verification",
      "message": "Please verify your email...",
      "message_type": "support",
      "direction": "admin_to_user",
      "is_read": false,
      "created_at": "2025-11-08T11:16:02.879705"
    }
  ]
}
```

#### Get Unread Messages
```http
GET /api/admin/messages/unread
Authorization: Bearer <token>
```

**Response:**
```json
{
  "total_unread": 3,
  "messages": [
    {
      "id": 5,
      "user_id": 3,
      "subject": "Payment Issue",
      "message": "I'm having trouble with my payment...",
      "created_at": "2025-11-08T14:30:00"
    }
  ]
}
```

#### Mark Message as Read
```http
PUT /api/admin/messages/{message_id}/read
Authorization: Bearer <token>
```

---

### Account Analytics Endpoints

#### Get Active Accounts
```http
GET /api/admin/accounts/active?days=30
Authorization: Bearer <token>
```

**Response:**
```json
{
  "period_days": 30,
  "total_active": 2,
  "users": [
    {
      "id": 5,
      "username": "demo",
      "email": "demo@blackwallet.com",
      "balance": 3170.0,
      "is_admin": false
    }
  ]
}
```

#### Get Inactive Accounts
```http
GET /api/admin/accounts/inactive?days=30
Authorization: Bearer <token>
```

**Response:**
```json
{
  "period_days": 30,
  "total_inactive": 3,
  "users": [
    {
      "id": 2,
      "username": "alice",
      "email": "alice@example.com",
      "balance": 1000.0,
      "last_seen": "N/A"
    }
  ]
}
```

#### Get Admin Dashboard
```http
GET /api/admin/analytics/dashboard
Authorization: Bearer <token>
```

**Response:**
```json
{
  "users": {
    "total": 5,
    "active_30d": 2
  },
  "transactions": {
    "count_30d": 11,
    "volume_30d": 1911.125,
    "average": 173.74
  },
  "financial": {
    "total_balance_in_system": 4938.875
  },
  "notifications": {
    "total_sent": 12,
    "unread": 12
  },
  "marketing": {
    "active_promotions": 1,
    "active_advertisements": 2
  },
  "support": {
    "unread_messages": 0
  },
  "stripe_mode": "test"
}
```

---

## Database Tables

### New Tables Created

1. **notifications**
   - id (PK)
   - user_id
   - title
   - message
   - notification_type
   - is_read
   - sent_at
   - extra_data (JSON)

2. **advertisements**
   - id (PK)
   - title
   - description
   - image_url
   - link_url
   - ad_type
   - target_audience
   - is_active
   - impressions
   - clicks
   - start_date
   - end_date
   - created_at
   - created_by

3. **promotions**
   - id (PK)
   - code (UNIQUE)
   - title
   - description
   - promotion_type
   - value
   - value_type
   - min_transaction
   - max_uses
   - uses_count
   - uses_per_user
   - is_active
   - start_date
   - end_date
   - created_at
   - created_by

4. **customer_messages**
   - id (PK)
   - user_id
   - admin_id
   - subject
   - message
   - message_type
   - direction (admin_to_user / user_to_admin)
   - is_read
   - parent_message_id
   - created_at
   - extra_data (JSON)

5. **promotion_usage**
   - id (PK)
   - promotion_id
   - user_id
   - transaction_id
   - amount_saved
   - used_at

---

## Testing

### Run Test Suite
```bash
cd ewallet_backend
python test_admin_expanded.py
```

### Test Results
All 18 test cases passed successfully:
- ✓ Admin login
- ✓ User list retrieval
- ✓ Send notification to specific user
- ✓ Broadcast notification to all users
- ✓ Get all notifications
- ✓ Create advertisement
- ✓ Get all advertisements
- ✓ Update advertisement
- ✓ Create promotion
- ✓ Get all promotions
- ✓ Get promotion usage statistics
- ✓ Toggle promotion status
- ✓ Send customer message
- ✓ Get user messages
- ✓ Get unread messages
- ✓ Get active accounts
- ✓ Get inactive accounts
- ✓ Get admin dashboard

---

## Usage Examples

### Example 1: Send Welcome Notification to New User
```python
import requests

token = "your_admin_token"
headers = {"Authorization": f"Bearer {token}"}

data = {
    "user_id": 5,
    "title": "Welcome to BlackWallet!",
    "message": "Thank you for joining. Enjoy our services!",
    "notification_type": "welcome"
}

response = requests.post(
    "http://localhost:8000/api/admin/notifications/send",
    headers=headers,
    json=data
)
print(response.json())
```

### Example 2: Create Holiday Promotion
```python
data = {
    "code": "HOLIDAY50",
    "title": "Holiday Special",
    "description": "Get 50% bonus on deposits over $200",
    "promotion_type": "bonus",
    "value": 50.0,
    "value_type": "percentage",
    "min_transaction": 200.0,
    "max_uses": 1000,
    "uses_per_user": 1,
    "end_date": "2025-12-25T23:59:59"
}

response = requests.post(
    "http://localhost:8000/api/admin/promotions",
    headers=headers,
    json=data
)
```

### Example 3: Monitor Active Users
```python
# Get users active in last 7 days
response = requests.get(
    "http://localhost:8000/api/admin/accounts/active?days=7",
    headers=headers
)

active_users = response.json()
print(f"Active users (7 days): {active_users['total_active']}")
```

---

## Security Notes

1. **Admin Authentication Required**: All endpoints require admin JWT token
2. **Admin-Only Access**: Only users with `is_admin=True` can access these endpoints
3. **Rate Limiting**: API rate limiting applies to all endpoints
4. **Input Validation**: All inputs are validated using Pydantic models
5. **SQL Injection Protection**: SQLAlchemy ORM prevents SQL injection

---

## Migration

Database migration was completed successfully:
```bash
python migrate_admin_features.py
```

Created 5 new tables:
- ✓ notifications
- ✓ advertisements
- ✓ promotions
- ✓ customer_messages
- ✓ promotion_usage

---

## Future Enhancements

### Planned Features:
1. **Flutter Admin UI**: Mobile admin interface
2. **Email Integration**: Send email notifications
3. **SMS Integration**: Send SMS notifications
4. **Analytics Graphs**: Visual charts and graphs
5. **Export Reports**: CSV/PDF export functionality
6. **Scheduled Campaigns**: Auto-schedule ads and promotions
7. **A/B Testing**: Test different ad variations
8. **Push Notification Service**: Real push notifications to mobile devices

---

## Support

For issues or questions:
- Check test scripts: `test_admin_expanded.py`
- Review API documentation above
- Check logs: `logs/ewallet.log`
- Contact: admin@blackwallet.com

---

## Changelog

### Version 2.0 (2025-11-08)
- ✓ Added push notification system
- ✓ Added advertisement management
- ✓ Added promotion/promo code system
- ✓ Added customer messaging
- ✓ Added active/inactive account tracking
- ✓ Added comprehensive analytics dashboard
- ✓ Created 5 new database tables
- ✓ Added 18 new API endpoints
- ✓ Complete test suite with 100% pass rate

### Version 1.0 (Previous)
- User management
- Balance editing
- System statistics
- Stripe mode switching

---

**Admin Portal is now fully operational with all requested features!**
