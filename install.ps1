Write-Host ""
Write-Host "ByHun Installer" -ForegroundColor Cyan
Write-Host "-----------------------------"
Write-Host "Downloading and installing ByHun..."
Write-Host ""

# URLs and paths
$zipUrl = "https://byhun.gt.tc/ByHun_WindowsInstaller.zip"
$tempDir = Join-Path $env:TEMP "ByHunInstaller"
$zipPath = Join-Path $tempDir "ByHun_WindowsInstaller.zip"
$exePath = Join-Path $tempDir "ByHun_WindowsInstaller.exe"

# Create temp directory
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Download ZIP
Write-Host "Downloading installer..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath

# Extract ZIP
Write-Host "Extracting files..."
Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

# Check installer
if (-Not (Test-Path $exePath)) {
    Write-Host "Installer not found after extraction." -ForegroundColor Red
    Write-Host "Installation aborted."
    exit 1
}

# Run installer
Write-Host "Launching installer..."
Start-Process -FilePath $exePath

Write-Host ""
Write-Host "Installer started successfully." -ForegroundColor Green
