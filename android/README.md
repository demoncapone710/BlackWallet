# Android Configuration for BlackWallet

This directory contains all the necessary Android configuration files for the BlackWallet Flutter app.

## 📁 Directory Structure

```
android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── kotlin/com/example/blackwallet/
│   │   │   │   └── MainActivity.kt
│   │   │   ├── res/
│   │   │   │   ├── drawable/
│   │   │   │   │   └── launch_background.xml
│   │   │   │   ├── mipmap-*/
│   │   │   │   ├── values/
│   │   │   │   │   └── styles.xml
│   │   │   │   └── xml/
│   │   │   │       └── network_security_config.xml
│   │   │   └── AndroidManifest.xml
│   │   ├── debug/
│   │   │   └── AndroidManifest.xml
│   │   └── profile/
│   │       └── AndroidManifest.xml
│   └── build.gradle
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
├── build.gradle
├── settings.gradle
└── gradle.properties
```

## 🔧 Key Files Created

### 1. AndroidManifest.xml (Main)
- **Package**: com.example.blackwallet
- **App Name**: BlackWallet
- **Permissions**: 
  - INTERNET (for API calls)
  - ACCESS_NETWORK_STATE
  - WAKE_LOCK
- **Network Security**: Allows cleartext traffic for development (localhost/10.0.2.2)
- **Launch Mode**: singleTop
- **Hardware Acceleration**: Enabled

### 2. network_security_config.xml
Allows HTTP traffic to:
- localhost (127.0.0.1)
- Android emulator (10.0.2.2)
- Local network (192.168.x.x)

⚠️ **For Production**: Remove cleartext traffic or use HTTPS only!

### 3. build.gradle (App)
- **Application ID**: com.example.blackwallet
- **Min SDK**: 21 (Android 5.0 Lollipop)
- **Target SDK**: 34 (Android 14)
- **Compile SDK**: 34
- **Kotlin**: Enabled
- **AndroidX**: Enabled

### 4. MainActivity.kt
Simple Kotlin activity that extends FlutterActivity

### 5. Gradle Configuration
- **Gradle Version**: 7.6.1
- **Android Gradle Plugin**: 7.4.2
- **Kotlin Version**: 1.8.22

## 🚀 Building the App

### Debug Build
```powershell
flutter build apk --debug
```

### Release Build
```powershell
flutter build apk --release
```

### Build and Install
```powershell
flutter run
```

## 📱 Running on Android

### 1. Start Android Emulator
```powershell
# List available devices
flutter devices

# Run on default device
flutter run

# Run on specific device
flutter run -d <device_id>
```

### 2. Running on Physical Device
1. Enable Developer Options on your Android device
2. Enable USB Debugging
3. Connect device via USB
4. Run: `flutter run`

## 🔗 API Configuration

The app is configured to connect to:
- **Android Emulator**: `http://10.0.2.2:8000`
- **Physical Device**: Update `baseUrl` in `lib/services/api_service.dart` to your computer's IP

### Find Your Computer's IP
```powershell
# Windows
ipconfig
# Look for IPv4 Address under your active network adapter
```

Then update `api_service.dart`:
```dart
static const baseUrl = "http://YOUR_IP:8000";  // e.g., "http://192.168.1.100:8000"
```

## 🎨 App Icon

Default Flutter launcher icon is used. To customize:

1. Add your icon files to `res/mipmap-*` directories:
   - mipmap-mdpi: 48x48
   - mipmap-hdpi: 72x72
   - mipmap-xhdpi: 96x96
   - mipmap-xxhdpi: 144x144
   - mipmap-xxxhdpi: 192x192

2. Or use the `flutter_launcher_icons` package:
   ```yaml
   # Add to pubspec.yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   
   flutter_icons:
     android: true
     image_path: "assets/icon.png"
   ```
   
   Then run:
   ```powershell
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

## 🔐 Signing for Release

### Generate Keystore
```powershell
keytool -genkey -v -keystore blackwallet-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias blackwallet
```

### Configure Signing
1. Create `android/key.properties`:
   ```properties
   storePassword=YOUR_PASSWORD
   keyPassword=YOUR_PASSWORD
   keyAlias=blackwallet
   storeFile=blackwallet-release-key.jks
   ```

2. Update `android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       ...
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile file(keystoreProperties['storeFile'])
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
           }
       }
   }
   ```

## 🐛 Troubleshooting

### Build Errors

**Gradle sync failed**
```powershell
cd android
.\gradlew clean
cd ..
flutter clean
flutter pub get
```

**Minimum SDK version error**
- App requires minimum SDK 21 (Android 5.0+)
- Update device or emulator to Android 5.0 or higher

**Network error on device**
- Make sure backend is running
- Update `baseUrl` to your computer's IP address
- Ensure device is on same network as your computer

### Connection Issues

**Can't connect to backend from emulator**
- Verify backend is running on port 8000
- Use `10.0.2.2` instead of `localhost` for emulator
- Check `network_security_config.xml` includes 10.0.2.2

**Can't connect from physical device**
- Use your computer's actual IP address (not 127.0.0.1)
- Ensure device is on same WiFi network
- Check firewall settings allow incoming connections on port 8000

## 📋 Permissions Explained

| Permission | Purpose | Required |
|------------|---------|----------|
| INTERNET | Make HTTP requests to backend API | Yes |
| ACCESS_NETWORK_STATE | Check network connectivity | Recommended |
| WAKE_LOCK | Keep screen on during operations | Optional |

## 🔄 Updating Configuration

### Change Package Name
1. Update in all AndroidManifest.xml files
2. Update in build.gradle (applicationId)
3. Rename kotlin package directory
4. Update package in MainActivity.kt

### Change App Name
Update in `AndroidManifest.xml`:
```xml
android:label="YourNewAppName"
```

### Change Min/Target SDK
Update in `android/app/build.gradle`:
```gradle
minSdkVersion 21  // Change this
targetSdkVersion 34  // Change this
```

## ✅ Verification

After setup, verify everything works:

```powershell
# Clean and get dependencies
flutter clean
flutter pub get

# Check for issues
flutter doctor

# Build debug APK
flutter build apk --debug

# Install and run
flutter run
```

## 📦 Generated Files (Don't Edit)
- `GeneratedPluginRegistrant.java` - Auto-generated by Flutter
- `.gradle/` - Gradle cache
- `build/` - Build outputs
- `local.properties` - Local SDK paths

---

Your Android configuration is now complete and ready to use! 🎉
