@echo off
title Between AWS Cost Management Toggle
cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0between-aws-toggle.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Script exited with status code %ERRORLEVEL%.
    pause
)
