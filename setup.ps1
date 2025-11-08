# Complete Setup Script for BlackWallet
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BlackWallet Complete Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Backend Setup
Write-Host "Step 1: Setting up Backend..." -ForegroundColor Yellow
Write-Host ""

Set-Location -Path $PSScriptRoot\ewallet_backend

if (Test-Path "venv") {
    Write-Host "Virtual environment already exists." -ForegroundColor Green
} else {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

Write-Host "Activating virtual environment..." -ForegroundColor Green
.\venv\Scripts\Activate.ps1

Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt

Write-Host ""
Write-Host "Initializing database with test data..." -ForegroundColor Yellow
python init_db.py

# Step 2: Flutter Setup
Write-Host ""
Write-Host "Step 2: Setting up Flutter..." -ForegroundColor Yellow
Write-Host ""

Set-Location -Path $PSScriptRoot

Write-Host "Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Start the backend server:" -ForegroundColor White
Write-Host "   .\start-backend.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. In a new terminal, run the Flutter app:" -ForegroundColor White
Write-Host "   flutter run" -ForegroundColor Yellow
Write-Host ""
Write-Host "Test Accounts:" -ForegroundColor Cyan
Write-Host "  - alice / alice123 (Balance: $1,000)" -ForegroundColor White
Write-Host "  - bob / bob123 (Balance: $500)" -ForegroundColor White
Write-Host "  - admin / admin123 (Balance: $10,000)" -ForegroundColor White
Write-Host ""
