@echo off
title Startup Manual Redirector
setlocal encoding=utf-8
cd /d "%~dp0"

if not exist "Startup_Guide.txt" (
    (
    echo ========================================================================
    echo                      STARTUP CONFIGURATION TUTORIAL
    echo ========================================================================
    echo.
    echo STEP 1: In the Task Scheduler window, look at the right-side "Actions" 
    echo         panel and click on "Create Task..." ^(Do NOT click Basic Task^).
    echo.
    echo STEP 2: In the "General" Tab:
    echo         - Set the Name to: WindowsProtectorBot
    echo         - Crucial: Check/Tick the box "Run with highest privileges" 
    echo           at the bottom. ^(Required for admin rights^).
    echo.
    echo STEP 3: Go to the "Triggers" Tab and click the "New..." button.
    echo         - Change "Begin the task:" dropdown to "At log on".
    echo         - Click OK.
    echo.
    echo STEP 4: Go to the "Actions" Tab and click the "New..." button.
    echo         - Ensure Action is set to "Start a program".
    echo         - Click "Browse..." and select "Main.bat" from this folder.
    echo.
    echo STEP 5: ⚠️ CRITICAL STEP: In the same Action window, find the field 
    echo         labeled "Start in ^(optional^):". Copy and paste the exact path 
    echo         written below into it:
    echo         %~dp0
    echo         ⚠️ Make sure there are NO double quotes " around the path!
    echo         - Click OK.
    echo.
    echo STEP 6: Go to the "Conditions" Tab. Under the "Power" section, 
    echo         UNCHECK / TICK OFF the box that says:
    echo         "Start the task only if the computer is on AC power".
    echo         ^(This ensures the bot works on laptop battery power^).
    echo.
    echo STEP 7: Click the main "OK" button at the bottom right to save the task.
    echo.
    echo ========================================================================
    ) > "Startup_Guide.txt"
)

start taskschd.msc
start notepad.exe "Startup_Guide.txt"
exit
