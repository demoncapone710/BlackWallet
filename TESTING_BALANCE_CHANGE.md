# Testing the Balance Change Feature

## Prerequisites
- Backend server running (check terminal)
- Flutter app running on device
- Admin account logged in

## Test Steps

### 1. Login as Admin
```
Username: admin
Password: (your admin password)
```

### 2. Navigate to User Management
- Open the app
- Go to **Admin Panel** → **User Management**
- You should see a list of all users

### 3. Test Balance Adjustment

**Steps:**
1. Find any user in the list
2. Click the **"Adjust Balance"** button (💰 icon) next to their name
3. You should see a dialog with **TWO fields**:
   - **New Balance**: Enter a new amount (e.g., `350.00`)
   - **Reason for change**: Enter a reason (e.g., `Manual adjustment for testing`)

4. Fill both fields:
   ```
   New Balance: $350.00
   Reason: Manual adjustment for testing
   ```

5. Click **"Update"**

### Expected Results

✅ **Success:**
- Green snackbar appears: "Balance updated successfully"
- User list refreshes automatically
- User's balance shows the new amount ($350.00)
- No error messages

❌ **If you leave reason blank:**
- Update button should not submit
- Both fields are required

❌ **Old behavior (before fix):**
- Error: "Field required: reason"
- This should no longer happen!

### 4. Verify in Backend

**Check the backend logs** to see the balance update was recorded:

```bash
# Look for log entry
tail -f ewallet_backend/logs/blackwallet.log
```

You should see something like:
```json
{
  "message": "Admin admin adjusted balance for user testuser from $250.00 to $350.00. Reason: Manual adjustment for testing"
}
```

### 5. Test Different Scenarios

**Test Case 1: Increase Balance**
- Current: $100.00
- New: $500.00
- Reason: "Added bonus reward"
- Expected: ✅ Balance increases

**Test Case 2: Decrease Balance**
- Current: $500.00
- New: $50.00
- Reason: "Corrected duplicate deposit"
- Expected: ✅ Balance decreases

**Test Case 3: Set to Zero**
- Current: $50.00
- New: $0.00
- Reason: "Account reset"
- Expected: ✅ Balance set to $0.00

**Test Case 4: Negative Value (Should Fail)**
- New: -$50.00
- Expected: ❌ Backend validation error (balance must be ≥ 0)

**Test Case 5: Missing Reason**
- New Balance: $123.45
- Reason: (leave blank)
- Expected: ❌ Update button doesn't work until reason is filled

**Test Case 6: Missing Balance**
- New Balance: (leave blank)
- Reason: "Test"
- Expected: ❌ Update button doesn't work until balance is filled

### 6. Check Transaction History (Optional)

Navigate to the user's transaction history to verify if a balance adjustment transaction was recorded (depending on your implementation).

## Common Issues

### Issue 1: "Field required: reason" error
**Status:** ✅ FIXED
**Solution:** Updated in this change - dialog now has reason field

### Issue 2: App crashes when clicking Update
**Check:**
- Both fields are filled
- Balance is a valid number
- No special characters in reason field

### Issue 3: Balance doesn't update visually
**Solution:**
- Wait for snackbar confirmation
- Pull to refresh the user list
- Check if backend actually updated (query database)

### Issue 4: Backend returns 403 Forbidden
**Check:**
- You're logged in as admin
- Admin flag is true in database
- JWT token is valid

## Verification Checklist

After testing, verify:
- [ ] Dialog shows 2 fields (balance + reason)
- [ ] Both fields have black text (readable)
- [ ] Reason field shows placeholder text
- [ ] Update button only works when both filled
- [ ] Success message appears after update
- [ ] User list refreshes with new balance
- [ ] Backend logs the change with reason
- [ ] No error messages appear
- [ ] Works for multiple users
- [ ] Works with different amounts

## API Endpoint Being Tested

```
PUT /api/admin/users/{user_id}/balance

Headers:
  Authorization: Bearer <token>
  Content-Type: application/json

Body:
{
  "new_balance": 350.00,
  "reason": "Manual adjustment for testing"
}

Response (200 OK):
{
  "success": true,
  "message": "Balance updated from $250.00 to $350.00",
  "old_balance": 250.00,
  "new_balance": 350.00
}
```

## Manual API Test (Optional)

You can also test directly with curl:

```bash
# Get your admin token first
TOKEN="your_jwt_token_here"

# Update balance
curl -X PUT http://localhost:8000/api/admin/users/2/balance \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "new_balance": 350.00,
    "reason": "Manual adjustment via API test"
  }'
```

## Success Criteria

✅ **Test Passes If:**
1. Dialog opens with 2 fields
2. Both fields are required
3. Balance updates successfully
4. Reason is recorded in logs
5. No errors occur
6. User list shows new balance
7. Can update multiple users
8. Validation works (no negative, both fields required)

## Next Steps After Testing

Once verified:
- [ ] Test with real users
- [ ] Test edge cases (very large numbers, decimals)
- [ ] Review audit logs for compliance
- [ ] Document any additional issues found

---

**Status:** Ready to test! ✅

The fix has been applied. The balance adjustment dialog now properly collects both the new balance and the reason for the change, matching what the backend API expects.
