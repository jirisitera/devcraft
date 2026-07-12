$ErrorActionPreference = "Stop"
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "        Devcraft Installer" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
function New-Shortcut {
    param ([Parameter(Mandatory = $true)][string]$LinkPath, [Parameter(Mandatory = $true)][string]$TargetPath, [Parameter(Mandatory = $true)][string]$WorkingDirectory)
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($LinkPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.WorkingDirectory = $WorkingDirectory
    $Shortcut.Save()
}
# determine installation directory
$defaultInstallDir = "$env:LOCALAPPDATA\Devcraft"
$installDir = Read-Host "Enter installation directory [$defaultInstallDir]"
if ([string]::IsNullOrWhiteSpace($installDir)) {
    $installDir = $defaultInstallDir
}
$installDir = [System.IO.Path]::GetFullPath($installDir)
Write-Host "Installing to: $installDir" -ForegroundColor Yellow
# check for existing installation
$existingInstall = Test-Path -LiteralPath $installDir
if ($existingInstall) {
    $installedVersion = $null
    $installedVersionPath = Join-Path $installDir "client\version.txt"
    if (Test-Path -LiteralPath $installedVersionPath) {
        $installedVersion = (Get-Content -LiteralPath $installedVersionPath -Raw).Trim()
    }
    if ($installedVersion) {
        Write-Host "Existing installation detected. Installed version: $installedVersion" -ForegroundColor Yellow
    } else {
        Write-Host "Existing installation detected, but the installed version could not be determined." -ForegroundColor Yellow
    }
    $updateChoice = Read-Host "Update this installation now? (Y/n)"
    if (-not [string]::IsNullOrWhiteSpace($updateChoice) -and $updateChoice.ToLower() -eq "n") {
        Write-Host "Exiting without updating." -ForegroundColor Yellow
        exit 0
    }
}
if (-not (Test-Path -LiteralPath $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
# fetch release info
$repoOwner = "jirisitera"
$repoName = "devcraft"
Write-Host "Fetching latest release information..."
$releaseUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
try {
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ "User-Agent" = "installer" }
} catch {
    Write-Host "Failed to fetch release info from GitHub. Please check your internet connection." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
$asset = $release.assets | Where-Object { $_.name -eq "devcraft-windows.zip" }
if (-not $asset) {
    Write-Host "Could not find 'devcraft-windows.zip' in the latest release." -ForegroundColor Red
    exit 1
}
$downloadUrl = $asset.browser_download_url
# use a random temporary folder to avoid conflicts
$tempId = [System.IO.Path]::GetRandomFileName()
$tempZipPath = Join-Path $env:TEMP "devcraft-$tempId.zip"
$tempExtractDir = Join-Path $env:TEMP "devcraft-$tempId-extract"
# download zipped release file
Write-Host "Downloading release $($release.tag_name)..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZipPath
} catch {
    Write-Host "Failed to download the release." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
# extract and install zip archive
Write-Host "Extracting files..."
try {
    New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null
    Expand-Archive -Path $tempZipPath -DestinationPath $tempExtractDir -Force
    $backupDir = "$env:TEMP\devcraft_backup_$tempId"
    $playerDataPaths = @("game\saves", "game\options.txt", "game\resourcepacks", "game\screenshots", "game\logs")
    if (Test-Path -LiteralPath $installDir) {
        Write-Host "Backing up player data..."
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        foreach ($p in $playerDataPaths) {
            $src = Join-Path $installDir $p
            if (Test-Path -LiteralPath $src) {
                $dest = Join-Path $backupDir $p
                $destParent = Split-Path $dest -Parent
                if (-not (Test-Path $destParent)) {
                    New-Item -ItemType Directory -Path $destParent -Force | Out-Null
                }
                Copy-Item -Path $src -Destination $destParent -Recurse -Force
            }
        }
        Write-Host "Removing old installation..."
        Remove-Item -Path "$installDir\*" -Recurse -Force
    }
    Write-Host "Installing to $installDir..."
    Copy-Item -Path "$tempExtractDir\*" -Destination $installDir -Recurse -Force
    if (Test-Path -LiteralPath $backupDir) {
        Write-Host "Restoring player data..."
        Copy-Item -Path "$backupDir\*" -Destination $installDir -Recurse -Force
        Remove-Item -Path $backupDir -Recurse -Force
    }
} catch {
    Write-Host "An error occurred during extraction or installation." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
} finally {
    # file cleanup
    Write-Host "Cleaning up temporary files..."
    if (Test-Path $tempZipPath) {
        Remove-Item -Path $tempZipPath -Force
    }
    if (Test-Path $tempExtractDir) {
        Remove-Item -Path $tempExtractDir -Recurse -Force
    }
}
# create shortcuts
$createDesktop = Read-Host "Create Desktop shortcut? (Y/n)"
if ([string]::IsNullOrWhiteSpace($createDesktop) -or $createDesktop.ToLower() -eq "y") {
    Write-Host "Creating Desktop shortcut..."
    $desktopLink = "$env:USERPROFILE\Desktop\Devcraft.lnk"
    New-Shortcut -LinkPath $desktopLink -TargetPath "$installDir\devcraft.exe" -WorkingDirectory $installDir
}
$createStartMenu = Read-Host "Create Start Menu shortcut? (Y/n)"
if ([string]::IsNullOrWhiteSpace($createStartMenu) -or $createStartMenu.ToLower() -eq "y") {
    Write-Host "Creating Start Menu shortcut..."
    $startMenuDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Devcraft"
    if (-not (Test-Path $startMenuDir)) {
        New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
    }
    $startMenuLink = "$startMenuDir\Devcraft.lnk"
    New-Shortcut -LinkPath $startMenuLink -TargetPath "$installDir\devcraft.exe" -WorkingDirectory $installDir
}
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "You can now run Devcraft from your Start Menu or Desktop." -ForegroundColor Green
