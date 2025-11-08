# BlackWallet - Quick Start Guide

## 🚀 Quick Setup (3 Steps)

### 1️⃣ Run Setup Script
```powershell
.\setup.ps1
```
This will:
- Create Python virtual environment
- Install all backend dependencies
- Initialize database with test users
- Install Flutter dependencies

### 2️⃣ Start Backend Server
```powershell
.\start-backend.ps1
```
Backend will run at: http://localhost:8000

### 3️⃣ Run Flutter App
Open a new terminal and run:
```powershell
flutter run
```

## 🧪 Test Accounts

| Username | Password  | Initial Balance |
|----------|-----------|-----------------|
| alice    | alice123  | $1,000          |
| bob      | bob123    | $500            |
| admin    | admin123  | $10,000         |

## 📱 How to Use

1. **Login** with one of the test accounts (e.g., alice/alice123)
2. **View Balance** on the wallet screen
3. **Send Money** by clicking "Send Money" button
   - Enter receiver username (e.g., "bob")
   - Enter amount
   - Click "Send Money"
4. **View History** by clicking "History" button
5. **Logout** using the logout icon in app bar

## 🧪 Testing Transfers

1. Login as `alice` (alice123)
2. Send $100 to `bob`
3. Logout
4. Login as `bob` (bob123)
5. Verify balance increased by $100
6. Check transaction history

## 🔧 Troubleshooting

### Backend won't start
- Check if port 8000 is already in use
- Make sure Python is installed: `python --version`
- Try: `cd ewallet_backend` then `uvicorn main:app --reload`

### Flutter won't connect
- Ensure backend is running
- For Android emulator, use: `http://10.0.2.2:8000`
- For iOS simulator, use: `http://localhost:8000`
- For physical device, use your computer's IP address

### Dependencies error
```powershell
# Backend
cd ewallet_backend
pip install -r requirements.txt

# Frontend
flutter pub get
```

## 📚 API Documentation

Visit: http://localhost:8000/docs

## 🛠️ Development

### Backend (FastAPI)
```powershell
cd ewallet_backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --reload
```

### Frontend (Flutter)
```powershell
flutter run
# Or for hot reload in debug mode
flutter run --debug
```

## 📝 Making Changes

After making code changes:
- **Backend**: Server auto-reloads with `--reload` flag
- **Frontend**: Use `r` in terminal for hot reload, or `R` for hot restart

## ✨ Features Implemented

✅ User Authentication (JWT)
✅ Secure Password Hashing
✅ Wallet Balance Display
✅ Money Transfer
✅ Transaction History
✅ Input Validation
✅ Error Handling
✅ Modern UI Design
✅ Loading States
✅ Token Management

## 🎯 Next Steps

See `README.md` for:
- Detailed architecture
- API endpoints
- Security considerations
- Production deployment guide
- Future enhancements

---

**Need Help?** Check the full README.md or create an issue.
