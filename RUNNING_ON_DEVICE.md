# Running BlackWallet on Physical Android Device

## 🎉 Your Device is Connected!

**Device Detected:** SM S166V (Samsung)
**Android Version:** 15 (API 35)
**Connection:** Wireless

## ⚠️ Important: Update API URL

Since you're using a **physical device**, you need to update the backend URL in the app.

### Step 1: Find Your Computer's IP Address

```powershell
ipconfig
```

Look for "IPv4 Address" under your active network adapter (usually WiFi or Ethernet).
Example: `192.168.1.100`

### Step 2: Update API Service

Edit `lib/services/api_service.dart` and change:

```dart
// Change from:
static const baseUrl = "http://10.0.2.2:8000";

// To (use YOUR IP address):
static const baseUrl = "http://192.168.1.100:8000";  // Replace with your actual IP
```

### Step 3: Make Sure Both Devices Are on Same WiFi

- Your computer must be on the same WiFi network as your phone
- Firewall must allow incoming connections on port 8000

### Step 4: Start Backend Server

```powershell
.\start-backend.ps1
```

The backend will be accessible at: `http://YOUR_IP:8000`

### Step 5: Run the App

```powershell
# Run on your Samsung device
flutter run -d adb-RZCY428R1VY-I8v0Ft._adb-tls-connect._tcp

# Or just (if it's the only device):
flutter run
```

## 🚀 Quick Command

Once you've updated the API URL:

```powershell
# Terminal 1: Start backend
.\start-backend.ps1

# Terminal 2: Run app
flutter run
```

## 🔍 Testing the Connection

After updating the IP and starting the backend, you can test:

1. Open browser on your phone
2. Navigate to: `http://YOUR_IP:8000/docs`
3. You should see the FastAPI documentation

If you can't access it:
- Check firewall settings
- Ensure both devices are on same network
- Try pinging your computer from your phone

## 📱 Alternative: Use Android Emulator

If you have trouble with the physical device, you can use an emulator:

```powershell
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Then run
flutter run
```

With an emulator, you don't need to change the IP address - `http://10.0.2.2:8000` works automatically.

## 🐛 Troubleshooting

### Can't Connect to Backend

**Symptoms:** Login fails, "Network error" messages

**Solutions:**
1. Verify backend is running: check `http://localhost:8000/docs` on your computer
2. Verify IP address is correct in `api_service.dart`
3. Check Windows Firewall:
   ```powershell
   # Allow Python through firewall
   netsh advfirewall firewall add rule name="Python Backend" dir=in action=allow program="C:\Path\To\Python\python.exe" enable=yes
   ```
4. Make sure both devices are on same WiFi network

### Device Disconnects

**Symptoms:** Device keeps disconnecting during build

**Solutions:**
1. Switch to USB connection instead of wireless
2. Enable "Stay Awake" in Developer Options
3. Use `flutter run --release` for better stability

### Build Fails

**Symptoms:** Gradle errors, build failures

**Solutions:**
```powershell
flutter clean
flutter pub get
flutter run
```

## ✅ Current Status

✅ Android manifest created
✅ Network permissions configured
✅ Device detected and connected
✅ Android licenses accepted
✅ Ready to run (after IP update)

## 📋 Next Steps

1. Run `ipconfig` to get your IP
2. Edit `lib/services/api_service.dart` with your IP
3. Start backend: `.\start-backend.ps1`
4. Run app: `flutter run`
5. Test with accounts: alice/alice123, bob/bob123

---

**Your Samsung device is ready! Just update the IP address and you're good to go! 📱**
