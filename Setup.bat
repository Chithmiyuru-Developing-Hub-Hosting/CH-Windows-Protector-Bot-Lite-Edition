<# : batch portion
@echo off
title Protector Bot Advanced Setup Wizard
setlocal encoding=utf-8
set "CURRENT_DIR=%~dp0"
if "%~1" neq "InvisibleMode" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -ComObject WScript.Shell; $WshShell.Run('cmd.exe /c \"' + $MyInvocation.MyCommand.Path + '\" InvisibleMode', 0, $false)"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "$env:MY_APP_DIR='%CURRENT_DIR%'; iex ((Get-Content '%~f0' -Raw))"
goto :eof
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$ConfigPassword = "123"
$ConfigIntro = "3"
$ConfigIdle = "60"
$ConfigCount = "20"
$ConfigPath = "C:\Users\Public\.WindowsSecureVault"
$ConfigFile = Join-Path $ConfigPath "Protector_Config.txt"

if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match "^PASSWORD=(.*)$") { $ConfigPassword = $Matches[1].Trim() }
        if ($_ -match "^INTRO_DELAY=(.*)$") { $ConfigIntro = [int]$Matches[1].Trim() }
        if ($_ -match "^IDLE_TIMEOUT=(.*)$") { $ConfigIdle = [int]$Matches[1].Trim() }
        if ($_ -match "^COUNTDOWN=(.*)$") { $ConfigCount = [int]$Matches[1].Trim() }
        if ($_ -match "^VAULT_PATH=(.*)$") { $ConfigPath = $Matches[1].Trim() }
    }
}

$SetupForm = New-Object System.Windows.Forms.Form
$SetupForm.Text = "Protector Bot - Customizer Setup"
$SetupForm.Size = New-Object System.Drawing.Size(500, 600)
$SetupForm.StartPosition = "CenterScreen"
$SetupForm.FormBorderStyle = "FixedDialog"
$SetupForm.MaximizeBox = $false
$SetupForm.BackColor = [System.Drawing.Color]::FromArgb(218, 233, 252)

try {
    $DwmSignature = @"
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
"@
    $DwmAPI = Add-Type -MemberDefinition $DwmSignature -Name "DwmCornersSetup" -Namespace "Win11SetupAPI" -PassThru
    $CornerAttribute = 33 
    $RoundPreference = 3  
    [void]$DwmAPI::DwmSetWindowAttribute($SetupForm.Handle, $CornerAttribute, [ref]$RoundPreference, 4)
} catch {}

$Title = New-Object System.Windows.Forms.Label
$Title.Text = "CURRENT SYSTEM CONFIGURATION"
$Title.Font = New-Object System.Drawing.Font("Segoe UI Variable Display Semibold", 13)
$Title.ForeColor = [System.Drawing.Color]::FromArgb(25, 55, 90)
$Title.Location = New-Object System.Drawing.Point(30, 20)
$Title.Size = New-Object System.Drawing.Size(430, 30)
$SetupForm.Controls.Add($Title)

function Create-Input($LabelText, $TopPos, $CurrentVal) {
    $L = New-Object System.Windows.Forms.Label
    $L.Text = $LabelText
    $L.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Semibold", 9)
    $L.ForeColor = [System.Drawing.Color]::FromArgb(100, 120, 150)
    $L.Location = New-Object System.Drawing.Point(30, $TopPos)
    $L.Size = New-Object System.Drawing.Size(420, 18)
    $SetupForm.Controls.Add($L)

    $T = New-Object System.Windows.Forms.TextBox
    $T.Location = New-Object System.Drawing.Point(30, ($TopPos + 22))
    $T.Width = 420
    $T.Text = $CurrentVal
    $T.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 11)
    $T.BackColor = [System.Drawing.Color]::White
    $T.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $T.BorderStyle = "FixedSingle"
    $SetupForm.Controls.Add($T)
    return $T
}

$In_Pass = Create-Input "Lock Screen PIN / Password:" 65 $ConfigPassword
$In_Intro = Create-Input "Intro Message Delay (Seconds before Login Panel appears):" 125 $ConfigIntro
$In_Idle = Create-Input "Inactivity Timeout (Seconds before auto-logout/lock):" 185 $ConfigIdle
$In_Count = Create-Input "Threat Countdown Timer (Seconds allowed to input correct PIN):" 245 $ConfigCount
$In_Path = Create-Input "Secret Intruder Vault Path (Where pictures hide):" 305 $ConfigPath

$SetupDevLabel = New-Object System.Windows.Forms.Label
$SetupDevLabel.Text = "Developed by Chithmiyuru Development Hub"
$SetupDevLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Light", 11)
$SetupDevLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 130, 160)
$SetupDevLabel.Size = New-Object System.Drawing.Size(420, 25)
$SetupDevLabel.TextAlign = "MiddleCenter"
$SetupDevLabel.Location = New-Object System.Drawing.Point(30, 525)
$SetupForm.Controls.Add($SetupDevLabel)

$SaveBtn = New-Object System.Windows.Forms.Button
$SaveBtn.Text = "UPDATE & APPLY CHANGES"
$SaveBtn.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Semibold", 11)
$SaveBtn.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$SaveBtn.ForeColor = [System.Drawing.Color]::White
$SaveBtn.Location = New-Object System.Drawing.Point(30, 385)
$SaveBtn.Size = New-Object System.Drawing.Size(420, 45)
$SaveBtn.FlatStyle = "Flat"
$SaveBtn.FlatAppearance.BorderSize = 0

$SaveBtn.Add_Click({
    $TargetVault = $In_Path.Text.Trim()
    if ([string]::IsNullOrEmpty($In_Pass.Text) -or [string]::IsNullOrEmpty($TargetVault)) {
        [System.Windows.Forms.MessageBox]::Show("Please ensure Password and Vault Path are valid!", "Error", "OK", "Error")
        return
    }
    if (-not (Test-Path $TargetVault)) {
        $Dir = New-Item -ItemType Directory -Path $TargetVault -Force
        $Dir.Attributes = 'Hidden', 'System'
    }
    $TargetConfig = Join-Path $TargetVault "Protector_Config.txt"
    $Data = "PASSWORD=$($In_Pass.Text.Trim())`nINTRO_DELAY=$($In_Intro.Text.Trim())`nIDLE_TIMEOUT=$($In_Idle.Text.Trim())`nCOUNTDOWN=$($In_Count.Text.Trim())`nVAULT_PATH=$TargetVault"
    $Data | Out-File -FilePath $TargetConfig -Encoding utf8
    [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully!", "Success", "OK", "Information")
})

$StartupBtn = New-Object System.Windows.Forms.Button
$StartupBtn.Text = "ADD TO STARTUP APP"
$StartupBtn.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Semibold", 11)
$StartupBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 220)
$StartupBtn.ForeColor = [System.Drawing.Color]::White
$StartupBtn.Location = New-Object System.Drawing.Point(30, 445)
$StartupBtn.Size = New-Object System.Drawing.Size(420, 45)
$StartupBtn.FlatStyle = "Flat"
$StartupBtn.FlatAppearance.BorderSize = 0

$StartupBtn.Add_Click({
    $CurrentDir = $env:MY_APP_DIR
    if (-not $CurrentDir) { $CurrentDir = $Global:PSScriptRoot }
    $TargetBat = Join-Path $CurrentDir "OpenInstructions.bat"
    
    if (Test-Path $TargetBat) {
        Start-Process "cmd.exe" -ArgumentList "/c `"$TargetBat`"" -WindowStyle Hidden
    } else {
        [System.Windows.Forms.MessageBox]::Show("OpenInstructions.bat file missing from current directory!", "Error", "OK", "Error")
    }
})

$SetupForm.Controls.Add($SaveBtn)
$SetupForm.Controls.Add($StartupBtn)
$SetupForm.ShowDialog() | Out-Null
