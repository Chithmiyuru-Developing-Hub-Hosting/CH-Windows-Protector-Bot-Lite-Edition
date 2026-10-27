<# : batch portion
@echo off
title Windows Protector Bot
setlocal encoding=utf-8
cd /d "%~dp0"
:LockWatchdogLoop
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0' -Raw))"
if exist "C:\Users\Public\.WindowsSecureVault\unlock_flag.txt" (
    del "C:\Users\Public\.WindowsSecureVault\unlock_flag.txt"
    goto :eof
)
goto :LockWatchdogLoop
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Media

$KeyboardHookSignatures = @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    public static void SetHook() { _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(System.Diagnostics.Process.GetCurrentProcess().MainModule.ModuleName), 0); }
    public static void ReleaseHook() { UnhookWindowsHookEx(_hookID); }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            int vkCode = Marshal.ReadInt32(lParam);
            Keys key = (Keys)vkCode;
            if (key == Keys.LWin || key == Keys.RWin || 
                (Control.ModifierKeys == Keys.Alt && key == Keys.Tab) || 
                (Control.ModifierKeys == Keys.Alt && key == Keys.F4) || 
                key == Keys.Escape) {
                return (IntPtr)1;
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@
Add-Type -TypeDefinition $KeyboardHookSignatures -ReferencedAssemblies "System.Windows.Forms"

$Win32Signatures = @"
[DllImport("avicap32.dll", EntryPoint = "capCreateCaptureWindowA")]
public static extern IntPtr CreateCaptureWindow(string name, int style, int x, int y, int w, int h, IntPtr parent, int id);
[DllImport("user32.dll")]
public static extern bool SendMessage(IntPtr hWnd, uint Msg, int wParam, int lParam);
[DllImport("user32.dll")]
public static extern bool SendMessage(IntPtr hWnd, uint Msg, int wParam, IntPtr lParam);
"@
$Win32 = Add-Type -MemberDefinition $Win32Signatures -Name "Win32Webcam" -Namespace "Win32Api" -PassThru

$Global:vaultPath = "C:\Users\Public\.WindowsSecureVault"
$ConfigFile = Join-Path $Global:vaultPath "Protector_Config.txt"
$UnlockFlag = Join-Path $Global:vaultPath "unlock_flag.txt"

if (Test-Path $UnlockFlag) { Remove-Item $UnlockFlag -Force }

if (-not (Test-Path $ConfigFile)) {
    [System.Windows.Forms.MessageBox]::Show("Configuration file missing from Vault! Please run Setup.bat first.", "Error", "OK", "Error")
    Exit
}

$Global:configPassword = "123"
$Global:introDelay = 3
$Global:idleCount = 60
$Global:timerCount = 20
$Global:appDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Get-Content $ConfigFile | ForEach-Object {
    $Line = $_.Trim()
    if ($Line -match "^PASSWORD=(.*)$") { $Global:configPassword = $Matches[1].Trim() }
    if ($Line -match "^INTRO_DELAY=(.*)$") { $Global:introDelay = [int]$Matches[1].Trim() }
    if ($Line -match "^IDLE_TIMEOUT=(.*)$") { $Global:idleCount = [int]$Matches[1].Trim() }
    if ($Line -match "^COUNTDOWN=(.*)$") { $Global:timerCount = [int]$Matches[1].Trim() }
    if ($Line -match "^VAULT_PATH=(.*)$") { $Global:vaultPath = $Matches[1].Trim() }
    if ($Line -match "^APP_DIR=(.*)$") { $Global:appDir = $Matches[1].Trim() }
}

[Environment]::CurrentDirectory = $Global:appDir

if (-not (Test-Path $Global:vaultPath)) {
    $Dir = New-Item -ItemType Directory -Path $Global:vaultPath -Force
    $Dir.Attributes = 'Hidden', 'System'
}

try {
    $MyBatchPath = Join-Path $Global:appDir "Main.bat"
    if (Test-Path $MyBatchPath) {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsProtectorBot" -Value "`"$MyBatchPath`"" -ErrorAction SilentlyContinue
    }
} catch {}

$Sapi = New-Object System.Speech.Synthesis.SpeechSynthesizer

function Block-Bypass-Initial {
    try {
        Get-Process -Name "taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force
        Get-Process -Name "explorer" -ErrorAction SilentlyContinue | Stop-Process -Force
    } catch {}
}

function Block-Bypass-Continuous {
    try { Get-Process -Name "taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force } catch {}
}

function Restore-System {
    try { Start-Process "explorer.exe" -ErrorAction SilentlyContinue } catch {}
}

function Write-SecurityLog ($Message) {
    try {
        $LogPath = Join-Path $Global:vaultPath "Security_Logs.txt"
        "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
    } catch {}
}

function Verify-Password ($InputText) {
    if ([string]::IsNullOrEmpty($InputText)) { return $false }
    return ($InputText -eq $Global:configPassword)
}

function Maximize-Volume {
    try {
        $MuteScript = @"
        [DllImport("user32.dll")]
        public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
"@
        $VolAPI = Add-Type -MemberDefinition $MuteScript -Name "VolControl" -Namespace "WinAPI" -PassThru
        for ($i = 0; $i -lt 50; $i++) {
            $VolAPI::keybd_event(0xAF, 0, 0, 0)
            $VolAPI::keybd_event(0xAF, 0, 2, 0)
        }
    } catch {}
}

function Capture-Intruder {
    try {
        $Hwnd = $Win32::CreateCaptureWindow("Webcam", 0, 0, 0, 640, 480, [IntPtr]::Zero, 0)
        if ($Hwnd -ne [IntPtr]::Zero -and $Win32::SendMessage($Hwnd, 0x40A, 0, 0)) {
            Start-Sleep -Milliseconds 1200 
            $Filename = "Intruder_$((Get-Date).ToString('yyyyMMdd_HHmmss')).jpg"
            $Path = Join-Path $Global:vaultPath $Filename
            $PtrPath = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($Path)
            try {
                [void]$Win32::SendMessage($Hwnd, 0x419, 0, $PtrPath)
                Write-SecurityLog "Intruder snapshot saved."
            } finally { [System.Runtime.InteropServices.Marshal]::FreeHGlobal($PtrPath); [void]$Win32::SendMessage($Hwnd, 0x40B, 0, 0) }
        }
    } catch { Write-SecurityLog "Webcam capture failed: $_" }
}
$Form = New-Object System.Windows.Forms.Form
$Form.FormBorderStyle = "None"
$Form.WindowState = "Maximized"
$Form.BackColor = [System.Drawing.Color]::FromArgb(218, 233, 252)
$Form.Opacity = 0.0

try {
    $DwmSignature = @"
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
"@
    $DwmAPI = Add-Type -MemberDefinition $DwmSignature -Name "DwmCorners" -Namespace "Win11API" -PassThru
    $CornerAttribute = 33 
    $RoundPreference = 3  
    [void]$DwmAPI::DwmSetWindowAttribute($Form.Handle, $CornerAttribute, [ref]$RoundPreference, 4)
} catch {}

$MainLabel = New-Object System.Windows.Forms.Label
$MainLabel.Text = "Welcome to Windows"
$MainLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Display Light", 48)
$MainLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 55, 90)
$MainLabel.TextAlign = "MiddleCenter"
$MainLabel.Dock = "Fill"
$Form.Controls.Add($MainLabel)

$Panel = New-Object System.Windows.Forms.Panel
$Panel.Size = New-Object System.Drawing.Size(440, 280)
$Panel.Visible = $false
$Panel.BackColor = [System.Drawing.Color]::FromArgb(245, 250, 255)
$Panel.BorderStyle = "FixedSingle"

$SubCardLabel = New-Object System.Windows.Forms.Label
$SubCardLabel.Text = "ENTER SECURITY PIN"
$SubCardLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Semibold", 10)
$SubCardLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 140, 170)
$SubCardLabel.Location = New-Object System.Drawing.Point(35, 30)
$SubCardLabel.Size = New-Object System.Drawing.Size(370, 20)
$Panel.Controls.Add($SubCardLabel)

$Txt = New-Object System.Windows.Forms.TextBox
$Txt.PasswordChar = '●'
$Txt.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 18)
$Txt.Width = 370
$Txt.Location = New-Object System.Drawing.Point(35, 65)
$Txt.BackColor = [System.Drawing.Color]::White
$Txt.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$Txt.BorderStyle = "FixedSingle"
$Panel.Controls.Add($Txt)

$Txt.Add_KeyDown({
    if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $_.SuppressKeyPress = $true
        $Btn.PerformClick()
    }
})

$Btn = New-Object System.Windows.Forms.Button
$Btn.Text = "Sign In"
$Btn.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Semibold", 12)
$Btn.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 220)
$Btn.ForeColor = [System.Drawing.Color]::White
$Btn.Location = New-Object System.Drawing.Point(35, 155)
$Btn.Size = New-Object System.Drawing.Size(370, 50)
$Btn.FlatStyle = "Flat"
$Btn.FlatAppearance.BorderSize = 0
$Panel.Controls.Add($Btn)

$LblTimer = New-Object System.Windows.Forms.Label
$LblTimer.Font = New-Object System.Drawing.Font("Segoe UI Variable Display Semibold", 54)
$LblTimer.ForeColor = [System.Drawing.Color]::FromArgb(235, 40, 40)
$LblTimer.Size = New-Object System.Drawing.Size(300, 100)
$LblTimer.TextAlign = "MiddleCenter"
$LblTimer.Visible = $false
$Form.Controls.Add($Panel)
$Form.Controls.Add($LblTimer)

$DevLabel = New-Object System.Windows.Forms.Label
$DevLabel.Text = "Developed by Chithmiyuru Development Hub"
$DevLabel.Font = New-Object System.Drawing.Font("Segoe UI Variable Text Light", 11)
$DevLabel.ForeColor = [System.Drawing.Color]::FromArgb(110, 130, 160)
$DevLabel.Size = New-Object System.Drawing.Size(500, 30)
$DevLabel.TextAlign = "MiddleCenter"
$Form.Controls.Add($DevLabel)

$Global:TargetX = 0
$Global:TargetY = 0
$Global:CurrentY = 0

$Form.Add_Load({
    $Global:TargetX = (($Form.Width - $Panel.Width) / 2)
    $Global:TargetY = (($Form.Height - $Panel.Height) / 2 + 80)
    $Global:CurrentY = $Form.Height 
    
    $Panel.Location = New-Object System.Drawing.Point($Global:TargetX, $Global:CurrentY)
    $LblTimer.Location = New-Object System.Drawing.Point((($Form.Width - $LblTimer.Width) / 2), (($Form.Height - $LblTimer.Height) / 2 + 280))
    $DevLabel.Location = New-Object System.Drawing.Point((($Form.Width - $DevLabel.Width) / 2), ($Form.Height - 60))
})

$IdleTimer = New-Object System.Windows.Forms.Timer
$IdleTimer.Interval = 1000
$IdleTimer.Add_Tick({ 
    if ($Global:idleCount -gt 0) { 
        $Global:idleCount-- 
    } else { 
        $IdleTimer.Stop(); $SysTimer.Stop(); $AntiBypassTimer.Stop()
        [KeyboardHook]::ReleaseHook()
        Restore-System
        rundll32.exe user32.dll,LockWorkStation
        $Form.Dispose()
        Stop-Process -Id $PID -Force 
    } 
})

$SysTimer = New-Object System.Windows.Forms.Timer
$SysTimer.Interval = 1000
$SysTimer.Add_Tick({
    if ($Global:timerCount -gt 0) { 
        $LblTimer.Text = $Global:timerCount.ToString()
        [System.Media.SystemSounds]::Hand.Play()
        $Global:timerCount-- 
    } else { 
        $SysTimer.Stop(); $IdleTimer.Stop(); $AntiBypassTimer.Stop()
        $Panel.Visible = $false
        $LblTimer.Visible = $false
        
        $Form.Opacity = 1.0
        $Form.BackColor = [System.Drawing.Color]::FromArgb(190, 10, 10)
        $MainLabel.Dock = "Fill"
        $MainLabel.ForeColor = [System.Drawing.Color]::White
        $MainLabel.Text = "ACCESS DENIED. HARDWARE LOCKED."
        [void]$Sapi.SpeakAsync("Access denied. System shutting down.")
        $Form.Refresh()
        Start-Sleep -Seconds 4
        [KeyboardHook]::ReleaseHook()
        "True" | Out-File -FilePath $UnlockFlag -Encoding utf8
        $Form.Dispose()
        Stop-Computer -Force
        Stop-Process -Id $PID -Force 
    }
})

$AntiBypassTimer = New-Object System.Windows.Forms.Timer
$AntiBypassTimer.Interval = 200
$AntiBypassTimer.Add_Tick({ 
    if ($Form.Visible) { 
        $Form.Activate()
        if ($Panel.Visible -and -not $Txt.Focused) { [void]$Txt.Focus() } 
    }
    Block-Bypass-Continuous 
})

$AnimationTimer = New-Object System.Windows.Forms.Timer
$AnimationTimer.Interval = 10
$AnimationTimer.Add_Tick({
    if ($Form.Opacity -lt 0.90) { $Form.Opacity += 0.05 } 
    if ($Global:CurrentY -gt $Global:TargetY) {
        $Step = [math]::Max(2, [int](($Global:CurrentY - $Global:TargetY) / 5)) 
        $Global:CurrentY -= $Step
        $Panel.Location = New-Object System.Drawing.Point($Global:TargetX, $Global:CurrentY)
    } else {
        $AnimationTimer.Stop()
        [void]$Txt.Focus()
    }
})

$IntroTimer = New-Object System.Windows.Forms.Timer
$IntroTimer.Interval = ($Global:introDelay * 1000)
$IntroTimer.Add_Tick({ 
    $IntroTimer.Stop()
    $MainLabel.Dock = "None"
    $MainLabel.Size = New-Object System.Drawing.Size(1200, 100)
    $MainLabel.Location = New-Object System.Drawing.Point((($Form.Width - $MainLabel.Width) / 2), (($Form.Height - $MainLabel.Height) / 2 - 160))
    $MainLabel.Text = "Please confirm your identity."
    $Panel.Visible = $true
    $AnimationTimer.Start()
    [void]$Sapi.SpeakAsync("Please confirm your identity.") 
})

$Btn.Add_Click({
    [string]$InputPassword = "$($Txt.Text)"
    if ($InputPassword) { $InputPassword = $InputPassword.Trim() }
    if (Verify-Password $InputPassword) { 
        $IdleTimer.Stop(); $SysTimer.Stop(); $AntiBypassTimer.Stop()
        [KeyboardHook]::ReleaseHook()
        Restore-System
        if (Test-Path $Global:vaultPath) { Start-Process "explorer.exe" -ArgumentList $Global:vaultPath }
        "True" | Out-File -FilePath $UnlockFlag -Encoding utf8
        $Form.Dispose()
        Stop-Process -Id $PID -Force 
    }
    else { 
        Maximize-Volume
        [void]$Sapi.SpeakAsync("Warning!")
        Capture-Intruder
        $Txt.Text = ""
        [void]$Txt.Focus()
        if (-not $SysTimer.Enabled) { 
            $IdleTimer.Stop(); $LblTimer.Visible = $true
            $MainLabel.ForeColor = [System.Drawing.Color]::FromArgb(220, 20, 20)
            $MainLabel.Text = "SECURITY THREAT DETECTED"
            [System.Media.SystemSounds]::Hand.Play()
            $SysTimer.Start() 
        } 
    }
})

$Form.Add_Shown({ 
    Block-Bypass-Initial
    [KeyboardHook]::SetHook()
    $AntiBypassTimer.Start()
    $IntroTimer.Start()
    $IdleTimer.Start()
    
    $Form.Opacity = 0.1
    $Form.Refresh()
    for($i=1; $i -le 10; $i++) { Start-Sleep -Milliseconds 15; $Form.Opacity += 0.08 }
    [void]$Sapi.SpeakAsync("Welcome.") 
})
[System.Windows.Forms.Application]::Run($Form)
