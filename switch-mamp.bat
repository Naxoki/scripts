@echo off
:: Auto-elevar a Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

powershell -ExecutionPolicy Bypass -File "D:\scripts\switch-mode.ps1"
