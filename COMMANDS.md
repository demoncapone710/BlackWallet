# 🚀 BlackWallet - Quick Command Reference

## Initial Setup (One Time)
```powershell
.\setup.ps1
```

## Start Backend Server
```powershell
.\start-backend.ps1
```

## Run Flutter App
```powershell
# Check available devices
flutter devices

# Run on default device
flutter run

# Run on specific device
flutter run -d <device_id>

# Run with hot reload
flutter run --debug
```

## Build Android APK
```powershell
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# Install on connected device
flutter install
```

## Verify Android Setup
```powershell
.\verify-android.ps1
```

## Flutter Commands
```powershell
# Get dependencies
flutter pub get

# Clean build cache
flutter clean

# Check Flutter installation
flutter doctor

# List devices
flutter devices

# Hot reload (press in terminal while app running)
r

# Hot restart (press in terminal while app running)
R
```

## Backend Commands
```powershell
cd ewallet_backend

# Activate venv
.\venv\Scripts\Activate.ps1

# Run server
uvicorn main:app --reload

# Initialize database
python init_db.py

# Install packages
pip install -r requirements.txt
```

## Test Accounts
```
alice / alice123 ($1,000)
bob / bob123 ($500)
admin / admin123 ($10,000)
```

## API URLs
- **Emulator**: http://10.0.2.2:8000
- **Localhost**: http://localhost:8000
- **Device**: http://YOUR_IP:8000
- **API Docs**: http://localhost:8000/docs

## Troubleshooting
```powershell
# Full clean and rebuild
flutter clean
flutter pub get
flutter run

# Gradle clean (Android)
cd android
.\gradlew clean
cd ..
flutter clean
flutter pub get

# Backend restart
# Press Ctrl+C in backend terminal
.\start-backend.ps1
```

## File Locations
- **Flutter App**: `lib/`
- **Backend**: `ewallet_backend/`
- **Android Config**: `android/`
- **API Service**: `lib/services/api_service.dart`

## Common Tasks

### Change API URL (for physical device)
Edit: `lib/services/api_service.dart`
```dart
static const baseUrl = "http://YOUR_IP:8000";
```

### Add Flutter Package
1. Edit `pubspec.yaml`
2. Run: `flutter pub get`

### Add Python Package
1. Edit `ewallet_backend/requirements.txt`
2. Run: `pip install -r requirements.txt`

### Reset Database
```powershell
cd ewallet_backend
rm ewallet.db
python init_db.py
```

### View Logs
```powershell
# Flutter logs
flutter logs

# Backend logs
# Visible in terminal where backend is running
```

## Documentation
- **QUICKSTART.md** - Quick start guide
- **README.md** - Full documentation
- **ANDROID_SETUP.md** - Android configuration
- **android/README.md** - Android details
- **FIXES_SUMMARY.md** - All fixes applied

## Support
- Backend API docs: http://localhost:8000/docs
- Flutter docs: https://flutter.dev
- FastAPI docs: https://fastapi.tiangolo.com

---
Save this file for quick reference! 📌
