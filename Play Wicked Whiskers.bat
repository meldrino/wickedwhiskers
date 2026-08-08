@echo off
title Wicked Whiskers Launcher
REM Close any leftover game windows / console boxes from previous runs
taskkill /f /im Godot_v4.7.1-stable_win64_console.exe /t >nul 2>&1
taskkill /f /im Godot_v4.7.1-stable_win64.exe /t >nul 2>&1
REM Give them a moment to close before starting fresh
timeout /t 1 /nobreak >nul
start "" "C:\crypto\tools\Godot_v4.7.1-stable_win64.exe" --path "C:\crypto\wicked whiskers"
exit
