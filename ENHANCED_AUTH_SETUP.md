# Enhanced Registration & Authentication Setup

## Overview
BlackWallet now includes enhanced user registration with email, phone number, and full name collection, plus password reset functionality via SMS/email.

## New Features

### 1. Enhanced Registration
- **Full Name**: User's complete name
- **Email Address**: With validation
- **Phone Number**: 10-15 digits, auto-formatted
- **Username**: Unique identifier
- **Password**: Minimum 6 characters

### 2. Password Reset Flow
- User enters email or phone number
- System sends 6-digit verification code (via SMS or email)
- Code expires after 15 minutes
- User creates new password after verification

### 3. Send Money via Contact
- Send money using recipient's phone number or email
- System looks up user automatically
- If recipient doesn't exist, they receive an invitation
- Invitations include app download link

## Backend Changes

### Database Schema
Added to `User` model:
```python
email = Column(String, unique=True, nullable=True)
phone = Column(String, unique=True, nullable=True)
full_name = Column(String, nullable=True)
password_reset_token = Column(String, nullable=True)
reset_token_expiry = Column(DateTime, nullable=True)
```

### New API Endpoints

#### Authentication Routes (`/api/auth/`)
- `POST /api/auth/forgot-password` - Request password reset code
- `POST /api/auth/verify-reset-code` - Verify the 6-digit code
- `POST /api/auth/reset-password` - Set new password
- `POST /api/auth/send-money-by-contact` - Send money via phone/email
- `GET /api/auth/user-by-contact/{contact}` - Lookup user by contact

### Notification Service
Created `notification_service.py` with:
- **SMS Support** (via Twilio - optional)
- **Email Support** (via SMTP)
- Password reset code delivery
- Money received notifications
- App invitation messages

## Frontend Changes

### New Screens
1. **Enhanced Signup Screen** (`signup_screen.dart`)
   - Added fields: Full Name, Email, Phone Number
   - Email validation using `email_validator` package
   - Phone number formatting (digits only, 10-15 length)

2. **Forgot Password Screen** (`forgot_password_screen.dart`)
   - Input: Email or phone number
   - Auto-detects input type
   - Sends verification code

3. **Verify Code Screen** (`verify_code_screen.dart`)
   - 6-digit code entry
   - Resend code option
   - 15-minute expiration warning

4. **Reset Password Screen** (`reset_password_screen.dart`)
   - New password entry
   - Confirmation field
   - Password visibility toggle

5. **Send via Contact Screen** (`send_via_contact_screen.dart`)
   - Phone/email input with user lookup
   - Shows recipient info if found
   - Sends invitation if not found
   - Amount entry with validation

### Updated API Service
Added methods to `api_service.dart`:
```dart
// Registration
signup(username, password, email, phone, fullName)

// Password Reset
forgotPassword(identifier)
verifyResetCode(identifier, code)
resetPassword(identifier, code, newPassword)

// Contact-based Transfers
getUserByContact(contact)
sendMoneyByContact(contact, amount, contactType)
```

## Setup Instructions

### 1. Install Backend Dependencies
```bash
cd ewallet_backend
pip install twilio pydantic[email]
```

### 2. Configure Environment Variables
Create/update `.env` file in `ewallet_backend/`:

```bash
# Email Settings (SMTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@blackwallet.com

# SMS Settings (Twilio) - Optional
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

#### Gmail Setup (for Email)
1. Go to Google Account Settings
2. Enable 2-Factor Authentication
3. Generate an App Password
4. Use that password in `SMTP_PASSWORD`

#### Twilio Setup (for SMS) - Optional
1. Sign up at https://www.twilio.com
2. Get free trial credits ($15)
3. Copy Account SID and Auth Token
4. Get a Twilio phone number
5. Add credentials to `.env`

**Note**: SMS is optional. If not configured, email-only reset will work.

### 3. Run Database Migration
```bash
cd ewallet_backend
python migrate_database.py
```

Or simply start the backend - SQLAlchemy will create the new columns automatically:
```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Install Flutter Dependencies
```bash
flutter pub get
```

New packages:
- `email_validator: ^3.0.0` - Email format validation
- `url_launcher: ^6.3.0` - Open SMS/email apps (future use)

### 5. Update Existing User Data (Optional)
If you have existing users, you can update them with email/phone:
```sql
UPDATE users SET 
  email = 'user@example.com',
  phone = '1234567890',
  full_name = 'John Doe'
WHERE username = 'existing_user';
```

## Testing the Features

### Test Enhanced Registration
1. Open the app and tap "Sign up"
2. Fill in all fields:
   - Full Name: John Doe
   - Email: john@example.com
   - Phone: 1234567890
   - Username: johndoe
   - Password: password123
3. Tap "Create Account"
4. Verify account is created

### Test Password Reset
1. On login screen, tap "Forgot Password?"
2. Enter email or phone number
3. Check email/SMS for 6-digit code
4. Enter code on verification screen
5. Create new password
6. Login with new password

### Test Send via Contact
1. From wallet screen, navigate to "Send via Phone/Email"
2. Enter recipient's phone or email
3. Tap search icon to lookup user
4. If found, shows their name
5. Enter amount and send
6. If recipient not found, they receive invitation

## Development Mode

When email/SMS is not configured, the system logs messages instead of sending:
```
[DEV MODE] Would send email to user@example.com: Password Reset Code
Your code is: 123456
```

Check backend logs to see the codes during testing.

## Security Features

- **Password Reset Codes**: 6 random digits, cryptographically secure
- **Code Expiration**: 15 minutes
- **One-time Use**: Codes invalidated after successful reset
- **Rate Limiting**: Prevents abuse of reset endpoints
- **Secure Validation**: Email and phone format checked server-side

## UI/UX Enhancements

- Auto-detect input type (email vs phone)
- Real-time field validation
- User lookup with visual feedback
- Invitation notifications for non-users
- Clear success/error messages
- Password visibility toggles
- Resend code functionality

## Navigation Flow

### Registration Flow
```
Login Screen
  ↓ (Sign up)
Signup Screen (with new fields)
  ↓ (Create Account)
Login Screen
```

### Password Reset Flow
```
Login Screen
  ↓ (Forgot Password?)
Forgot Password Screen
  ↓ (Send Reset Code)
Verify Code Screen
  ↓ (Verify Code)
Reset Password Screen
  ↓ (Reset Password)
Login Screen
```

### Send via Contact Flow
```
Wallet Screen
  ↓ (Send via Phone/Email)
Send via Contact Screen
  ↓ (User Lookup)
[Found: Show name] or [Not Found: Show invitation message]
  ↓ (Send Money)
Confirmation Dialog
  ↓ (Confirm)
Success → Back to Wallet
```

## API Response Examples

### Forgot Password
```json
{
  "message": "If an account exists, a reset code has been sent.",
  "method": "email"
}
```

### Send Money by Contact (User Found)
```json
{
  "message": "Successfully sent $50.00 to johndoe",
  "recipient_exists": true,
  "invitation_sent": false
}
```

### Send Money by Contact (User Not Found)
```json
{
  "message": "Invitation sent to john@example.com with $50.00",
  "recipient_exists": false,
  "invitation_sent": true
}
```

## Troubleshooting

### Email Not Sending
- Check SMTP credentials in `.env`
- Verify Gmail App Password is correct
- Check firewall allows port 587
- Look for error messages in backend logs

### SMS Not Sending
- Verify Twilio credentials
- Check account has credits
- Verify phone number format (+1234567890)
- Check Twilio console for error messages

### Migration Fails
- Make sure database file exists
- Check file permissions
- Run backend once to create tables: `python main.py`
- Then run migration: `python migrate_database.py`

### Validation Errors
- Email: Must be valid format (user@domain.com)
- Phone: 10-15 digits, non-digits removed automatically
- Password: Minimum 6 characters
- Full Name: Minimum 2 characters

## Future Enhancements

- [ ] Phone number verification with SMS code
- [ ] Email verification with link
- [ ] Social media login integration
- [ ] Import contacts for easy sending
- [ ] Transaction history for invited users
- [ ] Custom invitation messages
- [ ] Multiple notification channels per user

## Files Modified/Created

### Backend
- ✅ `models.py` - Added user fields
- ✅ `schemas.py` - Updated validation schemas
- ✅ `routes/auth.py` - New authentication endpoints
- ✅ `notification_service.py` - SMS/Email service
- ✅ `main.py` - Added auth router
- ✅ `migrate_database.py` - Database migration script
- ✅ `requirements.txt` - Added twilio, pydantic[email]
- ✅ `.env.example` - Added SMTP/Twilio config

### Frontend
- ✅ `lib/screens/signup_screen.dart` - Enhanced with new fields
- ✅ `lib/screens/login_screen.dart` - Added forgot password link
- ✅ `lib/screens/forgot_password_screen.dart` - New screen
- ✅ `lib/screens/verify_code_screen.dart` - New screen
- ✅ `lib/screens/reset_password_screen.dart` - New screen
- ✅ `lib/screens/send_via_contact_screen.dart` - New screen
- ✅ `lib/services/api_service.dart` - Added new methods
- ✅ `pubspec.yaml` - Added email_validator, url_launcher

## Notes

- SMS functionality requires Twilio account (free trial available)
- Email functionality requires SMTP server (Gmail works great)
- Development mode logs codes instead of sending for testing
- All contact information is optional for existing users
- New users must provide all fields during registration
- Password reset works with either email or phone
- Invitation system allows sending money to non-users

---

**Last Updated**: November 6, 2025  
**Version**: 1.1.0  
**Author**: BlackWallet Development Team
