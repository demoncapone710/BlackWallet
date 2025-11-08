# Android Build Verification Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BlackWallet Android Setup Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter
Write-Host "Checking Flutter installation..." -ForegroundColor Yellow
flutter --version

Write-Host ""
Write-Host "Checking Flutter doctor..." -ForegroundColor Yellow
flutter doctor

Write-Host ""
Write-Host "Listing connected devices..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Android Files Created:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$androidFiles = @(
    "android\app\src\main\AndroidManifest.xml",
    "android\app\src\main\kotlin\com\example\blackwallet\MainActivity.kt",
    "android\app\src\main\res\values\styles.xml",
    "android\app\src\main\res\xml\network_security_config.xml",
    "android\app\build.gradle",
    "android\build.gradle",
    "android\settings.gradle",
    "android\gradle.properties"
)

foreach ($file in $androidFiles) {
    $fullPath = Join-Path $PSScriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "[OK] $file" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $file" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Make sure backend is running:" -ForegroundColor White
Write-Host "   .\start-backend.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Connect Android device or start emulator" -ForegroundColor White
Write-Host ""
Write-Host "3. Run the app:" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Or build APK:" -ForegroundColor White
Write-Host "   flutter build apk --debug" -ForegroundColor Yellow
Write-Host ""
