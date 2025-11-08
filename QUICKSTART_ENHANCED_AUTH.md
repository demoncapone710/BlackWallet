# 🚀 Quick Start Guide - Enhanced Authentication

## What's New?
✅ Enhanced registration with email, phone, and full name  
✅ Password reset via SMS or email  
✅ Send money to anyone using their phone or email  
✅ Automatic user invitations for non-users  

---

## 1️⃣ Configure Backend (5 minutes)

### Option A: Email Only (Recommended for Testing)

Create `ewallet_backend/.env`:
```bash
# Email Settings (Gmail)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-gmail-app-password
SMTP_FROM_EMAIL=noreply@blackwallet.com
```

**Get Gmail App Password:**
1. Go to https://myaccount.google.com/security
2. Enable 2-Factor Authentication
3. Search "App Passwords"
4. Create password for "Mail"
5. Copy 16-character password to `.env`

### Option B: Email + SMS (Full Features)

Add to `.env`:
```bash
# SMS Settings (Twilio)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

**Get Twilio Credentials:**
1. Sign up at https://www.twilio.com (Free $15 credit)
2. Go to Console Dashboard
3. Copy Account SID and Auth Token
4. Get a phone number from "Phone Numbers" section

---

## 2️⃣ Start Backend

```bash
cd ewallet_backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Note:** Database columns will be created automatically!

---

## 3️⃣ Run Flutter App

```bash
flutter run
```

---

## 📱 Test the Features

### ✅ Enhanced Registration
1. Tap "Sign up" on login screen
2. Fill in:
   - Full Name: John Doe
   - Email: john@example.com
   - Phone: 1234567890
   - Username: johndoe
   - Password: password123
3. Tap "Create Account"

### ✅ Password Reset (Email)
1. Tap "Forgot Password?" on login
2. Enter: john@example.com
3. **Check your email** for 6-digit code
4. Enter code on verification screen
5. Create new password
6. Login!

### ✅ Password Reset (SMS)
1. Tap "Forgot Password?"
2. Enter: 1234567890
3. **Check your phone** for SMS
4. Enter 6-digit code
5. Create new password

### ✅ Send Money via Contact
1. Open wallet → Menu (⋮)
2. Tap "Send via Phone/Email"
3. Enter recipient's phone or email
4. Tap search icon (🔍)
5. If found: Shows their name
6. If not found: They'll get an invitation!
7. Enter amount → Send

---

## 🎯 Where to Find New Features

### Login Screen
- **New:** "Forgot Password?" link below password field

### Signup Screen
- **New Fields:**
  - Full Name (with name icon)
  - Email (with @ icon)
  - Phone Number (with phone icon)
  - Username
  - Password
  - Confirm Password

### Wallet Screen Menu
- **New Option:** "Send via Phone/Email" (pink/magenta color)
  - Located between "Send Money" and "Request Money"

---

## 🐛 Troubleshooting

### "Email not sent"
- ✅ Check SMTP credentials in `.env`
- ✅ Verify Gmail app password is correct
- ✅ Check backend logs for errors

### "SMS not sent"
- ✅ Verify Twilio credentials
- ✅ Check Twilio account has credit
- ✅ Phone number must include country code (+1)

### "Code expired"
- Codes expire after 15 minutes
- Tap "Resend Code" to get a new one

### "User already exists"
- Email or phone already registered
- Try different email/phone
- Or use password reset to recover account

---

## 📝 Development Mode

If email/SMS not configured, backend logs messages:
```
[DEV MODE] Would send email to john@example.com
Your reset code is: 123456
```

Check terminal to see codes during testing!

---

## 🎨 UI Highlights

### New Screens Created:
1. **Forgot Password** - Clean, simple code request
2. **Verify Code** - Large, centered 6-digit input
3. **Reset Password** - Dual password fields with toggles
4. **Send via Contact** - User lookup with visual feedback

### Color Scheme:
- **Crimson Red** (#DC143C) - Primary actions
- **Pink/Magenta** (#FF4081) - Contact features
- **Green** - Success states, user found
- **Orange** - Warning states, invitation notice

---

## 📚 Documentation

**Full Setup Guide:**  
`ENHANCED_AUTH_SETUP.md` - Complete technical documentation

**Feature Summary:**  
`ENHANCED_AUTH_SUMMARY.md` - Implementation details

**This Quick Start:**  
`QUICKSTART_ENHANCED_AUTH.md` - You are here!

---

## ✨ Key Benefits

### For Users:
- 📧 Reset password easily via email or text
- 📱 Send money with just a phone number
- 🎁 Invite friends who don't have the app yet
- 🔒 Secure with 15-minute code expiration

### For Developers:
- 🏗️ Clean architecture with separate services
- 🔄 Works with or without SMS/email configured
- 📊 Comprehensive error handling
- 🧪 Easy to test in dev mode

---

## 🚀 Next Steps

### Immediate:
1. ✅ Configure at least email in `.env`
2. ✅ Test registration with new fields
3. ✅ Test password reset flow
4. ✅ Test sending money via contact

### Optional:
- Configure Twilio for SMS support
- Customize email templates in `notification_service.py`
- Add your logo to emails
- Update `.env` with production URLs

---

## 💡 Pro Tips

1. **Use Gmail for testing** - It's free and reliable
2. **Get Twilio trial** - $15 free credit for SMS testing
3. **Check backend logs** - See all codes in dev mode
4. **Test with real contacts** - More realistic experience
5. **Invite yourself first** - Test the full invitation flow

---

## 📞 Support

**Found an issue?**
- Check backend logs for errors
- Verify `.env` configuration
- See `ENHANCED_AUTH_SETUP.md` for detailed troubleshooting

**Feature working?**
- Test all flows thoroughly
- Try edge cases (expired codes, invalid emails)
- Verify email/SMS delivery

---

## 🎉 You're Ready!

All features are implemented and tested. Just configure your email (and optionally SMS), start the backend, and enjoy the enhanced authentication system!

**Happy coding! 🚀**

---

*Last Updated: November 6, 2025*  
*Version: 1.1.0*
