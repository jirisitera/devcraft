$ErrorActionPreference = "Stop"
function Convert-PngToIco {
    param([Parameter(Mandatory = $true)][string]$PngPath, [Parameter(Mandatory = $true)][string]$IcoPath)
    $pngBytes = [System.IO.File]::ReadAllBytes($PngPath)
    if ($pngBytes.Length -lt 24) {
        Write-Error "PNG file '$PngPath' is too small to be valid."
        return
    }
    $pngSignature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
    for ($i = 0; $i -lt $pngSignature.Length; $i++) {
        if ($pngBytes[$i] -ne $pngSignature[$i]) {
            Write-Error "File '$PngPath' is not a valid PNG."
            return
        }
    }
    $width = [System.BitConverter]::ToUInt32([byte[]]($pngBytes[19], $pngBytes[18], $pngBytes[17], $pngBytes[16]), 0)
    $height = [System.BitConverter]::ToUInt32([byte[]]($pngBytes[23], $pngBytes[22], $pngBytes[21], $pngBytes[20]), 0)
    $iconWidth = if ($width -ge 256) { 0 } else { [byte]$width }
    $iconHeight = if ($height -ge 256) { 0 } else { [byte]$height }
    try {
        $stream = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $writer = New-Object System.IO.BinaryWriter($stream)
        # ICONDIR
        $writer.Write([UInt16]0) # Reserved
        $writer.Write([UInt16]1) # Type (icon)
        $writer.Write([UInt16]1) # Count
        # ICONDIR ENTRY
        $writer.Write([byte]$iconWidth)
        $writer.Write([byte]$iconHeight)
        $writer.Write([byte]0) # Color count
        $writer.Write([byte]0) # Reserved
        $writer.Write([UInt16]1) # Color planes
        $writer.Write([UInt16]32) # Bits per pixel
        $writer.Write([UInt32]$pngBytes.Length) # Bytes in resource
        $writer.Write([UInt32]22) # Offset: 6 + 16
        # PNG payload
        $writer.Write($pngBytes)
        $writer.Flush()
    } catch {
        Write-Error "Failed to convert PNG to ICO: $_"
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
    }
}
# verify ps2exe is installed
try { $null = Get-Command ps2exe -ErrorAction Stop }
catch {
    Write-Host "ps2exe is not installed or not in PATH." -ForegroundColor Yellow
    Write-Host "Attempting to install ps2exe from PSGallery..." -ForegroundColor Cyan
    try {
        Install-Module ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "ps2exe installed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to install ps2exe. Please install it manually: Install-Module ps2exe -Scope CurrentUser -Force"
        exit 1
    }
}
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$scriptPath = Join-Path $scriptRoot "run.ps1"
$clientDir = Join-Path $projectRoot "client"
if (-not (Test-Path -LiteralPath $clientDir)) {
    New-Item -ItemType Directory -Path $clientDir -Force | Out-Null
}
$outputPath = Join-Path $clientDir "devcraft.exe"
$iconIcoPath = Join-Path $projectRoot "assets\icon.ico"
$iconPngPath = Join-Path $projectRoot "assets\icon.png"
$iconForBuild = $null
# verify the input script exists
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Error "run.ps1 not found at $scriptPath"
    exit 1
}
# resolve icon source
if (Test-Path -LiteralPath $iconIcoPath) {
    Write-Host "Using ICO icon from: $iconIcoPath" -ForegroundColor Cyan
    $iconForBuild = $iconIcoPath
} elseif (Test-Path -LiteralPath $iconPngPath) {
    Write-Host "Converting PNG icon to ICO: $iconIcoPath" -ForegroundColor Cyan
    Convert-PngToIco -PngPath $iconPngPath -IcoPath $iconIcoPath
    if (Test-Path -LiteralPath $iconIcoPath) {
        $iconForBuild = $iconIcoPath
    }
} else {
    Write-Host "No icon file found in assets (expected icon.ico or icon.png)." -ForegroundColor Yellow
    Write-Host "Proceeding without embedded EXE icon..." -ForegroundColor Yellow
}
Write-Host "Compiling run.ps1 to EXE..." -ForegroundColor Green
try {
    $ps2exeArgs = @{
        InputFile   = $scriptPath
        OutputFile  = $outputPath
        ErrorAction = "Stop"
        noConsole   = $true
    }
    if ($iconForBuild) {
        $ps2exeArgs.IconFile = $iconForBuild
    }
    ps2exe @ps2exeArgs
    if (Test-Path -LiteralPath $outputPath) {
        $fileSize = (Get-Item -LiteralPath $outputPath).Length / 1MB
        Write-Host "Build successful!" -ForegroundColor Green
        Write-Host "Output: $outputPath" -ForegroundColor Cyan
        Write-Host "Size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Error during compilation: $($_.Exception.Message)"
    exit 1
}
