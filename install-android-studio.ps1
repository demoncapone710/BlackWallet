# Set download URL and paths
$installerUrl = "https://redirector.gvt1.com/edgedl/android/studio/install/2023.1.1.26/android-studio-2023.1.1.26-windows.exe"
$installerPath = "$env:TEMP\android-studio-installer.exe"
$installDir = "C:\Program Files\Android\Android Studio"
$studioBin = "$installDir\bin"

# Download Android Studio installer
Write-Host "Downloading Android Studio installer..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Launch installer (manual install required)
Write-Host "Launching Android Studio installer..."
Start-Process -FilePath $installerPath -Wait

# Add Android Studio to system PATH
$existingPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($existingPath -notlike "*$studioBin*") {
    $newPath = "$existingPath;$studioBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "Android Studio path added to system PATH."
} else {
    Write-Host "Android Studio path already in system PATH."
}

# Clean up installer
Remove-Item $installerPath

Write-Host "Android Studio installed and configured."
Write-Host "Restart PowerShell to use Android Studio from the command line."