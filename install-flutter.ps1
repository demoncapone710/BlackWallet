# Set install path
$flutterPath = "C:\src\flutter"
$zipUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.13.9-stable.zip"
$zipFile = "$env:TEMP\flutter.zip"

# Create install directory
if (!(Test-Path "C:\src")) {
    New-Item -ItemType Directory -Path "C:\src" -Force
}

# Download Flutter SDK
Write-Host "Downloading Flutter SDK..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile

# Extract SDK
Write-Host "Extracting Flutter SDK..."
Expand-Archive -Path $zipFile -DestinationPath "C:\src" -Force

# Add to system PATH
$flutterBin = "$flutterPath\bin"
$existingPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($existingPath -notlike "*$flutterBin*") {
    $newPath = "$existingPath;$flutterBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "Flutter path added to system PATH."
} else {
    Write-Host "Flutter path already in system PATH."
}

# Clean up
Remove-Item $zipFile

# Launch flutter doctor in new PowerShell window
Write-Host "Launching flutter doctor..."
Start-Process powershell -ArgumentList "flutter doctor" -NoNewWindow

Write-Host "Flutter SDK installed at $flutterPath"
Write-Host "Restart PowerShell to use the 'flutter' command."