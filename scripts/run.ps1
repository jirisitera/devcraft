$ErrorActionPreference = "Stop"
Add-Type -AssemblyName WindowsBase
if ($Host.Name -match "PSRunspace") { $ProgressPreference = "SilentlyContinue" }
function Write-LauncherStatus {
    param([Parameter(Mandatory = $true)][string]$Message)
    if ($Host.Name -notmatch "PSRunspace") { Write-Host "[Launcher] $Message" -ForegroundColor Cyan }
}
function Write-LauncherError {
    param([Parameter(Mandatory = $true)][string]$Message, [switch]$Exit)
    [System.Windows.MessageBox]::Show($Message, "Launcher Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    if ($Exit) { exit 1 }
}
function Get-ScriptRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($PSCommandPath) { return Split-Path -Parent $PSCommandPath }
    if ($MyInvocation.MyCommand.Path) { return Split-Path -Parent $MyInvocation.MyCommand.Path }
    return [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd("\")
}
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName System.Xaml
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32UI {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@
# download portablemc
$repo = "theorzr/portablemc"
$url = "https://api.github.com/repos/$repo/releases/latest"
$rootDir = Get-ScriptRoot
if ((Split-Path -Leaf $rootDir).ToLower() -eq "scripts") { $rootDir = Split-Path -Parent $rootDir }
$downloadDir = Join-Path $rootDir "client"
$zipPath = Join-Path $downloadDir "pmc-latest.zip"
$extractDir = Join-Path $downloadDir ".extracted"
$exePath = Join-Path $extractDir "portablemc.exe"
if (-not (Test-Path -LiteralPath $downloadDir)) { New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $exePath)) {
    try {
        Write-LauncherStatus "Resolving latest PortableMC Windows build..."
        $release = Invoke-RestMethod -Uri $url -Headers @{ "User-Agent" = "pmc-bootstrap" }
        $asset = $release.assets | Where-Object { $_.name -like "portablemc-*-windows-x86_64-msvc.zip" } | Select-Object -First 1
        if (-not $asset) { Write-LauncherError -Message "No Windows x86_64 asset found in latest release." -Exit }
        $assetUrl = $asset.browser_download_url
        Write-LauncherStatus "Downloading from: $assetUrl"
        Invoke-WebRequest -Uri $assetUrl -OutFile $zipPath
        if (Test-Path -LiteralPath $extractDir) { Remove-Item -LiteralPath $extractDir -Recurse -Force }
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
        Write-LauncherStatus "Extracting archive..."
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        if (-not (Test-Path -LiteralPath $exePath)) { Write-LauncherError -Message "portablemc.exe was not found after extraction." -Exit }
        Write-LauncherStatus "Download successful!"
    }
    catch { Write-LauncherError -Message "Failed to setup PortableMC: $($_.Exception.Message)" -Exit }
}
# username input UI
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" 
        Title="Minecraft Launcher" Width="480" Height="320" 
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" 
        Background="Transparent" Foreground="#1C1C1C" WindowStyle="None" 
        AllowsTransparency="True" Opacity="1" UseLayoutRounding="True" SnapsToDevicePixels="True"
        Topmost="True" FocusManager.FocusedElement="{Binding ElementName=UsernameBox}">
    <Window.Resources>
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="500"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1084D7"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource ModernButton}">
            <Setter Property="Background" Value="#fafafa"/>
            <Setter Property="Foreground" Value="#1C1C1C"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#ffffff"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#ffffff"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#1C1C1C"/>
            <Setter Property="CaretBrush" Value="#0078D4"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="BorderBrush" Value="#D1D1D1"/>
            <Setter Property="Padding" Value="14,12"/>
            <Setter Property="FontSize" Value="16"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsFocused" Value="True">
                                <Setter TargetName="border" Property="BorderBrush" Value="#0078D4"/>
                                <Setter TargetName="border" Property="BorderThickness" Value="2"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border x:Name="RootShell" CornerRadius="28" ClipToBounds="True" Background="Transparent">
        <Grid>
            <Grid.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                    <GradientStop Color="#FFBFD3E6" Offset="0"/>
                    <GradientStop Color="#FFD8E7F4" Offset="0.55"/>
                    <GradientStop Color="#FFC6DCEB" Offset="1"/>
                </LinearGradientBrush>
            </Grid.Background>
            <Ellipse Width="220" Height="220" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="-60,-85,0,0" Fill="#4DA6E3FF" IsHitTestVisible="False">
                <Ellipse.Effect><BlurEffect Radius="36"/></Ellipse.Effect>
            </Ellipse>
            <Ellipse Width="200" Height="200" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,-45,-70" Fill="#4DB8FFD2" IsHitTestVisible="False">
                <Ellipse.Effect><BlurEffect Radius="34"/></Ellipse.Effect>
            </Ellipse>
            <Border HorizontalAlignment="Stretch" VerticalAlignment="Stretch" Margin="18" CornerRadius="18" BorderThickness="1" BorderBrush="#AAFFFFFF" Background="#80FFFFFF" Padding="16">
                <Border.Effect>
                    <DropShadowEffect BlurRadius="20" ShadowDepth="4" Opacity="0.18" Color="#334155"/>
                </Border.Effect>
                <Grid>
                    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Stretch" Margin="12,0,12,0">
                        <TextBlock Text="Minecraft Launcher" FontSize="30" FontWeight="SemiBold" Foreground="#0F4C81" Margin="0,0,0,8"/>
                        <TextBlock Text="Please enter your username:" FontSize="14" FontWeight="Normal" Margin="0,0,0,20" Foreground="#3F4A59"/>
                        <TextBox x:Name="UsernameBox" Style="{StaticResource ModernTextBox}" Margin="0,0,0,18" MaxLength="16"/>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                            <Button x:Name="OkButton" Content="Launch" Width="118" Height="40" Style="{StaticResource ModernButton}" Margin="0,0,12,0"/>
                            <Button x:Name="CancelButton" Content="Cancel" Width="118" Height="40" Style="{StaticResource SecondaryButton}" Margin="0"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>
            </Border>
        </Grid>
    </Border>
</Window>
"@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$rootShell = $window.FindName("RootShell")
$usernameBox = $window.FindName("UsernameBox")
$okButton = $window.FindName("OkButton")
$cancelButton = $window.FindName("CancelButton")
$usernameBox.Add_PreviewTextInput({
        param($eventSender, $e)
        if ($e.Text -notmatch "^[A-Za-z0-9_]+$") { $e.Handled = $true }
    })
[System.Windows.DataObject]::AddPastingHandler($usernameBox, {
        param($eventSender, $e)
        if ($e.DataObject.GetDataPresent([System.Windows.DataFormats]::Text)) {
            $pasteText = $e.DataObject.GetData([System.Windows.DataFormats]::Text)
            if ($pasteText -notmatch "^[A-Za-z0-9_]+$") { $e.CancelCommand() }
        }
        else { $e.CancelCommand() }
    })
function Set-RoundedShellClip {
    param([Parameter(Mandatory = $true)]$Shell, [double]$Radius = 28)
    $rect = New-Object System.Windows.Rect(0, 0, $Shell.ActualWidth, $Shell.ActualHeight)
    $Shell.Clip = New-Object System.Windows.Media.RectangleGeometry($rect, $Radius, $Radius)
}
$window.Add_SizeChanged({ Set-RoundedShellClip -Shell $rootShell })
$window.Add_ContentRendered({
        Set-RoundedShellClip -Shell $rootShell
        $hwnd = New-Object System.Windows.Interop.WindowInteropHelper($window)
        [Win32UI]::SetForegroundWindow($hwnd.Handle) | Out-Null
        [void]$window.Activate()
        [void]$usernameBox.Focus()
        [void][System.Windows.Input.Keyboard]::Focus($usernameBox)
    })
$userClickedOk = $false
$okButton.Add_Click({ $script:userClickedOk = $true; $window.Close() })
$cancelButton.Add_Click({ $script:userClickedOk = $false; $window.Close() })
$usernameBox.Add_KeyDown({ if ($_.Key -eq "Return") { $script:userClickedOk = $true; $window.Close() } })
$window.ShowDialog() | Out-Null
if (-not $userClickedOk) {
    Write-LauncherStatus "Name selection cancelled. Exiting launch sequence."
    exit 0
}
$pmcUser = $usernameBox.Text
if ([string]::IsNullOrWhiteSpace($pmcUser)) {
    Write-LauncherStatus "No username specified, using randomly generated name instead..."
    $pmcUser = "player$((Get-Random -Minimum 100 -Maximum 999))"
}
if ($pmcUser.Length -lt 3 -or $pmcUser.Length -gt 16 -or $pmcUser -notmatch "^[A-Za-z0-9_]+$") {
    Write-LauncherError -Message "Invalid username. Use 3 to 16 characters (letters, numbers, and underscores only)." -Exit
}
# download required mods
$modsConfigPath = Join-Path $rootDir "game\mods.json"
if (Test-Path -LiteralPath $modsConfigPath) {
    Write-LauncherStatus "Checking for required mods..."
    try {
        $modsConfig = Get-Content -Raw -Path $modsConfigPath | ConvertFrom-Json
        if ($null -ne $modsConfig -and $null -ne $modsConfig.mods) {
            $modsDir = Join-Path $rootDir "game\mods"
            if (-not (Test-Path -LiteralPath $modsDir)) {
                New-Item -ItemType Directory -Path $modsDir -Force | Out-Null
            }
            foreach ($mod in $modsConfig.mods) {
                if ($null -ne $mod.filename -and $null -ne $mod.url) {
                    $modDestPath = Join-Path $modsDir $mod.filename
                    if (-not (Test-Path -LiteralPath $modDestPath)) {
                        Write-LauncherStatus "Downloading mod: $($mod.filename)..."
                        try {
                            Invoke-WebRequest -Uri $mod.url -OutFile $modDestPath -UseBasicParsing
                        }
                        catch {
                            Write-LauncherError -Message "Failed to download mod $($mod.filename)."
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-LauncherError -Message "Failed to parse mods.json configuration."
    }
}
# boot up game
Write-LauncherStatus "Booting up Minecraft as user '$pmcUser'..."
$pmcArgs = @("start", "neoforge:1.21.1", "--mc-dir", "$(Join-Path $rootDir 'game')", "--username", "$pmcUser", "--disable-chat")
$process = Start-Process -FilePath $exePath -ArgumentList $pmcArgs -NoNewWindow -Wait -PassThru
exit $process.ExitCode
