# Balance Update Fix

## Problem
When trying to update a user's balance in the admin panel, the app was showing this error:
```
Error: Exception: [{type: missing, loc: [body, reason], msg: Field required, input {new_balance: $350.0}}]
```

## Root Cause
The backend endpoint `/api/admin/users/{user_id}/balance` requires TWO fields:
- `new_balance` (the new amount)
- `reason` (explanation for the change)

But the Flutter UI was only sending `new_balance`.

## Solution
Updated `lib/screens/admin/user_management_screen.dart` to:

1. **Added a reason field** to the balance adjustment dialog
2. **Collects both values** from the user
3. **Sends both fields** to the backend

### Changes Made:

**Before:**
```dart
// Only had one text field for balance
TextField(
  controller: controller,
  decoration: InputDecoration(labelText: 'New Balance'),
)

// Only sent new_balance
body: json.encode({'new_balance': newBalance}),
```

**After:**
```dart
// Two text fields: balance + reason
TextField(
  controller: balanceController,
  decoration: InputDecoration(labelText: 'New Balance'),
)
TextField(
  controller: reasonController,
  decoration: InputDecoration(
    labelText: 'Reason for change',
    hintText: 'e.g., Manual adjustment, Refund, etc.',
  ),
)

// Sends both fields
body: json.encode({
  'new_balance': newBalance,
  'reason': reason,
}),
```

## How to Use

1. **Go to Admin Panel** → User Management
2. **Click "Adjust Balance"** on any user
3. **Enter new balance** amount (e.g., $350.00)
4. **Enter reason** (e.g., "Manual adjustment", "Refund for issue #123", etc.)
5. **Click Update**

The reason field is **required** - you must provide an explanation for the balance change. This is for audit trail and compliance purposes.

## Backend Validation

The backend enforces:
- `new_balance`: Must be ≥ 0
- `reason`: Must be at least 1 character

Example valid request:
```json
{
  "new_balance": 350.00,
  "reason": "Manual adjustment - customer support request"
}
```

## Status
✅ **FIXED** - Balance updates now work correctly with proper reason tracking
